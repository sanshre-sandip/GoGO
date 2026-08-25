import 'dart:convert';

import 'package:flutter/services.dart';

import '../../services/location_service.dart';
import '../../services/storage_service.dart';

/// Runs inside the floating assistant's own Flutter engine, hosted by
/// OverlayService. Its only job is to hand the native side the current trip:
/// the comparison itself is native, because it drives the provider apps
/// through the accessibility service.
class OverlayWorker {
  OverlayWorker({LocationService? location})
      : _location = location ?? const LocationService();

  final LocationService _location;

  static const channel = MethodChannel('gogo/overlay_worker');

  void listen() {
    channel.setMethodCallHandler((call) async {
      if (call.method != 'tripContext') return null;
      return jsonEncode(await tripContext());
    });
  }

  /// The trip the overlay should compare: live location as pickup, and the
  /// last destination chosen in the app. The overlay has no room to pick one.
  Future<Map<String, dynamic>> tripContext() async {
    final storage = await StorageService.create();
    final destination = storage.recentDestinations.firstOrNull;
    if (destination == null) {
      return {'error': 'Pick a destination in GoGo first, then compare from here.'};
    }

    try {
      final pickup = await _location.current();
      return {
        'pickupLabel': pickup.label,
        'pickupLat': pickup.latitude,
        'pickupLon': pickup.longitude,
        'destinationLabel': destination.label,
        'destinationLat': destination.latitude,
        'destinationLon': destination.longitude,
        'category': storage.preferences.category.name,
      };
    } on LocationException catch (e) {
      return {'error': e.message};
    }
  }
}
