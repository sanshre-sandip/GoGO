import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/provider_config.dart';
import '../../models/location_point.dart';
import '../../models/provider_result.dart';
import '../../models/ride_option.dart';
import '../../models/ride_provider.dart';
import 'provider_connector.dart';

/// Yango's official partner endpoint.
///
/// `GET https://taxi-routeinfo.taxi.yandex.net/taxi_info`
/// `?clid={clid}&rll={from_lon},{from_lat}~{to_lon},{to_lat}`
/// with header `YaTaxi-Api-Key: {key}`.
///
/// Documented at yango.com/en_int/partner-program/documentation/. Credentials
/// come from integration-support@yango.com; without them this returns
/// [QuoteStatus.missingCredentials] rather than a made-up fare.
class YangoConnector implements ProviderConnector {
  YangoConnector(
    this.provider, {
    this.config = const ProviderConfig(),
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  final RideProvider provider;

  final http.Client _client;
  final ProviderConfig config;

  static final _endpoint = Uri.https('taxi-routeinfo.taxi.yandex.net', '/taxi_info');

  @override
  bool get isConfigured => config.yangoConfigured;

  @override
  Future<ProviderResult> quote({
    required LocationPoint pickup,
    required LocationPoint destination,
  }) async {
    if (!isConfigured) {
      return ProviderResult(provider: provider, status: QuoteStatus.missingCredentials);
    }

    final url = _endpoint.replace(queryParameters: {
      'clid': ProviderConfig.yangoClid,
      'rll': '${pickup.longitude},${pickup.latitude}'
          '~${destination.longitude},${destination.latitude}',
    });

    try {
      final response = await _client.get(
        url,
        headers: {'YaTaxi-Api-Key': ProviderConfig.yangoApiKey},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401 || response.statusCode == 403) {
        return ProviderResult(
          provider: provider,
          status: QuoteStatus.missingCredentials,
          detail: 'Yango rejected the API key (HTTP ${response.statusCode}).',
        );
      }
      if (response.statusCode != 200) {
        return ProviderResult(
          provider: provider,
          status: QuoteStatus.unavailable,
          detail: 'Yango returned HTTP ${response.statusCode}.',
        );
      }
      return parse(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      return ProviderResult(
        provider: provider,
        status: QuoteStatus.unavailable,
        detail: 'Could not reach Yango.',
      );
    }
  }

  /// Maps the documented response onto GoGo's model. Exposed for tests so the
  /// parsing is verified against recorded payloads, not guessed at runtime.
  ProviderResult parse(Map<String, dynamic> body) {
    final options = (body['options'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final priced = options.where((o) => o['price'] is num).toList();
    if (priced.isEmpty) {
      return ProviderResult(
        provider: provider,
        status: QuoteStatus.unavailable,
        detail: 'Yango has no classes available for this route.',
      );
    }

    // ponytail: cheapest class only. Show every class when the UI grows a
    // per-class breakdown.
    priced.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
    final best = priced.first;
    final waiting = best['waiting_time'];
    final distance = body['distance'];

    return ProviderResult(
      provider: provider,
      status: QuoteStatus.live,
      option: RideOption(
        id: '${provider.id}-${best['class_name']}',
        provider: provider,
        price: (best['price'] as num).toDouble(),
        currency: body['currency'] as String? ?? '',
        etaMinutes: waiting is num ? (waiting / 60).ceil() : null,
        vehicleType: best['class_text'] as String? ??
            best['class_name'] as String? ??
            'Car',
        tripDistanceKm: distance is num ? distance / 1000 : null,
      ),
    );
  }
}
