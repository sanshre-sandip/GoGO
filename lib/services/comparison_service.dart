import '../models/ride_option.dart';
import '../models/ride_preferences.dart';

class ScoredRide {
  final RideOption option;
  final double priceScore;
  final double distanceScore;
  final double etaScore;
  final double matchScore;

  const ScoredRide({
    required this.option,
    required this.priceScore,
    required this.distanceScore,
    required this.etaScore,
    required this.matchScore,
  });
}

class ComparisonResult {
  /// Best match first.
  final List<ScoredRide> ranked;
  final RideOption? cheapest;
  final RideOption? nearest;
  final RideOption? fastest;
  final String explanation;

  const ComparisonResult({
    required this.ranked,
    this.cheapest,
    this.nearest,
    this.fastest,
    this.explanation = '',
  });

  RideOption? get bestMatch => ranked.isEmpty ? null : ranked.first.option;
  bool get isEmpty => ranked.isEmpty;
}

/// Local, deterministic ranking. No network, no LLM.
class ComparisonService {
  const ComparisonService();

  ComparisonResult compare(List<RideOption> options, RidePreferences prefs) {
    if (options.isEmpty) return const ComparisonResult(ranked: []);

    final p = prefs.orBalanced;

    // A wait limit is a filter, not a weight — but never filter everything away.
    var pool = options;
    final limit = p.maxWaitMinutes;
    if (limit != null) {
      final within = options.where((o) => o.etaMinutes <= limit).toList();
      if (within.isNotEmpty) pool = within;
    }

    final prices = _normalize(pool.map((o) => o.price));
    final distances = _normalize(pool.map((o) => o.driverDistanceKm));
    final etas = _normalize(pool.map((o) => o.etaMinutes.toDouble()));
    final total = p.pricePriority + p.distancePriority + p.etaPriority;

    final scored = <ScoredRide>[
      for (var i = 0; i < pool.length; i++)
        ScoredRide(
          option: pool[i],
          priceScore: prices[i],
          distanceScore: distances[i],
          etaScore: etas[i],
          matchScore: (p.pricePriority * prices[i] +
                  p.distancePriority * distances[i] +
                  p.etaPriority * etas[i]) /
              total,
        ),
    ];

    // Stable, deterministic: score desc, then cheaper, then id.
    scored.sort((a, b) {
      final byScore = b.matchScore.compareTo(a.matchScore);
      if (byScore != 0) return byScore;
      final byPrice = a.option.price.compareTo(b.option.price);
      if (byPrice != 0) return byPrice;
      return a.option.id.compareTo(b.option.id);
    });

    final cheapest = _best(pool, (o) => o.price);
    final nearest = _best(pool, (o) => o.driverDistanceKm);
    final fastest = _best(pool, (o) => o.etaMinutes.toDouble());

    return ComparisonResult(
      ranked: scored,
      cheapest: cheapest,
      nearest: nearest,
      fastest: fastest,
      explanation: _explain(scored.first.option, cheapest!, nearest!, fastest!, p),
    );
  }

  /// Lower raw value is better, so map the range onto 1 (best) .. 0 (worst).
  /// All values equal → everyone scores 1, which keeps ties neutral.
  List<double> _normalize(Iterable<double> values) {
    final list = values.toList();
    final min = list.reduce((a, b) => a < b ? a : b);
    final max = list.reduce((a, b) => a > b ? a : b);
    if (max == min) return List.filled(list.length, 1.0);
    return [for (final v in list) (max - v) / (max - min)];
  }

  RideOption? _best(List<RideOption> options, double Function(RideOption) metric) {
    if (options.isEmpty) return null;
    return options.reduce((a, b) {
      final d = metric(a).compareTo(metric(b));
      if (d != 0) return d < 0 ? a : b;
      return a.id.compareTo(b.id) <= 0 ? a : b; // deterministic on ties
    });
  }

  String _explain(
    RideOption winner,
    RideOption cheapest,
    RideOption nearest,
    RideOption fastest,
    RidePreferences p,
  ) {
    final name = winner.provider.name;
    final wins = <String>[
      if (winner.id == cheapest.id) 'is the cheapest at ${winner.priceLabel}',
      if (winner.id == nearest.id)
        'has the closest driver at ${winner.distanceLabel}',
      if (winner.id == fastest.id) 'picks you up fastest in ${winner.etaMinutes} min',
    ];

    if (wins.length == 3) return '$name wins on price, distance and pickup time.';
    if (wins.isEmpty) {
      return '$name balances your priorities best overall — ${winner.priceLabel}, '
          '${winner.distanceLabel}, ${winner.etaLabel}.';
    }

    final trade = <String>[
      if (winner.id != cheapest.id && p.pricePriority > 0)
        '${(winner.price - cheapest.price).toStringAsFixed(0)} ${winner.currency} more than ${cheapest.provider.name}',
      if (winner.id != nearest.id && p.distancePriority > 0)
        'a slightly further driver than ${nearest.provider.name}',
      if (winner.id != fastest.id && p.etaPriority > 0)
        '${winner.etaMinutes - fastest.etaMinutes} min longer to arrive than ${fastest.provider.name}',
    ];

    final good = _join(wins);
    return trade.isEmpty
        ? '$name $good.'
        : '$name costs ${_join(trade)}, but it $good.';
  }

  String _join(List<String> parts) => parts.length == 1
      ? parts.first
      : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
}
