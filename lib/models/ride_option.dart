import 'ride_provider.dart';

class RideOption {
  final String id;
  final RideProvider provider;
  final double price;
  final String currency;
  final double driverDistanceKm;
  final int etaMinutes;
  final String vehicleType;

  const RideOption({
    required this.id,
    required this.provider,
    required this.price,
    required this.driverDistanceKm,
    required this.etaMinutes,
    this.currency = 'NPR',
    this.vehicleType = 'Car',
  });

  String get priceLabel => '$currency ${price.toStringAsFixed(0)}';
  String get distanceLabel => '${driverDistanceKm.toStringAsFixed(1)} km away';
  String get etaLabel => 'ETA $etaMinutes min';

  RideOption copyWith({double? price, double? driverDistanceKm, int? etaMinutes}) =>
      RideOption(
        id: id,
        provider: provider,
        price: price ?? this.price,
        currency: currency,
        driverDistanceKm: driverDistanceKm ?? this.driverDistanceKm,
        etaMinutes: etaMinutes ?? this.etaMinutes,
        vehicleType: vehicleType,
      );
}
