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

  /// Real apps GoGo can hand you over to. Fares below are still estimates —
  /// only the handoff is real. Package names must match the manifest
  /// `<queries>` block, or Android 11+ will report every app as "not installed".
  static const providers = <RideProvider>[
    RideProvider(
      id: 'pathao',
      name: 'Pathao',
      color: Color(0xFF16A34A),
      androidPackage: 'com.pathao.user',
    ),
    RideProvider(
      id: 'indrive',
      name: 'inDrive',
      color: Color(0xFF7C3AED),
      androidPackage: 'sinet.startup.inDriver',
    ),
    RideProvider(
      id: 'yango',
      name: 'Yango',
      color: Color(0xFFDC2626),
      androidPackage: 'com.yandex.yango',
      deepLink: 'yango://',
    ),
    RideProvider(
      id: 'uber',
      name: 'Uber',
      color: Color(0xFF111827),
      androidPackage: 'com.ubercab',
      deepLink: 'uber://',
    ),
  ];

  // base fare, per-km rate, vehicle
  static const _tariffs = {
    'pathao': (75.0, 42.0, 'Bike'),
    'indrive': (90.0, 55.0, 'Car'),
    'yango': (85.0, 48.0, 'Car'),
    'uber': (110.0, 50.0, 'Car'),
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
