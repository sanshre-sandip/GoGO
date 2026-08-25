import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/ride_preferences.dart';
import '../../services/comparison_service.dart';
import '../../services/handoff_service.dart';
import '../../services/location_service.dart';
import '../../services/storage_service.dart';
import '../../services/quote_service.dart';

/// Runs inside the floating assistant's own Flutter engine, hosted by
/// OverlayService. It does the same real work the app does — locate, quote,
/// rank — and hands back JSON that the service draws in native views, so the
/// user never leaves the app they are in.
class OverlayWorker {
  OverlayWorker({
    LocationService? location,
    QuoteService? quotes,
    this.comparison = const ComparisonService(),
  })  : _location = location ?? const LocationService(),
        _quotes = quotes ??
            QuoteService(
              connectors: QuoteService.defaultConnectors(),
              handoff: const HandoffService(),
            );

  final LocationService _location;
  final QuoteService _quotes;
  final ComparisonService comparison;

  static const channel = MethodChannel('gogo/overlay_worker');

  void listen() {
    channel.setMethodCallHandler((call) async {
      if (call.method != 'compare') return null;
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      return jsonEncode(await compare(
        priorities: (args['priorities'] as List?)?.cast<String>() ?? const [],
        installed: (args['installed'] as List?)?.cast<String>().toSet() ?? const {},
      ));
    });
  }

  Future<Map<String, dynamic>> compare({
    required List<String> priorities,
    required Set<String> installed,
  }) async {
    final prefs = RidePreferences.fromSelection({
      for (final name in priorities)
        ...Priority.values.where((p) => p.name == name),
    });

    // The overlay has no UI for picking a destination, so it uses the last one
    // chosen in the app. Without one there is no route, and no route means no
    // real fare to quote.
    final storage = await StorageService.create();
    final destination = storage.recentDestinations.firstOrNull;
    if (destination == null) {
      return {'error': 'Pick a destination in GoGo first, then compare from here.'};
    }

    try {
      final pickup = await _location.current();
      final results =
          await _quotes.quoteAll(pickup: pickup, destination: destination);
      final live = [
        for (final r in results)
          if (r.hasLivePrice) r.option!,
      ];
      final ranked = comparison.compare(live, prefs);

      return {
        'pickup': pickup.label,
        'destination': destination.label,
        'best': ranked.bestMatch?.provider.id,
        'explanation': ranked.explanation,
        'providers': [
          for (final r in results)
            {
              'id': r.provider.id,
              'name': r.provider.name,
              'package': r.provider.packageId,
              'installed': installed.contains(r.provider.packageId),
              'status': r.status.name,
              'message': r.statusMessage,
              if (r.hasLivePrice) ...{
                'price': r.option!.priceLabel,
                'eta': r.option!.etaLabel,
              },
            },
        ],
      };
    } on LocationException catch (e) {
      return {'error': e.message};
    } catch (_) {
      return {'error': "GoGo couldn't reach the providers."};
    }
  }
}
