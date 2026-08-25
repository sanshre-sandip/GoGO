import '../models/ride_option.dart';
import '../models/ride_preferences.dart';

class ScoredRide {
  final RideOption option;
  final double? priceScore;
  final double? distanceScore;
  final double? etaScore;
  final double matchScore;

  const ScoredRide({
    required this.option,
    required this.matchScore,
    this.priceScore,
    this.distanceScore,
    this.etaScore,
  });
}

class ComparisonResult {
  /// Best match first. Only rides with a real price appear here.
  final List<ScoredRide> ranked;
  final RideOption? cheapest;
  final RideOption? nearest;
  final RideOption? fastest;
  final String explanation;

  /// Priorities the user chose that no provider supplied data for, so the
  /// ranking could not honour them.
  final Set<Priority> unusablePriorities;

  const ComparisonResult({
    required this.ranked,
    this.cheapest,
    this.nearest,
    this.fastest,
    this.explanation = '',
    this.unusablePriorities = const {},
  });

  RideOption? get bestMatch => ranked.isEmpty ? null : ranked.first.option;
  bool get isEmpty => ranked.isEmpty;
}

/// Local, deterministic ranking over real provider quotes. No network, no LLM.
///
/// A metric is only used when *every* ride being compared reports it —
/// ranking half the field on ETA and the other half on nothing would be
/// arbitrary, so a metric nobody reports is dropped and surfaced to the user
/// through [ComparisonResult.unusablePriorities].
class ComparisonService {
  const ComparisonService();

  ComparisonResult compare(List<RideOption> options, RidePreferences prefs) {
    if (options.isEmpty) return const ComparisonResult(ranked: []);

    final p = prefs.orBalanced;

    // A wait limit is a filter, not a weight — but never filter everything away
    // and never drop a ride just because its ETA is unknown.
    var pool = options;
    final limit = p.maxWaitMinutes;
    if (limit != null) {
      final within =
          options.where((o) => o.etaMinutes == null || o.etaMinutes! <= limit).toList();
      if (within.isNotEmpty) pool = within;
    }

    final prices = _normalize(pool.map((o) => o.price));
    final distances = _normalize(pool.map((o) => o.driverDistanceKm));
    final etas = _normalize(pool.map((o) => o.etaMinutes?.toDouble()));

    final weights = <Priority, double>{
      if (prices != null) Priority.cheapest: p.pricePriority,
      if (distances != null) Priority.nearest: p.distancePriority,
      if (etas != null) Priority.fastest: p.etaPriority,
    }..removeWhere((_, w) => w == 0);

    // Everything the user asked for is missing → fall back to what we do have.
    final usable = weights.isEmpty
        ? <Priority, double>{
            if (prices != null) Priority.cheapest: 1,
            if (distances != null) Priority.nearest: 1,
            if (etas != null) Priority.fastest: 1,
          }
        : weights;
    final total = usable.values.fold(0.0, (a, b) => a + b);

    final scored = <ScoredRide>[
      for (var i = 0; i < pool.length; i++)
        ScoredRide(
          option: pool[i],
          priceScore: prices?[i],
          distanceScore: distances?[i],
          etaScore: etas?[i],
          matchScore: total == 0
              ? 0
              : ((usable[Priority.cheapest] ?? 0) * (prices?[i] ?? 0) +
                      (usable[Priority.nearest] ?? 0) * (distances?[i] ?? 0) +
                      (usable[Priority.fastest] ?? 0) * (etas?[i] ?? 0)) /
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
    final fastest = _best(pool, (o) => o.etaMinutes?.toDouble());

    return ComparisonResult(
      ranked: scored,
      cheapest: cheapest,
      nearest: nearest,
      fastest: fastest,
      unusablePriorities: {
        if (distances == null && p.distancePriority > 0) Priority.nearest,
        if (etas == null && p.etaPriority > 0) Priority.fastest,
      },
      explanation: _explain(scored.first.option, cheapest, nearest, fastest, p),
    );
  }

  /// Lower raw value is better, so map the range onto 1 (best) .. 0 (worst).
  /// All values equal → everyone scores 1, keeping ties neutral.
  /// Returns null when any ride is missing the metric.
  List<double>? _normalize(Iterable<double?> values) {
    final list = values.toList();
    if (list.any((v) => v == null)) return null;
    final present = list.cast<double>();
    final min = present.reduce((a, b) => a < b ? a : b);
    final max = present.reduce((a, b) => a > b ? a : b);
    if (max == min) return List.filled(present.length, 1.0);
    return [for (final v in present) (max - v) / (max - min)];
  }

  RideOption? _best(List<RideOption> options, double? Function(RideOption) metric) {
    final withMetric = options.where((o) => metric(o) != null).toList();
    if (withMetric.isEmpty) return null;
    return withMetric.reduce((a, b) {
      final d = metric(a)!.compareTo(metric(b)!);
      if (d != 0) return d < 0 ? a : b;
      return a.id.compareTo(b.id) <= 0 ? a : b; // deterministic on ties
    });
  }

  String _explain(
    RideOption winner,
    RideOption? cheapest,
    RideOption? nearest,
    RideOption? fastest,
    RidePreferences p,
  ) {
    final name = winner.provider.name;
    final wins = <String>[
      if (winner.id == cheapest?.id) 'is the cheapest at ${winner.priceLabel}',
      if (winner.id == nearest?.id) 'has the closest driver at ${winner.distanceLabel}',
      if (winner.id == fastest?.id)
        'picks you up fastest in ${winner.etaMinutes} min',
    ];

    if (wins.isEmpty) {
      return '$name balances your priorities best overall.';
    }

    final trade = <String>[
      if (cheapest != null && winner.id != cheapest.id && p.pricePriority > 0)
        '${(winner.price - cheapest.price).toStringAsFixed(0)} ${winner.currency} '
            'more than ${cheapest.provider.name}',
      if (nearest != null && winner.id != nearest.id && p.distancePriority > 0)
        'further from you than ${nearest.provider.name}',
      if (fastest != null &&
          winner.id != fastest.id &&
          p.etaPriority > 0 &&
          winner.etaMinutes != null)
        '${winner.etaMinutes! - fastest.etaMinutes!} min longer to arrive than '
            '${fastest.provider.name}',
    ];

    final good = _join(wins);
    return trade.isEmpty
        ? '$name $good.'
        : '$name is ${_join(trade)}, but it $good.';
  }

  String _join(List<String> parts) => parts.length == 1
      ? parts.first
      : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
}
