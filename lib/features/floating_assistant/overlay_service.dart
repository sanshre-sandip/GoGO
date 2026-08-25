import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../models/ride_preferences.dart';

/// Thin wrapper over the Android overlay + foreground service.
/// Every call is a no-op off Android, so the UI can stay unconditional.
class OverlayService {
  const OverlayService();

  static const _channel = MethodChannel('gogo/overlay');

  bool get supported => defaultTargetPlatform == TargetPlatform.android && !kIsWeb;

  Future<bool> _call(String method) async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> hasPermission() => _call('hasPermission');

  /// Opens the system "Display over other apps" screen. The result only
  /// arrives once the user comes back, so re-check [hasPermission] then.
  Future<bool> requestPermission() => _call('requestPermission');

  Future<bool> isRunning() => _call('isRunning');
  Future<bool> start() => _call('start');
  Future<bool> stop() => _call('stop');

  /// Priorities the user picked in the floating overlay, if any are waiting.
  Future<RidePreferences?> consumePendingRequest() async {
    if (!supported) return null;
    try {
      final raw = await _channel.invokeListMethod<String>('consumePendingRequest');
      if (raw == null || raw.isEmpty) return null;
      return RidePreferences.fromSelection({
        for (final name in raw)
          ...Priority.values.where((p) => p.name == name),
      });
    } on PlatformException {
      return null;
    }
  }
}

final overlayServiceProvider = Provider((ref) => const OverlayService());

/// True while the floating assistant is actually running.
class FloatingAssistantNotifier extends Notifier<bool> {
  @override
  bool build() {
    final wanted = ref.read(storageProvider).floatingAssistantEnabled;
    if (wanted) Future.microtask(_syncFromService);
    return wanted;
  }

  Future<void> _syncFromService() async {
    state = await ref.read(overlayServiceProvider).isRunning();
  }

  /// Returns null on success, or a message explaining why it didn't start.
  Future<String?> setEnabled(bool enabled) async {
    final overlay = ref.read(overlayServiceProvider);
    if (!overlay.supported) return 'The floating assistant is Android-only.';

    if (!enabled) {
      await overlay.stop();
      state = false;
      await ref.read(storageProvider).setFloatingAssistantEnabled(false);
      return null;
    }

    if (!await overlay.hasPermission()) {
      await overlay.requestPermission();
      if (!await overlay.hasPermission()) {
        return 'GoGo needs the "Display over other apps" permission to show '
            'the floating button. You can turn it on any time.';
      }
    }

    final started = await overlay.start();
    state = started;
    await ref.read(storageProvider).setFloatingAssistantEnabled(started);
    return started ? null : "Couldn't start the floating assistant.";
  }
}

final floatingAssistantProvider =
    NotifierProvider<FloatingAssistantNotifier, bool>(FloatingAssistantNotifier.new);
