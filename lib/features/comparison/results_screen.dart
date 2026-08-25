import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/widgets.dart';
import '../../services/comparison_service.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchProvider);
    final result = state.result;
    final text = Theme.of(context).textTheme;

    if (result == null || result.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Available Rides')),
        body: const MessageState(
          emoji: '🚕',
          title: 'No rides available',
          body: 'Nobody is nearby right now. Try again in a minute.',
        ),
      );
    }

    final best = result.ranked.first.option;
    return Scaffold(
      appBar: AppBar(title: const Text('Available Rides')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🏆 Best Match', style: text.titleMedium),
                    const SizedBox(height: Spacing.xs),
                    Text(best.provider.name, style: text.headlineSmall),
                    const SizedBox(height: Spacing.sm),
                    Text(result.explanation, style: text.bodyMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                if (result.cheapest != null)
                  WinnerChip(label: '💰 Cheapest', value: result.cheapest!.provider.name),
                if (result.nearest != null)
                  WinnerChip(label: '📍 Nearest', value: result.nearest!.provider.name),
                if (result.fastest != null)
                  WinnerChip(label: '⚡ Fastest', value: result.fastest!.provider.name),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            for (final scored in result.ranked)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: _RideCard(scored: scored, isBest: scored.option.id == best.id),
              ),
            if (ref.read(providerServiceProvider).isMock)
              Text(
                'Prices and driver positions are simulated for this preview.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({required this.scored, required this.isBest});

  final ScoredRide scored;
  final bool isBest;

  Future<void> _openProvider(BuildContext context) async {
    final option = scored.option;
    final link = option.provider.deepLink;
    var opened = false;
    if (link != null) {
      try {
        opened = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false; // app not installed / link unsupported
      }
    }

    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${option.provider.name} can\'t be opened from GoGo yet — '
          'open the app manually to book.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final option = scored.option;
    final text = Theme.of(context).textTheme;
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
            const SizedBox(height: Spacing.xs),
            Text('Driver ${option.distanceLabel} · ${option.etaLabel}'),
            const SizedBox(height: Spacing.md),
            OutlinedButton(
              onPressed: () => _openProvider(context),
              child: const Text('Open Provider'),
            ),
          ],
        ),
      ),
    );
  }
}
