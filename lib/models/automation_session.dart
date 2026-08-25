/// Mirrors the native session state machine in ComparisonSession.kt.
enum SessionState {
  idle,
  preparingProvider,
  launchingProvider,
  waitingForUi,
  enteringTripData,
  waitingForFare,
  fareDetected,
  providerFailed,
  nextProvider,
  comparing,
  completed,
  cancelled,
}

SessionState _stateFrom(String? name) {
  final normalized = (name ?? 'IDLE').toLowerCase().replaceAll('_', '');
  return SessionState.values.firstWhere(
    (s) => s.name.toLowerCase() == normalized,
    orElse: () => SessionState.idle,
  );
}

/// Why a provider produced no fare. GoGo shows the reason, never a substitute
/// number.
enum FailureReason {
  appNotInstalled,
  accessibilityUnavailable,
  launchFailed,
  blockedScreen,
  tripEntryUnavailable,
  fareNotFound,
  lowConfidence,
  ambiguous,
  timeout,
  cancelled,
}

extension FailureExplanation on FailureReason {
  /// The longer "why", for the results screen.
  String get explanation => switch (this) {
        FailureReason.appNotInstalled =>
          'the app is not on this phone, so there was nothing to ask.',
        FailureReason.accessibilityUnavailable =>
          "GoGo's accessibility service was off, so it could not read the screen.",
        FailureReason.launchFailed => 'the app would not open.',
        FailureReason.blockedScreen =>
          'the app wanted a sign-in or a permission before showing prices.',
        FailureReason.tripEntryUnavailable =>
          'GoGo could not put the destination into that app\'s own search.',
        FailureReason.fareNotFound =>
          'the app never displayed a price GoGo could read.',
        FailureReason.lowConfidence =>
          'a number was on screen but GoGo was not sure it was the fare, so it '
              'refused to report it.',
        FailureReason.ambiguous =>
          'several prices were on screen at once and GoGo would not pick one.',
        FailureReason.timeout =>
          'the app did not reach a price in time — usually trip entry stalling.',
        FailureReason.cancelled => 'you stopped the comparison.',
      };
}

extension FailureMessage on FailureReason {
  String get message => switch (this) {
        FailureReason.appNotInstalled => 'Not installed',
        FailureReason.accessibilityUnavailable => 'Accessibility service is off',
        FailureReason.launchFailed => "Couldn't open the app",
        FailureReason.blockedScreen => 'The app needs you to sign in first',
        FailureReason.tripEntryUnavailable => 'Trip entry unavailable',
        FailureReason.fareNotFound => 'No fare appeared',
        FailureReason.lowConfidence => "Couldn't read the fare clearly",
        FailureReason.ambiguous => 'Several fares on screen',
        FailureReason.timeout => 'Timed out',
        FailureReason.cancelled => 'Cancelled',
      };
}

FailureReason? _failureFrom(String? name) {
  if (name == null) return null;
  final normalized = name.toLowerCase().replaceAll('_', '');
  for (final reason in FailureReason.values) {
    if (reason.name.toLowerCase() == normalized) return reason;
  }
  return null;
}

/// One provider's outcome: a fare that was genuinely read off its screen, or a
/// reason there is none.
class ProviderOutcome {
  final String id;
  final String name;
  final String packageId;
  final bool installed;
  final bool succeeded;
  final double? amount;
  final String? currency;
  final String? rawText;

  /// The ride class the fare belongs to, when GoGo actually selected one.
  final String? vehicleType;
  final double confidence;
  final DateTime? detectedAt;
  final FailureReason? failure;
  final String? note;

  const ProviderOutcome({
    required this.id,
    required this.name,
    required this.packageId,
    required this.installed,
    required this.succeeded,
    this.amount,
    this.currency,
    this.rawText,
    this.vehicleType,
    this.confidence = 0,
    this.detectedAt,
    this.failure,
    this.note,
  });

  factory ProviderOutcome.fromJson(Map<String, dynamic> json) => ProviderOutcome(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        packageId: json['package'] as String? ?? '',
        installed: json['installed'] as bool? ?? false,
        succeeded: json['succeeded'] as bool? ?? false,
        amount: (json['amount'] as num?)?.toDouble(),
        currency: json['currency'] as String?,
        rawText: json['rawText'] as String?,
        vehicleType: json['vehicleType'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        detectedAt: json['timestamp'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((json['timestamp'] as num).toInt()),
        failure: _failureFrom(json['failure'] as String?),
        note: json['note'] as String?,
      );

  String get fareLabel =>
      succeeded ? '${currency ?? ''} ${amount!.toStringAsFixed(0)}'.trim() : '';

  /// "NPR 350 · Bike", or just the fare when the class is unknown — GoGo does
  /// not label a fare with a class it did not pick.
  String get fareWithClass =>
      vehicleType == null ? fareLabel : '$fareLabel · $vehicleType';

  String get statusLabel => succeeded
      ? fareLabel
      : note ?? failure?.message ?? 'Waiting';
}

/// A snapshot of the running (or finished) comparison.
class AutomationSession {
  final String id;
  final SessionState state;
  final bool running;
  final String? currentProviderId;
  final List<ProviderOutcome> providers;

  const AutomationSession({
    this.id = '',
    this.state = SessionState.idle,
    this.running = false,
    this.currentProviderId,
    this.providers = const [],
  });

  factory AutomationSession.fromJson(Map<String, dynamic> json) => AutomationSession(
        id: json['sessionId'] as String? ?? '',
        state: _stateFrom(json['state'] as String?),
        running: json['running'] as bool? ?? false,
        currentProviderId: json['currentProvider'] as String?,
        providers: [
          for (final p in (json['providers'] as List? ?? const []))
            ProviderOutcome.fromJson((p as Map).cast<String, dynamic>()),
        ],
      );

  List<ProviderOutcome> get detected =>
      providers.where((p) => p.succeeded).toList()
        ..sort((a, b) => a.amount!.compareTo(b.amount!));

  ProviderOutcome? get best => detected.isEmpty ? null : detected.first;

  int get checkedCount =>
      providers.where((p) => p.succeeded || p.failure != null).length;

  bool get finished =>
      state == SessionState.completed || state == SessionState.cancelled;

  /// Plain-English account of why no fare came back, built from what actually
  /// happened per provider rather than a generic apology.
  String get emptyExplanation {
    if (providers.isEmpty) return 'No comparison has run yet.';

    final byReason = <FailureReason, List<String>>{};
    for (final p in providers.where((p) => p.failure != null)) {
      byReason.putIfAbsent(p.failure!, () => []).add(p.name);
    }
    if (byReason.isEmpty) return 'No provider reported a fare.';

    final parts = byReason.entries.map((e) {
      final names = e.key == FailureReason.appNotInstalled
          ? e.value.join(', ')
          : e.value.join(' and ');
      return '$names: ${e.key.explanation}';
    });
    return parts.join('\n');
  }
}

/// One line from the native automation log.
class AutomationLogEntry {
  final DateTime timestamp;
  final String sessionId;
  final String? provider;
  final String event;
  final String detail;

  const AutomationLogEntry({
    required this.timestamp,
    required this.sessionId,
    required this.event,
    this.provider,
    this.detail = '',
  });

  factory AutomationLogEntry.fromJson(Map<String, dynamic> json) => AutomationLogEntry(
        timestamp:
            DateTime.fromMillisecondsSinceEpoch((json['timestamp'] as num).toInt()),
        sessionId: json['session'] as String? ?? '',
        provider: json['provider'] as String?,
        event: json['event'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
      );
}

/// What the debug screen needs to explain why a comparison can or cannot run.
class AutomationDiagnostics {
  final bool accessibilityEnabled;
  final bool accessibilityConnected;
  final List<ProviderOutcome> providers;
  final AutomationSession session;

  const AutomationDiagnostics({
    required this.accessibilityEnabled,
    required this.accessibilityConnected,
    required this.providers,
    required this.session,
  });

  factory AutomationDiagnostics.fromJson(Map<String, dynamic> json) =>
      AutomationDiagnostics(
        accessibilityEnabled: json['accessibilityEnabled'] as bool? ?? false,
        accessibilityConnected: json['accessibilityConnected'] as bool? ?? false,
        providers: [
          for (final p in (json['providers'] as List? ?? const []))
            ProviderOutcome.fromJson((p as Map).cast<String, dynamic>()),
        ],
        session: AutomationSession.fromJson(
          ((json['session'] as Map?) ?? {}).cast<String, dynamic>(),
        ),
      );
}
