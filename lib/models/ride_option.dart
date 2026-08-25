import 'ride_provider.dart';

/// One real, quoted ride. Every field here came from a provider's API —
/// nothing is estimated by GoGo.
class RideOption {
  final String id;
  final RideProvider provider;
  final double price;
  final String currency;
  /// Minutes until pickup, when the API reports it.
  final int? etaMinutes;
  final String vehicleType;

  /// How far the assigned driver is. Not every API reports this, so it is
  /// optional and the ranking skips it when nobody provides it.
  final double? driverDistanceKm;

  /// Route length in km, when the API reports it.
  final double? tripDistanceKm;

  const RideOption({
    required this.id,
    required this.provider,
    required this.price,
    required this.currency,
    this.etaMinutes,
    required this.vehicleType,
    this.driverDistanceKm,
    this.tripDistanceKm,
  });

  String get priceLabel => '$currency ${price.toStringAsFixed(0)}';
  String? get etaLabel => etaMinutes == null ? null : 'ETA $etaMinutes min';
  String? get distanceLabel => driverDistanceKm == null
      ? null
      : '${driverDistanceKm!.toStringAsFixed(1)} km away';
}
