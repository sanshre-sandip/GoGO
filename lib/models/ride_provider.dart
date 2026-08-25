import 'package:flutter/material.dart';

/// How a provider can be reached for live pricing.
enum PricingSupport {
  /// An official API exists and GoGo implements it (may still need credentials).
  officialApi,

  /// No public fare API is available to third parties.
  none,

  /// An API exists but its terms forbid using it for price comparison.
  forbiddenByTerms,
}

/// A ride-hailing provider.
///
/// [packageId] and [scheme] are verified against a real device — see
/// `docs/provider-verification.md`. Never add a value here that has not been
/// checked with `adb shell cmd package resolve-activity`.
class RideProvider {
  final String id;
  final String name;
  final Color color;
  final String packageId;

  /// Custom URI that opens the app, verified to resolve on device.
  final String? scheme;

  final PricingSupport pricing;

  /// Why live pricing is unavailable, shown verbatim in the UI.
  final String? pricingNote;

  const RideProvider({
    required this.id,
    required this.name,
    required this.color,
    required this.packageId,
    required this.pricing,
    this.scheme,
    this.pricingNote,
  });
}
