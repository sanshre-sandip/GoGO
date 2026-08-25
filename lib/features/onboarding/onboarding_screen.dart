import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/widgets.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            children: [
              const Spacer(),
              const GoLogo(size: 96),
              const SizedBox(height: Spacing.lg),
              Text(Brand.name, style: text.displaySmall),
              const SizedBox(height: Spacing.sm),
              Text(Brand.tagline, style: text.titleMedium),
              const SizedBox(height: Spacing.md),
              Text(
                'Compare ride options based on what matters to you —\n'
                'price, how close the driver is, or how fast they arrive.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  await ref.read(storageProvider).completeOnboarding();
                  if (context.mounted) context.go('/');
                },
                child: const Text('Get Started'),
              ),
              const SizedBox(height: Spacing.md),
              Text(
                'GoGo uses your location only to estimate rides. Nothing leaves your phone.',
                textAlign: TextAlign.center,
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
