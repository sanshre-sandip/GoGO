import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:gogo/models/location_point.dart';
import 'package:gogo/models/provider_result.dart';
import 'package:gogo/models/ride_option.dart';
import 'package:gogo/models/ride_preferences.dart';
import 'package:gogo/models/ride_provider.dart';
import 'package:gogo/services/connectors/yango_connector.dart';
import 'package:gogo/services/location_service.dart';
import 'package:gogo/services/preference_interpreter.dart';
import 'package:gogo/services/quote_service.dart';

void main() {
  final yango = kProviders.firstWhere((p) => p.id == 'yango');

  test('RideOption only labels the facts a provider actually reported', () {
    final option = RideOption(
      id: 'x',
      provider: yango,
      price: 250,
      currency: 'NPR',
      etaMinutes: 5,
      vehicleType: 'Economy',
    );
    expect(option.priceLabel, 'NPR 250');
    expect(option.etaLabel, 'ETA 5 min');
    expect(option.distanceLabel, isNull); // no driver distance reported
  });

  test('RidePreferences round-trips through JSON', () {
    const prefs = RidePreferences(
      pricePriority: 0.8,
      etaPriority: 0.7,
      maxWaitMinutes: 5,
    );
    final copy = RidePreferences.fromJson(prefs.toJson());
    expect(copy.pricePriority, 0.8);
    expect(copy.maxWaitMinutes, 5);
    expect(copy.selection, {Priority.cheapest, Priority.fastest});
  });

  test('empty preferences balance instead of ranking arbitrarily', () {
    const prefs = RidePreferences();
    expect(prefs.isEmpty, isTrue);
    expect(prefs.orBalanced.pricePriority, 1);
    expect(prefs.orBalanced.etaPriority, 1);
  });

  test('LocationPoint round-trips and falls back to coordinates', () {
    const point = LocationPoint(latitude: 27.7172, longitude: 85.3240);
    expect(LocationPoint.fromJson(point.toJson()).latitude, 27.7172);
    expect(point.toString(), '27.7172, 85.3240');
  });

  test('placeLabel reads like a Maps address', () {
    expect(
      placeLabel(name: 'Thamel Marg', subLocality: 'Thamel', locality: 'Kathmandu'),
      'Thamel Marg, Kathmandu',
    );
    expect(placeLabel(subLocality: 'Patan', locality: 'Lalitpur'), 'Patan, Lalitpur');
    expect(placeLabel(name: 'Kathmandu', locality: 'Kathmandu'), 'Kathmandu');
    expect(placeLabel(), '');
  });

  test('rule-based interpreter reads a plain sentence', () async {
    final prefs = await const RuleBasedPreferenceInterpreter()
        .interpret("I need the cheapest ride but I don't want to wait more than 5 min");
    expect(prefs.pricePriority, 1);
    expect(prefs.etaPriority, 1);
    expect(prefs.maxWaitMinutes, 5);
  });

  group('provider registry', () {
    test('every provider carries a verified package id', () {
      for (final p in kProviders) {
        expect(p.packageId, isNotEmpty, reason: '${p.name} needs a package id');
      }
      expect(
        kProviders.map((p) => p.packageId),
        containsAll([
          'com.pathao.user',
          'sinet.startup.inDriver',
          'com.yandex.yango',
          'com.ubercab',
        ]),
      );
    });

    test('providers without an official API explain why', () {
      for (final p in kProviders.where((p) => p.pricing != PricingSupport.officialApi)) {
        expect(p.pricingNote, isNotNull, reason: '${p.name} must say why');
      }
    });
  });

  group('Yango connector', () {
    // Shape taken from the documented taxi_info response. This is a parser
    // fixture, never shown as a price in the app.
    final connector = YangoConnector(yango);

    test('parses the cheapest class out of a response', () {
      final result = connector.parse({
        'currency': 'NPR',
        'distance': 4200.0,
        'time': 900.0,
        'options': [
          {
            'class_name': 'econom',
            'class_text': 'Economy',
            'min_price': 120,
            'price': 320,
            'waiting_time': 185.0,
          },
          {
            'class_name': 'business',
            'class_text': 'Comfort',
            'price': 480,
            'waiting_time': 240.0,
          },
        ],
      });

      expect(result.status, QuoteStatus.live);
      expect(result.option!.price, 320);
      expect(result.option!.currency, 'NPR');
      expect(result.option!.vehicleType, 'Economy');
      expect(result.option!.etaMinutes, 4); // 185s rounds up to 4 min
      expect(result.option!.tripDistanceKm, closeTo(4.2, 0.001));
      expect(result.option!.driverDistanceKm, isNull); // not reported by this API
    });

    test('a response with no priced classes is unavailable, not free', () {
      final result = connector.parse({'currency': 'NPR', 'options': []});
      expect(result.status, QuoteStatus.unavailable);
      expect(result.option, isNull);
    });

    test('without credentials it reports missing config instead of a price',
        () async {
      final result = await connector.quote(
        pickup: const LocationPoint(latitude: 27.7, longitude: 85.3),
        destination: const LocationPoint(latitude: 27.6, longitude: 85.2),
      );
      // No dart-defines in a plain `flutter test` run.
      expect(result.status, QuoteStatus.missingCredentials);
      expect(result.option, isNull);
    });
  });

  test('ProviderResult never claims a price it does not have', () {
    const result = ProviderResult(
      provider: RideProvider(
        id: 'x',
        name: 'X',
        color: Color(0xFF000000),
        packageId: 'x',
        pricing: PricingSupport.none,
        pricingNote: 'No API.',
      ),
      status: QuoteStatus.noPublicApi,
    );
    expect(result.hasLivePrice, isFalse);
    expect(result.statusMessage, 'No API.');
  });
}
