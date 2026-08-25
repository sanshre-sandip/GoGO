import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/location_point.dart';
import '../models/ride_preferences.dart';

/// Everything GoGo remembers lives here — on the device only.
class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  static const _onboarded = 'onboarded';
  static const _preferences = 'preferences';
  static const _floating = 'floating_assistant';
  static const _recents = 'recent_destinations';
  static const _maxRecents = 5;

  static Future<StorageService> create() async =>
      StorageService(await SharedPreferences.getInstance());

  bool get onboardingComplete => _prefs.getBool(_onboarded) ?? false;
  Future<void> completeOnboarding() => _prefs.setBool(_onboarded, true);

  RidePreferences get preferences {
    final raw = _prefs.getString(_preferences);
    if (raw == null) return const RidePreferences(pricePriority: 1, distancePriority: 1);
    return RidePreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> savePreferences(RidePreferences p) =>
      _prefs.setString(_preferences, jsonEncode(p.toJson()));

  bool get floatingAssistantEnabled => _prefs.getBool(_floating) ?? false;
  Future<void> setFloatingAssistantEnabled(bool on) => _prefs.setBool(_floating, on);

  List<LocationPoint> get recentDestinations =>
      (_prefs.getStringList(_recents) ?? [])
          .map((s) => LocationPoint.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();

  Future<void> addRecentDestination(LocationPoint point) {
    final kept = recentDestinations.where((p) => p.label != point.label).toList();
    final updated = [point, ...kept].take(_maxRecents);
    return _prefs.setStringList(
      _recents,
      updated.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }
}
