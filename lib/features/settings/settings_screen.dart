import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../floating_assistant/overlay_service.dart';

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
