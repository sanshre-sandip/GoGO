import 'dart:math';

import 'package:flutter/material.dart';

import '../models/location_point.dart';
import '../models/ride_option.dart';
import '../models/ride_provider.dart';

/// Source of ride options. The mock implementation below is the MVP;
/// swap in a real one when a legitimate provider integration exists.
abstract class ProviderService {
  Future<List<RideOption>> quote({
    required LocationPoint pickup,
    required LocationPoint destination,
    required double tripDistanceKm,
  });

  /// True while the data shown is simulated, so the UI can say so.
  bool get isMock;
}

class MockProviderService implements ProviderService {
  const MockProviderService();

  @override
  bool get isMock => true;

  static const providers = <RideProvider>[
    RideProvider(id: 'a', name: 'Provider A', color: Color(0xFF16A34A)),
    RideProvider(id: 'b', name: 'Provider B', color: Color(0xFF7C3AED)),
    RideProvider(id: 'c', name: 'Provider C', color: Color(0xFFEA580C)),
  ];

  // base fare, per-km rate, vehicle
  static const _tariffs = {
    'a': (90.0, 55.0, 'Car'),
    'b': (110.0, 50.0, 'Car'),
    'c': (75.0, 42.0, 'Bike'),
  };

  @override
  Future<List<RideOption>> quote({
    required LocationPoint pickup,
    required LocationPoint destination,
    required double tripDistanceKm,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400)); // feels like a fetch

    // Seeded on the trip so the same search gives the same quotes.
    final rng = Random(destination.label.hashCode ^ tripDistanceKm.round());
    final km = tripDistanceKm.clamp(0.5, 40.0);

    return [
      for (final p in providers)
        () {
          final (base, perKm, vehicle) = _tariffs[p.id]!;
          final driverKm = 0.3 + rng.nextDouble() * 2.2;
          return RideOption(
            id: '${p.id}-${destination.label.hashCode}',
            provider: p,
            price: ((base + perKm * km) * (0.92 + rng.nextDouble() * 0.2))
                .roundToDouble(),
            driverDistanceKm: double.parse(driverKm.toStringAsFixed(1)),
            etaMinutes: (driverKm * 2.5).round() + 1 + rng.nextInt(3),
            vehicleType: vehicle,
          );
        }(),
    ];
  }
}
