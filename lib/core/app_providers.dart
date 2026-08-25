import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location_point.dart';
import '../models/ride_preferences.dart';
import '../models/provider_result.dart';
import '../services/comparison_service.dart';
import '../services/location_service.dart';
import '../services/preference_interpreter.dart';
import '../services/quote_service.dart';
import '../services/storage_service.dart';

/// Overridden in main() once SharedPreferences has loaded.
final storageProvider = Provider<StorageService>(
  (ref) => throw UnimplementedError('storageProvider must be overridden'),
);

final locationServiceProvider = Provider((ref) => const LocationService());
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

  /// Per-provider outcome, including the ones with no live price.
  final List<ProviderResult> providerResults;

  const SearchState({
    this.pickup,
    this.destination,
    this.preferences = const RidePreferences(),
    this.locating = false,
    this.searching = false,
    this.locationError,
    this.searchError,
    this.result,
    this.providerResults = const [],
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
    List<ProviderResult>? providerResults,
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
        providerResults: providerResults ?? this.providerResults,
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
    if (state.locating) return; // a request is already in flight
    state = state.copyWith(locating: true);
    try {
      final point = await ref.read(locationServiceProvider).current();
      state = state.copyWith(pickup: point, locating: false);
    } on LocationException catch (e) {
      state = state.copyWith(locating: false, locationError: e.message);
    } catch (_) {
      state = state.copyWith(
        locating: false,
        locationError: LocationFailure.unavailable.message,
      );
    }
  }

  void setDestination(LocationPoint point) {
    state = state.copyWith(destination: point);
    ref.read(storageProvider).addRecentDestination(point);
  }

  void togglePriority(Priority priority, bool selected) {
    final next = {...state.preferences.selection};
    selected ? next.add(priority) : next.remove(priority);
    setPreferences(RidePreferences.fromSelection(next));
  }

  void setPreferences(RidePreferences prefs) {
    state = state.copyWith(preferences: prefs);
    ref.read(storageProvider).savePreferences(prefs);
  }

  /// Asks every provider for a real quote. Returns true when at least one came
  /// back with a live price to rank.
  Future<bool> findRides() async {
    final destination = state.destination;
    final pickup = state.pickup;
    if (destination == null) {
      state = state.copyWith(searchError: 'Pick a destination first.');
      return false;
    }
    if (pickup == null) {
      state = state.copyWith(
        searchError: 'GoGo needs your pickup location to request quotes.',
      );
      return false;
    }

    state = state.copyWith(searching: true);
    try {
      final results = await ref
          .read(quoteServiceProvider)
          .quoteAll(pickup: pickup, destination: destination);
      final live = [
        for (final r in results)
          if (r.hasLivePrice) r.option!,
      ];
      final result =
          ref.read(comparisonServiceProvider).compare(live, state.preferences);
      state = state.copyWith(
        searching: false,
        result: result,
        providerResults: results,
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        searching: false,
        searchError: "Couldn't reach the providers. Check your connection.",
      );
      return false;
    }
  }
}

final searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
