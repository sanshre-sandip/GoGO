import 'package:geolocator/geolocator.dart';

import '../models/location_point.dart';

/// Friendly, non-technical failure reasons — the UI shows these directly.
enum LocationFailure { serviceDisabled, permissionDenied, permanentlyDenied, unavailable }

extension LocationFailureMessage on LocationFailure {
  String get message => switch (this) {
        LocationFailure.serviceDisabled =>
          'Location is turned off. Turn it on to find rides near you.',
        LocationFailure.permissionDenied =>
          'GoGo needs your location to see how far away drivers are.',
        LocationFailure.permanentlyDenied =>
          'Location access is blocked. Enable it in Settings to use your current location.',
        LocationFailure.unavailable =>
          "Couldn't get your location right now. Try again in a moment.",
      };
}

class LocationException implements Exception {
  final LocationFailure failure;
  const LocationException(this.failure);
  String get message => failure.message;
}

class LocationService {
  const LocationService();

  Future<LocationPoint> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(LocationFailure.permanentlyDenied);
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(LocationFailure.permissionDenied);
    }

    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      return LocationPoint(
        latitude: p.latitude,
        longitude: p.longitude,
        label: 'Current location',
      );
    } catch (_) {
      throw const LocationException(LocationFailure.unavailable);
    }
  }

  double distanceKm(LocationPoint a, LocationPoint b) =>
      Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude) /
      1000;
}
