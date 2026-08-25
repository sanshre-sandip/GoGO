import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/widgets.dart';
import '../../models/provider_result.dart';
import '../../models/ride_preferences.dart';
import '../../services/comparison_service.dart';
import '../../services/handoff_service.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchProvider);
    final result = state.result;
    final others = [
      for (final r in state.providerResults)
        if (!r.hasLivePrice) r,
    ];
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Available Rides')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            if (result == null || result.isEmpty)
              const _NoLivePrices()
            else ...[
              _BestMatch(result: result),
              const SizedBox(height: Spacing.md),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: [
                  if (result.cheapest != null)
                    WinnerChip(
                      label: '💰 Cheapest',
                      value: result.cheapest!.provider.name,
                    ),
                  if (result.nearest != null)
                    WinnerChip(
                      label: '📍 Nearest',
                      value: result.nearest!.provider.name,
                    ),
                  if (result.fastest != null)
                    WinnerChip(
                      label: '⚡ Fastest',
                      value: result.fastest!.provider.name,
                    ),
                ],
              ),
              if (result.unusablePriorities.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.sm),
                  child: Text(
                    'Ignored: ${result.unusablePriorities.map((p) => p.label).join(', ')} — '
                    'the providers with live prices did not report that data.',
                    style: text.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: Spacing.lg),
              for (final scored in result.ranked)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: _LiveCard(
                    scored: scored,
                    isBest: scored.option.id == result.bestMatch!.id,
                    installed: state.providerResults
                        .any((r) => r.provider.id == scored.option.provider.id &&
                            r.appInstalled),
                  ),
                ),
            ],
            if (others.isNotEmpty) ...[
              const SizedBox(height: Spacing.sm),
              Text('No live price', style: text.titleMedium),
              const SizedBox(height: Spacing.xs),
              Text(
                'GoGo will not guess a fare. Open these apps to see theirs.',
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.md),
              for (final other in others)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: _UnavailableCard(result: other),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoLivePrices extends StatelessWidget {
  const _NoLivePrices();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: Spacing.xl),
        child: MessageState(
          emoji: '📭',
          title: 'No live prices for this trip',
          body: 'None of the providers returned a fare GoGo can compare. Open '
              'an app below to check its price directly.',
        ),
      );
}

class _BestMatch extends StatelessWidget {
  const _BestMatch({required this.result});

  final ComparisonResult result;

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
            Text('🏆 Best Match', style: text.titleMedium),
            const SizedBox(height: Spacing.xs),
            Text(result.bestMatch!.provider.name, style: text.headlineSmall),
            const SizedBox(height: Spacing.sm),
            Text(result.explanation, style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ProviderButton extends ConsumerWidget {
  const _ProviderButton({required this.result});

  final ProviderResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = result.provider;
    return OutlinedButton(
      onPressed: () async {
        final outcome = await ref.read(handoffServiceProvider).open(provider);
        if (outcome == Handoff.opened || !context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              outcome == Handoff.store
                  ? '${provider.name} is not installed — opening its store page.'
                  : '${provider.name} could not be opened on this device.',
            ),
          ),
        );
      },
      child: Text(
        result.appInstalled ? 'Open ${provider.name}' : 'Install ${provider.name}',
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({
    required this.scored,
    required this.isBest,
    required this.installed,
  });

  final ScoredRide scored;
  final bool isBest;
  final bool installed;

  @override
  Widget build(BuildContext context) {
    final option = scored.option;
    final text = Theme.of(context).textTheme;
    final facts = [
      if (option.distanceLabel != null) 'Driver ${option.distanceLabel}',
      if (option.etaLabel != null) option.etaLabel!,
      if (option.tripDistanceKm != null)
        '${option.tripDistanceKm!.toStringAsFixed(1)} km trip',
    ];

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: isBest
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 12, color: option.provider.color),
                const SizedBox(width: Spacing.sm),
                Text(option.provider.name, style: text.titleMedium),
                const Spacer(),
                Text(option.vehicleType, style: text.bodySmall),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Text(option.priceLabel, style: text.headlineSmall),
            if (facts.isNotEmpty) ...[
              const SizedBox(height: Spacing.xs),
              Text(facts.join(' · ')),
            ],
            const SizedBox(height: Spacing.md),
            _ProviderButton(
              result: ProviderResult(
                provider: option.provider,
                status: QuoteStatus.live,
                option: option,
                appInstalled: installed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({required this.result});

  final ProviderResult result;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 12, color: result.provider.color),
                const SizedBox(width: Spacing.sm),
                Text(result.provider.name, style: text.titleMedium),
                const Spacer(),
                Text(
                  result.appInstalled ? 'Installed' : 'Not installed',
                  style: text.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              result.statusMessage,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.md),
            _ProviderButton(result: result),
          ],
        ),
      ),
    );
  }
}
