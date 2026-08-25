import 'ride_option.dart';
import 'ride_provider.dart';

enum QuoteStatus {
  /// A real quote came back from the provider's API.
  live,

  /// GoGo implements this provider's API but has no credentials configured.
  missingCredentials,

  /// The provider offers no public fare API.
  noPublicApi,

  /// An API exists but its terms forbid comparison use.
  notPermitted,

  /// The API was called and failed or returned nothing for this route.
  unavailable,
}

/// What GoGo knows about one provider for one trip. Either a real quote, or an
/// explicit reason there is none — never an invented number.
class ProviderResult {
  final RideProvider provider;
  final QuoteStatus status;
  final RideOption? option;
  final bool appInstalled;

  /// Human-readable detail for [QuoteStatus.unavailable].
  final String? detail;

  const ProviderResult({
    required this.provider,
    required this.status,
    this.option,
    this.appInstalled = false,
    this.detail,
  });

  bool get hasLivePrice => status == QuoteStatus.live && option != null;

  String get statusMessage => switch (status) {
        QuoteStatus.live => 'Live price',
        QuoteStatus.missingCredentials =>
          'Needs API credentials — see Settings › Live pricing.',
        QuoteStatus.noPublicApi =>
          provider.pricingNote ?? 'No public fare API. Open the app for its price.',
        QuoteStatus.notPermitted =>
          provider.pricingNote ?? 'Their API terms do not allow price comparison.',
        QuoteStatus.unavailable => detail ?? 'No live price right now.',
      };

  ProviderResult copyWith({bool? appInstalled}) => ProviderResult(
        provider: provider,
        status: status,
        option: option,
        appInstalled: appInstalled ?? this.appInstalled,
        detail: detail,
      );
}
