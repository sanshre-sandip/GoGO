import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/widgets.dart';
import '../../models/automation_session.dart';
import '../../services/automation_service.dart';
import '../../services/handoff_service.dart';
import '../../services/quote_service.dart';

/// Live view of the comparison: GoGo opens each installed provider in turn and
/// reads the fare that app itself displays. Only fares actually extracted are
/// shown — a provider that could not be read says why.
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(automationSessionProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparing rides'),
        actions: [
          session.maybeWhen(
            data: (s) => s.running
                ? TextButton(
                    onPressed: ref.read(automationServiceProvider).cancel,
                    child: const Text('Cancel'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: session.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => MessageState(
            emoji: '⚠️',
            title: "Couldn't follow the comparison",
            body: '$e',
          ),
          data: (s) => s.providers.isEmpty
              ? const MessageState(
                  emoji: '🚦',
                  title: 'No comparison running',
                  body: 'Start one from the home screen.',
                )
              : ListView(
                  padding: const EdgeInsets.all(Spacing.md),
                  children: [
                    _Progress(session: s),
                    const SizedBox(height: Spacing.md),
                    if (s.finished && s.best != null) ...[
                      _BestFare(best: s.best!),
                      const SizedBox(height: Spacing.md),
                    ],
                    if (s.finished && s.best == null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(Spacing.md),
                          child: Text(
                            'No fare could be read from any app. GoGo does not '
                            'estimate — nothing is shown rather than a guess.',
                            style: text.bodyMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                    ],
                    for (final provider in s.providers)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.sm),
                        child: _ProviderRow(
                          provider: provider,
                          isCurrent: provider.id == s.currentProviderId && s.running,
                        ),
                      ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      'Fares are read from each provider\'s own screen at the '
                      'moment GoGo looked. Confirm in the app before booking.',
                      style: text.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.session});

  final AutomationSession session;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = session.providers.length;
    final done = session.checkedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          session.running
              ? 'Checking ${(done + 1).clamp(1, total)} of $total'
              : 'Checked $done of $total',
          style: text.titleMedium,
        ),
        const SizedBox(height: Spacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : done / total,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _BestFare extends StatelessWidget {
  const _BestFare({required this.best});

  final ProviderOutcome best;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🏆 Best detected fare', style: text.titleMedium),
            const SizedBox(height: Spacing.xs),
            Text(best.name, style: text.headlineSmall),
            Text(best.fareLabel, style: text.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class _ProviderRow extends ConsumerWidget {
  const _ProviderRow({required this.provider, required this.isCurrent});

  final ProviderOutcome provider;
  final bool isCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final brand = kProviders
        .where((p) => p.id == provider.id)
        .map((p) => p.color)
        .firstOrNull;

    final icon = provider.succeeded
        ? Icons.check_circle_rounded
        : provider.failure != null
            ? Icons.cancel_outlined
            : isCurrent
                ? Icons.hourglass_top_rounded
                : Icons.circle_outlined;

    return Card(
      child: ListTile(
        leading: Icon(icon, color: brand ?? scheme.outline),
        title: Text(provider.name, style: text.titleMedium),
        subtitle: Text(
          isCurrent && !provider.succeeded && provider.failure == null
              ? 'Checking…'
              : provider.statusLabel,
        ),
        trailing: provider.succeeded
            ? TextButton(
                onPressed: () => ref
                    .read(handoffServiceProvider)
                    .open(kProviders.firstWhere((p) => p.id == provider.id)),
                child: const Text('Open'),
              )
            : null,
      ),
    );
  }
}
