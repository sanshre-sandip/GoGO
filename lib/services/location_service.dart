import 'package:geocoding/geocoding.dart';
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

const _fallbackLabel = 'Current location';

/// Plus codes ("M8C2+R8Q") are what Android's geocoder returns when it has no
/// street name. They are coordinates in disguise, so we skip them and use the
/// next useful part instead.
final _plusCode = RegExp(r'^[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,3}$');

/// Google-Maps-ish short address: the specific bit, then the city.
/// Kept pure and top-level so it can be unit tested without a device.
String placeLabel({
  String? name,
  String? street,
  String? subLocality,
  String? locality,
}) {
  bool useful(String? v) =>
      v != null &&
      v.trim().isNotEmpty &&
      v.trim() != locality?.trim() &&
      !_plusCode.hasMatch(v.trim());

  final specific = [name, street, subLocality].firstWhere(useful, orElse: () => null);
  final city = locality?.trim();

  return [
    if (useful(specific)) specific!.trim(),
    if (city != null && city.isNotEmpty) city,
  ].join(', ');
}

class LocationService {
  const LocationService();

  Future<LocationPoint> current() async {
    try {
      return await _locate();
    } on LocationException {
      rethrow;
    } catch (_) {
      // Anything geolocator throws (permission request already in flight,
      // platform errors) still has to end the spinner.
      throw const LocationException(LocationFailure.unavailable);
    }
  }

  Future<LocationPoint> _locate() async {
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

    // A fresh fix can take forever indoors, so cap the wait and fall back to
    // the last known position rather than spinning.
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return await _point(p);
    } catch (_) {
      Position? last;
      try {
        last = await Geolocator.getLastKnownPosition();
      } catch (_) {
        last = null;
      }
      if (last == null) throw const LocationException(LocationFailure.unavailable);
      return await _point(last);
    }
  }

  Future<LocationPoint> _point(Position p) async => LocationPoint(
        latitude: p.latitude,
        longitude: p.longitude,
        label: await describeCoordinates(p.latitude, p.longitude),
      );

  /// Reverse geocoding via the platform's own geocoder — no API key, no network
  /// code of ours. Falls back to a plain label where the device has no geocoder.
  Future<String> describeCoordinates(double latitude, double longitude) async {
    try {
      final places = await Geocoding().placemarkFromCoordinates(latitude, longitude);
      if (places.isEmpty) return _fallbackLabel;
      final p = places.first;
      final name = placeLabel(
        name: p.name,
        street: p.street,
        subLocality: p.subLocality,
        locality: p.locality,
      );
      return name.isEmpty ? _fallbackLabel : name;
    } catch (_) {
      return _fallbackLabel;
    }
  }

  double distanceKm(LocationPoint a, LocationPoint b) =>
      Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude) /
      1000;
}
