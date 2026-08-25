import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/widgets.dart';
import '../../models/ride_preferences.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const GoLogo(size: 28),
            const SizedBox(width: Spacing.sm),
            Text(Brand.name, style: text.headlineSmall),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            Text('Where are you going?', style: text.headlineSmall),
            const SizedBox(height: Spacing.lg),
            _LocationRow(
              icon: Icons.my_location_rounded,
              title: state.locating
                  ? 'Finding your location…'
                  : state.pickup?.label ?? 'Location unavailable',
              subtitle: state.locationError ?? state.pickup?.toString(),
              isError: state.locationError != null,
              trailing: state.locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      onPressed: notifier.refreshLocation,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Retry',
                    ),
            ),
            const SizedBox(height: Spacing.sm),
            _LocationRow(
              icon: Icons.place_rounded,
              title: state.destination?.label ?? 'Search destination',
              subtitle: state.destination == null ? 'Destination' : null,
              onTap: () => context.push('/destination'),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
            const SizedBox(height: Spacing.xl),
            Text('What matters most?', style: text.titleMedium),
            const SizedBox(height: Spacing.sm),
            for (final priority in Priority.values)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: PriorityTile(
                  priority: priority,
                  selected: state.preferences.selection.contains(priority),
                  onChanged: (v) => notifier.togglePriority(priority, v),
                ),
              ),
            if (state.preferences.isEmpty)
              Text(
                'Nothing selected — GoGo will balance all three.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: state.canSearch
                  ? () async {
                      final ok = await notifier.findRides();
                      if (!context.mounted) return;
                      if (ok) {
                        context.push('/results');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ref.read(searchProvider).searchError ??
                                  'No rides available right now.',
                            ),
                          ),
                        );
                      }
                    }
                  : null,
              child: state.searching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('FIND RIDES'),
            ),
            if (state.destination == null)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.sm),
                child: Text(
                  'Pick a destination to compare rides.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        leading: Icon(icon, color: isError ? scheme.error : scheme.primary),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
