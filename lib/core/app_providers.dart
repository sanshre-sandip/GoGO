import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location_point.dart';
import '../models/ride_preferences.dart';
import '../services/comparison_service.dart';
import '../services/location_service.dart';
import '../services/preference_interpreter.dart';
import '../services/provider_service.dart';
import '../services/storage_service.dart';

/// Overridden in main() once SharedPreferences has loaded.
final storageProvider = Provider<StorageService>(
  (ref) => throw UnimplementedError('storageProvider must be overridden'),
);

final locationServiceProvider = Provider((ref) => const LocationService());
final providerServiceProvider =
    Provider<ProviderService>((ref) => const MockProviderService());
final comparisonServiceProvider = Provider((ref) => const ComparisonService());
final preferenceInterpreterProvider =
    Provider<PreferenceInterpreter>((ref) => const RuleBasedPreferenceInterpreter());

class SearchState {
  final LocationPoint? pickup;
  final LocationPoint? destination;
  final RidePreferences preferences;
  final bool locating;
  final bool searching;
  final String? locationError;
  final String? searchError;
  final ComparisonResult? result;

  const SearchState({
    this.pickup,
    this.destination,
    this.preferences = const RidePreferences(),
    this.locating = false,
    this.searching = false,
    this.locationError,
    this.searchError,
    this.result,
  });

  bool get canSearch => destination != null && !searching;

  SearchState copyWith({
    LocationPoint? pickup,
    LocationPoint? destination,
    RidePreferences? preferences,
    bool? locating,
    bool? searching,
    String? locationError,
    String? searchError,
    ComparisonResult? result,
  }) =>
      SearchState(
        pickup: pickup ?? this.pickup,
        destination: destination ?? this.destination,
        preferences: preferences ?? this.preferences,
        locating: locating ?? this.locating,
        searching: searching ?? this.searching,
        locationError: locationError,
        searchError: searchError,
        result: result ?? this.result,
      );
}

class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() {
    final state = SearchState(preferences: ref.read(storageProvider).preferences);
    Future.microtask(refreshLocation);
    return state;
  }

  Future<void> refreshLocation() async {
    state = state.copyWith(locating: true);
    try {
      final point = await ref.read(locationServiceProvider).current();
      state = state.copyWith(pickup: point, locating: false);
    } on LocationException catch (e) {
      state = state.copyWith(locating: false, locationError: e.message);
    }
  }

  void setDestination(LocationPoint point) {
    state = state.copyWith(destination: point);
    ref.read(storageProvider).addRecentDestination(point);
  }

  void togglePriority(Priority priority, bool selected) {
    final next = {...state.preferences.selection};
    selected ? next.add(priority) : next.remove(priority);
    setPreferences(
      RidePreferences.fromSelection(next)
        ..hashCode, // keep analyzer quiet about cascade-only use
    );
  }

  void setPreferences(RidePreferences prefs) {
    state = state.copyWith(preferences: prefs);
    ref.read(storageProvider).savePreferences(prefs);
  }

  /// Returns true when there is a result worth showing.
  Future<bool> findRides() async {
    final destination = state.destination;
    if (destination == null) {
      state = state.copyWith(searchError: 'Pick a destination first.');
      return false;
    }

    state = state.copyWith(searching: true);
    final pickup = state.pickup ?? destination;
    final tripKm = ref.read(locationServiceProvider).distanceKm(pickup, destination);

    try {
      final options = await ref.read(providerServiceProvider).quote(
            pickup: pickup,
            destination: destination,
            tripDistanceKm: tripKm,
          );
      final result =
          ref.read(comparisonServiceProvider).compare(options, state.preferences);
      state = state.copyWith(searching: false, result: result);
      return !result.isEmpty;
    } catch (_) {
      state = state.copyWith(
        searching: false,
        searchError: "Couldn't load ride options. Please try again.",
      );
      return false;
    }
  }
}

final searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
