import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location_point.dart';
import '../models/provider_result.dart';
import '../models/ride_provider.dart';
import 'connectors/provider_connector.dart';
import 'connectors/yango_connector.dart';
import 'handoff_service.dart';

/// Providers GoGo supports.
///
/// Package ids and schemes below were read off a physical device with
/// `adb shell pm list packages` and `cmd package resolve-activity`, not guessed.
/// See `docs/provider-verification.md` for the transcript.
const kProviders = <RideProvider>[
  RideProvider(
    id: 'pathao',
    name: 'Pathao',
    color: Color(0xFF16A34A),
    packageId: 'com.pathao.user',
    scheme: 'pathao://',
    pricing: PricingSupport.none,
    pricingNote: 'Pathao publishes no public fare API. Open the app for its price.',
  ),
  RideProvider(
    id: 'indrive',
    name: 'inDrive',
    color: Color(0xFF7C3AED),
    packageId: 'sinet.startup.inDriver',
    scheme: 'indrive://open',
    pricing: PricingSupport.none,
    pricingNote:
        'inDrive fares are offers you make to drivers, so there is no fare to '
        'quote in advance.',
  ),
  RideProvider(
    id: 'yango',
    name: 'Yango',
    color: Color(0xFFDC2626),
    packageId: 'com.yandex.yango',
    scheme: 'yandexyango://',
    pricing: PricingSupport.officialApi,
  ),
  RideProvider(
    id: 'uber',
    name: 'Uber',
    color: Color(0xFF111827),
    packageId: 'com.ubercab',
    pricing: PricingSupport.forbiddenByTerms,
    pricingNote:
        'Uber\'s API terms forbid using their price estimates to compare against '
        'other services, so GoGo only opens the app.',
  ),
];

/// Asks every provider for a real quote and reports, per provider, either a
/// live price or why there is none.
class QuoteService {
  QuoteService({required this.connectors, required this.handoff});

  final List<ProviderConnector> connectors;
  final HandoffService handoff;

  static List<ProviderConnector> defaultConnectors() => [
        for (final p in kProviders)
          if (p.pricing == PricingSupport.officialApi && p.id == 'yango')
            YangoConnector(p)
          else
            HandoffOnlyConnector(p),
      ];

  Future<List<ProviderResult>> quoteAll({
    required LocationPoint pickup,
    required LocationPoint destination,
  }) async {
    final installed =
        await handoff.installedPackages(kProviders.map((p) => p.packageId));
    final results = await Future.wait([
      for (final c in connectors) c.quote(pickup: pickup, destination: destination),
    ]);
    return [
      for (final r in results)
        r.copyWith(appInstalled: installed.contains(r.provider.packageId)),
    ];
  }
}

final quoteServiceProvider = Provider(
  (ref) => QuoteService(
    connectors: QuoteService.defaultConnectors(),
    handoff: ref.read(handoffServiceProvider),
  ),
);
