import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/provider_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ride_provider.dart';
import '../../services/quote_service.dart';
import '../floating_assistant/overlay_service.dart';

/// Shows exactly which providers can return a live fare, and what is still
/// needed to switch the rest on. Nothing here pretends to work.
class _LivePricing extends StatelessWidget {
  const _LivePricing();

  @override
  Widget build(BuildContext context) {
    const config = ProviderConfig();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    String status(RideProvider p) => switch (p.pricing) {
          PricingSupport.officialApi =>
            config.yangoConfigured ? 'Live pricing on' : 'Needs credentials',
          PricingSupport.none => 'No public fare API',
          PricingSupport.forbiddenByTerms => 'Not permitted by their terms',
        };

    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live pricing', style: text.titleMedium),
          const SizedBox(height: Spacing.sm),
          for (final p in kProviders)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 10, color: p.color),
                  const SizedBox(width: Spacing.sm),
                  Expanded(child: Text(p.name, style: text.bodyMedium)),
                  Text(
                    status(p),
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          if (config.missing.isNotEmpty) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              'To enable live pricing, rebuild with:\n'
              '${config.missing.map((m) => '  --dart-define=$m').join('\n')}',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(floatingAssistantProvider);
    final overlay = ref.read(overlayServiceProvider);
    final text = Theme.of(context).textTheme;

    Future<void> toggle(bool value) async {
      final problem =
          await ref.read(floatingAssistantProvider.notifier).setEnabled(value);
      if (problem != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(problem)));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            SwitchListTile(
              value: running,
              onChanged: overlay.supported ? toggle : null,
              title: const Text('Floating Assistant'),
              subtitle: Text(
                overlay.supported
                    ? 'Show a GoGo button on top of other apps so you can compare '
                        'rides without switching back.'
                    : 'Available on Android only.',
              ),
            ),
            if (overlay.supported)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: running ? null : () => toggle(true),
                        child: const Text('Start'),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: running ? () => toggle(false) : null,
                        child: const Text('Stop'),
                      ),
                    ),
                  ],
                ),
              ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Automation debug'),
              subtitle: const Text(
                'Accessibility status, installed providers, session state and logs.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/debug'),
            ),
            const Divider(),
            const _LivePricing(),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Privacy', style: text.titleMedium),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    '• Location is used only to estimate how far drivers are, and is '
                    'never uploaded.\n'
                    '• Your priorities and recent destinations stay on this device.\n'
                    '• The floating assistant only shows GoGo\'s own button — it never '
                    'reads what is on your screen.\n'
                    '• GoGo never books a ride for you; you always finish in the '
                    'provider\'s own app.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: Spacing.lg),
                  Text('${Brand.name} — ${Brand.tagline}', style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
