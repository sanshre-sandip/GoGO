import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/automation_session.dart';
import '../models/location_point.dart';

/// Talks to the native comparison session. All the automation logic lives in
/// Kotlin — this is only the bridge and the state it publishes.
class AutomationService {
  const AutomationService();

  static const _channel = MethodChannel('gogo/overlay');
  static const _events = EventChannel('gogo/automation_events');

  bool get supported => defaultTargetPlatform == TargetPlatform.android && !kIsWeb;

  /// Live session updates, pushed as the machine advances.
  Stream<AutomationSession> get sessions => supported
      ? _events.receiveBroadcastStream().map(
            (raw) => AutomationSession.fromJson(
              jsonDecode(raw as String) as Map<String, dynamic>,
            ),
          )
      : const Stream.empty();

  Future<AutomationDiagnostics?> diagnostics() async {
    final raw = await _invoke('accessibilityStatus');
    if (raw == null) return null;
    return AutomationDiagnostics.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  Future<void> openAccessibilitySettings() => _invoke('openAccessibilitySettings');

  /// Starts a real comparison across the installed provider apps.
  Future<AutomationSession?> start({
    required LocationPoint pickup,
    required LocationPoint destination,
    String? category,
  }) async {
    if (!supported) return null;
    try {
      final raw = await _channel.invokeMethod<String>('startComparison', {
        'pickupLabel': pickup.label,
        'pickupLat': pickup.latitude,
        'pickupLon': pickup.longitude,
        'destinationLabel': destination.label,
        'destinationLat': destination.latitude,
        'destinationLon': destination.longitude,
        'category': category,
      });
      if (raw == null) return null;
      return AutomationSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on PlatformException {
      return null;
    }
  }

  Future<void> cancel() => _invoke('cancelComparison');

  Future<List<AutomationLogEntry>> logs() async {
    final raw = await _invoke('automationLogs');
    if (raw == null) return const [];
    return [
      for (final entry in jsonDecode(raw) as List)
        AutomationLogEntry.fromJson((entry as Map).cast<String, dynamic>()),
    ];
  }

  Future<String?> _invoke(String method) async {
    if (!supported) return null;
    try {
      final result = await _channel.invokeMethod<Object?>(method);
      return result is String ? result : null;
    } on PlatformException {
      return null;
    }
  }
}

final automationServiceProvider = Provider((ref) => const AutomationService());

/// The live session, or an idle one when nothing is running.
final automationSessionProvider = StreamProvider<AutomationSession>(
  (ref) => ref.watch(automationServiceProvider).sessions,
);

final automationDiagnosticsProvider = FutureProvider<AutomationDiagnostics?>(
  (ref) => ref.watch(automationServiceProvider).diagnostics(),
);
