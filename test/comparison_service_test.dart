import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:gogo/models/ride_option.dart';
import 'package:gogo/models/ride_preferences.dart';
import 'package:gogo/models/ride_provider.dart';
import 'package:gogo/services/comparison_service.dart';

RideOption ride(String id, double price, double? km, int? eta) => RideOption(
      id: id,
      provider: RideProvider(
        id: id,
        name: 'Provider $id',
        color: const Color(0xFF000000),
        packageId: 'test.$id',
        pricing: PricingSupport.none,
      ),
      price: price,
      currency: 'NPR',
      driverDistanceKm: km,
      etaMinutes: eta,
      vehicleType: 'Car',
    );

void main() {
  const service = ComparisonService();

  // A: cheapest, B: nearest + fastest, C: middling.
  final rides = [
    ride('A', 250, 1.2, 5),
    ride('B', 280, 0.5, 3),
    ride('C', 320, 0.8, 4),
  ];

  String winner(Set<Priority> selection, [List<RideOption>? options]) => service
      .compare(options ?? rides, RidePreferences.fromSelection(selection))
      .bestMatch!
      .id;

  test('cheapest only picks the lowest price', () {
    expect(winner({Priority.cheapest}), 'A');
  });

  test('nearest only picks the closest driver', () {
    expect(winner({Priority.nearest}), 'B');
  });

  test('fastest only picks the lowest ETA', () {
    expect(winner({Priority.fastest}), 'B');
  });

  test('cheapest + nearest weighs both, not just price', () {
    final result = service.compare(
      rides,
      RidePreferences.fromSelection({Priority.cheapest, Priority.nearest}),
    );
    // A is cheapest but furthest, B is 30 NPR more but much closer: the
    // combined score puts B first, so price alone does not decide.
    expect(result.bestMatch!.id, 'B');
    expect(result.ranked.last.option.id, 'C');
  });

  test('all priorities selected favours the all-round option', () {
    expect(winner(Priority.values.toSet()), 'B');
  });

  test('no priorities selected still ranks, balanced', () {
    final result = service.compare(rides, const RidePreferences());
    expect(result.ranked, hasLength(3));
    expect(result.bestMatch!.id, 'B');
  });

  test('individual winners are reported regardless of selection', () {
    final result =
        service.compare(rides, RidePreferences.fromSelection({Priority.cheapest}));
    expect(result.cheapest!.id, 'A');
    expect(result.nearest!.id, 'B');
    expect(result.fastest!.id, 'B');
  });

  test('empty ride list yields an empty result', () {
    final result = service.compare([], RidePreferences.fromSelection({Priority.cheapest}));
    expect(result.isEmpty, isTrue);
    expect(result.bestMatch, isNull);
    expect(result.cheapest, isNull);
  });

  test('equal prices fall through to the other priorities', () {
    final equal = [ride('A', 200, 2.0, 9), ride('B', 200, 0.5, 3)];
    expect(winner({Priority.cheapest, Priority.nearest}, equal), 'B');
  });

  test('equal distances and ETAs leave price deciding', () {
    final equal = [ride('A', 300, 1.0, 5), ride('B', 200, 1.0, 5)];
    expect(winner(Priority.values.toSet(), equal), 'B');
  });

  test('identical rides rank deterministically by id', () {
    final same = [ride('B', 200, 1.0, 5), ride('A', 200, 1.0, 5)];
    expect(winner({Priority.cheapest}, same), 'A');
  });

  test('single ride wins by default', () {
    final one = [ride('A', 999, 9.9, 30)];
    expect(winner({Priority.fastest}, one), 'A');
  });

  test('maxWaitMinutes filters out slow pickups', () {
    final result = service.compare(
      rides,
      const RidePreferences(pricePriority: 1, maxWaitMinutes: 4),
    );
    expect(result.ranked.map((r) => r.option.id), isNot(contains('A')));
    expect(result.bestMatch!.id, 'B');
  });

  test('an impossible wait limit does not empty the list', () {
    final result = service.compare(
      rides,
      const RidePreferences(pricePriority: 1, maxWaitMinutes: 1),
    );
    expect(result.ranked, hasLength(3));
  });

  test('a metric nobody reports is dropped, not guessed', () {
    // Yango reports a fare and pickup time but no driver distance.
    final noDistance = [ride('A', 250, null, 5), ride('B', 280, null, 3)];
    final result = service.compare(
      noDistance,
      RidePreferences.fromSelection({Priority.nearest, Priority.fastest}),
    );
    expect(result.nearest, isNull);
    expect(result.unusablePriorities, {Priority.nearest});
    expect(result.bestMatch!.id, 'B'); // ranked on ETA alone
  });

  test('rides with an unknown ETA survive a wait limit', () {
    final mixed = [ride('A', 250, null, null), ride('B', 900, null, 2)];
    final result = service.compare(
      mixed,
      const RidePreferences(pricePriority: 1, maxWaitMinutes: 3),
    );
    expect(result.ranked.map((r) => r.option.id), containsAll(['A', 'B']));
  });

  test('when every chosen priority is unreported, price still ranks', () {
    final noExtras = [ride('A', 300, null, null), ride('B', 200, null, null)];
    final result = service.compare(
      noExtras,
      RidePreferences.fromSelection({Priority.fastest}),
    );
    expect(result.bestMatch!.id, 'B');
    expect(result.unusablePriorities, {Priority.fastest});
  });

  test('explanation names the winner and the trade-off', () {
    final result = service.compare(
      rides,
      RidePreferences.fromSelection({Priority.nearest, Priority.fastest}),
    );
    expect(result.explanation, contains('Provider B'));
    expect(result.explanation, isNotEmpty);
  });
}
