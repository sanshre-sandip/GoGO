import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ride_provider.dart';

enum Handoff {
  /// The provider's app came to the front.
  opened,

  /// The app isn't installed, so its store page was opened instead.
  store,

  /// Nothing to open — no package, or the device refused every intent.
  unavailable,
}

/// Opens the provider's own app. GoGo never books a ride itself.
class HandoffService {
  const HandoffService();

  static const _channel = MethodChannel('gogo/overlay');

  Future<Handoff> open(RideProvider provider) async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) {
      return Handoff.unavailable;
    }
    try {
      final result = await _channel.invokeMethod<String>('openProvider', {
        'package': provider.androidPackage,
        'deepLink': provider.deepLink,
      });
      return Handoff.values.firstWhere(
        (h) => h.name == result,
        orElse: () => Handoff.unavailable,
      );
    } on PlatformException {
      return Handoff.unavailable;
    }
  }
}

final handoffServiceProvider = Provider((ref) => const HandoffService());
