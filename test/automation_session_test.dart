import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gogo/models/automation_session.dart';

/// These payloads are the shape the native session publishes. They verify the
/// bridge parsing only — no fare here is ever displayed as real.
void main() {
  test('parses a running session with one detected fare', () {
    final session = AutomationSession.fromJson(
      jsonDecode('''
      {
        "sessionId": "abc123",
        "state": "WAITING_FOR_FARE",
        "running": true,
        "currentProvider": "indrive",
        "providers": [
          {"id":"pathao","name":"Pathao","package":"com.pathao.user","installed":true,
           "succeeded":true,"amount":350.0,"currency":"Rs.","confidence":0.8,
           "rawText":"Rs. 350","timestamp":1735000000000,"status":"ACCEPTED"},
          {"id":"indrive","name":"inDrive","package":"sinet.startup.inDriver",
           "installed":true,"succeeded":false},
          {"id":"uber","name":"Uber","package":"com.ubercab","installed":false,
           "succeeded":false,"failure":"APP_NOT_INSTALLED"}
        ]
      }
      ''') as Map<String, dynamic>,
    );

    expect(session.state, SessionState.waitingForFare);
    expect(session.running, isTrue);
    expect(session.currentProviderId, 'indrive');
    expect(session.providers, hasLength(3));
    expect(session.checkedCount, 2); // one fare, one failure
    expect(session.best!.id, 'pathao');
    expect(session.best!.fareLabel, 'Rs. 350');
  });

  test('a failed provider carries a reason, never a fare', () {
    final outcome = ProviderOutcome.fromJson(
      jsonDecode('''
      {"id":"yango","name":"Yango","package":"com.yandex.yango","installed":true,
       "succeeded":false,"failure":"TRIP_ENTRY_UNAVAILABLE","note":"Trip entry unavailable"}
      ''') as Map<String, dynamic>,
    );

    expect(outcome.succeeded, isFalse);
    expect(outcome.amount, isNull);
    expect(outcome.failure, FailureReason.tripEntryUnavailable);
    expect(outcome.statusLabel, 'Trip entry unavailable');
  });

  test('the cheapest detected fare wins, ignoring providers with none', () {
    final session = AutomationSession.fromJson({
      'state': 'COMPLETED',
      'running': false,
      'providers': [
        {'id': 'a', 'name': 'A', 'installed': true, 'succeeded': true, 'amount': 380.0, 'currency': 'NPR'},
        {'id': 'b', 'name': 'B', 'installed': true, 'succeeded': true, 'amount': 320.0, 'currency': 'NPR'},
        {'id': 'c', 'name': 'C', 'installed': true, 'succeeded': false, 'failure': 'TIMEOUT'},
      ],
    });

    expect(session.detected.map((p) => p.id), ['b', 'a']);
    expect(session.best!.id, 'b');
    expect(session.finished, isTrue);
  });

  test('an unknown failure name does not crash the bridge', () {
    final outcome = ProviderOutcome.fromJson({
      'id': 'x',
      'name': 'X',
      'installed': true,
      'succeeded': false,
      'failure': 'SOMETHING_NEW',
    });
    expect(outcome.failure, isNull);
    expect(outcome.statusLabel, 'Waiting');
  });

  test('every native failure reason maps to a message', () {
    const names = [
      'APP_NOT_INSTALLED', 'ACCESSIBILITY_UNAVAILABLE', 'LAUNCH_FAILED',
      'BLOCKED_SCREEN', 'TRIP_ENTRY_UNAVAILABLE', 'FARE_NOT_FOUND',
      'LOW_CONFIDENCE', 'AMBIGUOUS', 'TIMEOUT', 'CANCELLED',
    ];
    for (final name in names) {
      final outcome = ProviderOutcome.fromJson({
        'id': 'x', 'name': 'X', 'installed': true, 'succeeded': false, 'failure': name,
      });
      expect(outcome.failure, isNotNull, reason: '$name should map');
      expect(outcome.statusLabel, isNotEmpty);
    }
  });

  test('an empty snapshot is an idle session', () {
    final session = AutomationSession.fromJson({});
    expect(session.state, SessionState.idle);
    expect(session.providers, isEmpty);
    expect(session.best, isNull);
  });

  test('a fare is labelled with its class only when GoGo picked one', () {
    final labelled = ProviderOutcome.fromJson({
      'id': 'yango', 'name': 'Yango', 'installed': true, 'succeeded': true,
      'amount': 320.0, 'currency': 'NPR', 'vehicleType': 'Bike',
    });
    expect(labelled.fareWithClass, 'NPR 320 · Bike');

    final unlabelled = ProviderOutcome.fromJson({
      'id': 'pathao', 'name': 'Pathao', 'installed': true, 'succeeded': true,
      'amount': 350.0, 'currency': 'NPR',
    });
    expect(unlabelled.vehicleType, isNull);
    expect(unlabelled.fareWithClass, 'NPR 350');
  });

  test('an empty result explains itself per provider', () {
    final session = AutomationSession.fromJson({
      'state': 'COMPLETED',
      'running': false,
      'providers': [
        {'id': 'pathao', 'name': 'Pathao', 'installed': true, 'succeeded': false,
         'failure': 'TIMEOUT'},
        {'id': 'indrive', 'name': 'inDrive', 'installed': true, 'succeeded': false,
         'failure': 'TIMEOUT'},
        {'id': 'uber', 'name': 'Uber', 'installed': false, 'succeeded': false,
         'failure': 'APP_NOT_INSTALLED'},
      ],
    });

    final explanation = session.emptyExplanation;
    expect(explanation, contains('Pathao and inDrive'));
    expect(explanation, contains('did not reach a price in time'));
    expect(explanation, contains('Uber'));
    expect(explanation, contains('not on this phone'));
  });

  test('every failure reason has a long explanation too', () {
    for (final reason in FailureReason.values) {
      expect(reason.explanation, isNotEmpty);
    }
  });
}
