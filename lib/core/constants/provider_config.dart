/// Credentials for provider APIs, supplied at build time. Nothing is hardcoded
/// and there is no default that "works" — an unconfigured provider reports
/// [QuoteStatus.missingCredentials] instead of inventing a price.
///
///   flutter build apk --release \
///     --dart-define=YANGO_CLID=your_clid \
///     --dart-define=YANGO_API_KEY=your_key
///
/// Yango issues both to partner-program members: integration-support@yango.com
library;

class ProviderConfig {
  const ProviderConfig();

  static const yangoClid = String.fromEnvironment('YANGO_CLID');
  static const yangoApiKey = String.fromEnvironment('YANGO_API_KEY');

  bool get yangoConfigured => yangoClid.isNotEmpty && yangoApiKey.isNotEmpty;

  /// What a developer still has to supply, for display in Settings.
  List<String> get missing => [
        if (yangoClid.isEmpty) 'YANGO_CLID=<your clid>',
        if (yangoApiKey.isEmpty) 'YANGO_API_KEY=<your key>',
      ];
}
