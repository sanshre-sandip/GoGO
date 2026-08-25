import '../../models/location_point.dart';
import '../../models/provider_result.dart';
import '../../models/ride_provider.dart';

/// One provider's live-pricing integration.
abstract class ProviderConnector {
  RideProvider get provider;

  /// False when the connector exists but has no credentials configured.
  bool get isConfigured;

  Future<ProviderResult> quote({
    required LocationPoint pickup,
    required LocationPoint destination,
  });
}

/// For providers with no public fare API. It never returns a price — it says
/// why there isn't one, so the UI can send the user to the app instead.
class HandoffOnlyConnector implements ProviderConnector {
  const HandoffOnlyConnector(this.provider);

  @override
  final RideProvider provider;

  @override
  bool get isConfigured => true;

  @override
  Future<ProviderResult> quote({
    required LocationPoint pickup,
    required LocationPoint destination,
  }) async =>
      ProviderResult(
        provider: provider,
        status: provider.pricing == PricingSupport.forbiddenByTerms
            ? QuoteStatus.notPermitted
            : QuoteStatus.noPublicApi,
      );
}
