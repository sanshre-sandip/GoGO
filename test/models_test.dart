import 'package:flutter_test/flutter_test.dart';
import 'package:gogo/models/location_point.dart';
import 'package:gogo/models/ride_option.dart';
import 'package:gogo/models/ride_preferences.dart';
import 'package:gogo/services/location_service.dart';
import 'package:gogo/services/preference_interpreter.dart';
import 'package:gogo/services/provider_service.dart';

void main() {
  test('RideOption formats its labels', () {
    final option = RideOption(
      id: 'x',
      provider: MockProviderService.providers.first,
      price: 250,
      driverDistanceKm: 1.24,
      etaMinutes: 5,
    );
    expect(option.priceLabel, 'NPR 250');
    expect(option.distanceLabel, '1.2 km away');
    expect(option.etaLabel, 'ETA 5 min');
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
    final balanced = prefs.orBalanced;
    expect(balanced.pricePriority, 1);
    expect(balanced.distancePriority, 1);
    expect(balanced.etaPriority, 1);
  });

  test('LocationPoint round-trips and falls back to coordinates', () {
    const point = LocationPoint(latitude: 27.7172, longitude: 85.3240);
    expect(LocationPoint.fromJson(point.toJson()).latitude, 27.7172);
    expect(point.toString(), '27.7172, 85.3240');
  });

  test('rule-based interpreter reads a plain sentence', () async {
    final prefs = await const RuleBasedPreferenceInterpreter()
        .interpret("I need the cheapest ride but I don't want to wait more than 5 min");
    expect(prefs.pricePriority, 1);
    expect(prefs.etaPriority, 1);
    expect(prefs.distancePriority, 0);
    expect(prefs.maxWaitMinutes, 5);
  });

  test('placeLabel reads like a Maps address', () {
    expect(
      placeLabel(name: 'Thamel Marg', subLocality: 'Thamel', locality: 'Kathmandu'),
      'Thamel Marg, Kathmandu',
    );
    // Falls through to the next useful part when the specific one is missing.
    expect(placeLabel(subLocality: 'Patan', locality: 'Lalitpur'), 'Patan, Lalitpur');
    // Never repeats the city back at you.
    expect(placeLabel(name: 'Kathmandu', locality: 'Kathmandu'), 'Kathmandu');
    expect(placeLabel(), '');
  });

  test('mock quotes are deterministic for the same trip', () async {
    const service = MockProviderService();
    const pickup = LocationPoint(latitude: 27.7, longitude: 85.3, label: 'here');
    const dest = LocationPoint(latitude: 27.72, longitude: 85.33, label: 'Thamel');
    final a = await service.quote(pickup: pickup, destination: dest, tripDistanceKm: 4);
    final b = await service.quote(pickup: pickup, destination: dest, tripDistanceKm: 4);
    expect(a.map((o) => o.price), b.map((o) => o.price));
    expect(a, hasLength(MockProviderService.providers.length));
  });
}

// placeLabel is appended here rather than in its own file — it is one pure
// helper, not a feature.
