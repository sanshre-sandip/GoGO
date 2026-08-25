import 'package:flutter/material.dart';

import '../../models/ride_preferences.dart';
import 'app_theme.dart';

/// Rounded "G" mark: bold silhouette with a forward motion streak.
class GoLogo extends StatelessWidget {
  const GoLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Brand.primary, Brand.accent],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: size * 0.1,
            bottom: size * 0.22,
            child: Container(
              width: size * 0.22,
              height: size * 0.06,
              decoration: BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
          ),
          Text(
            'G',
            style: TextStyle(
              fontSize: size * 0.58,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Selectable priority row used on Home and in the floating overlay.
class PriorityTile extends StatelessWidget {
  const PriorityTile({
    super.key,
    required this.priority,
    required this.selected,
    required this.onChanged,
    this.dense = false,
  });

  final Priority priority;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.sm),
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: dense ? Spacing.sm : Spacing.md - 2,
        ),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          children: [
            Text(priority.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: Spacing.sm + 2),
            Expanded(
              child: Text(
                priority.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// One-line labelled badge, e.g. "💰 Cheapest — Provider C".
class WinnerChip extends StatelessWidget {
  const WinnerChip({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md - 4,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        '$label  $value',
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

/// Friendly empty/error state instead of a raw exception.
class MessageState extends StatelessWidget {
  const MessageState({
    super.key,
    required this.emoji,
    required this.title,
    this.body,
    this.action,
  });

  final String emoji;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: Spacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (body != null) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: Spacing.lg), action!],
          ],
        ),
      ),
    );
  }
}
