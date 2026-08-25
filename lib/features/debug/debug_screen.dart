import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/automation_session.dart';
import '../../services/automation_service.dart';

/// Everything needed to work out why a comparison behaved the way it did on a
/// real phone: what is switched on, what is installed, where the session got
/// to, and the automation log.
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  List<AutomationLogEntry> _logs = const [];

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  Future<void> _refreshLogs() async {
    final logs = await ref.read(automationServiceProvider).logs();
    if (mounted) setState(() => _logs = logs.reversed.toList());
  }

  @override
  Widget build(BuildContext context) {
    final diagnostics = ref.watch(automationDiagnosticsProvider);
    final session = ref.watch(automationSessionProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Automation debug'),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(automationDiagnosticsProvider);
              _refreshLogs();
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            diagnostics.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Diagnostics unavailable: $e'),
              data: (d) => d == null
                  ? const Text('Automation is Android-only.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Row(
                          label: 'Accessibility enabled',
                          value: d.accessibilityEnabled ? 'Yes' : 'No',
                          ok: d.accessibilityEnabled,
                        ),
                        _Row(
                          label: 'Accessibility connected',
                          value: d.accessibilityConnected ? 'Yes' : 'No',
                          ok: d.accessibilityConnected,
                        ),
                        if (!d.accessibilityEnabled)
                          Padding(
                            padding: const EdgeInsets.only(top: Spacing.sm),
                            child: FilledButton(
                              onPressed: ref
                                  .read(automationServiceProvider)
                                  .openAccessibilitySettings,
                              child: const Text('Open Accessibility settings'),
                            ),
                          ),
                        const SizedBox(height: Spacing.md),
                        Text('Supported providers', style: text.titleMedium),
                        for (final p in d.providers)
                          _Row(
                            label: p.name,
                            value: p.installed ? 'Installed' : 'Not installed',
                            ok: p.installed,
                          ),
                      ],
                    ),
            ),
            const Divider(),
            Text('Session', style: text.titleMedium),
            session.when(
              loading: () => const Text('No session yet.'),
              error: (e, _) => Text('$e'),
              data: (s) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Row(label: 'State', value: s.state.name),
                  _Row(label: 'Session id', value: s.id.isEmpty ? '—' : s.id),
                  _Row(
                    label: 'Current provider',
                    value: s.currentProviderId ?? '—',
                  ),
                  for (final p in s.providers)
                    _Row(
                      label: p.name,
                      value: p.succeeded
                          ? '${p.fareLabel}  (${(p.confidence * 100).round()}%)'
                          : p.statusLabel,
                      ok: p.succeeded,
                    ),
                  if (s.providers.any((p) => p.rawText != null)) ...[
                    const SizedBox(height: Spacing.sm),
                    Text('Latest extracted text', style: text.titleSmall),
                    for (final p in s.providers.where((p) => p.rawText != null))
                      Text(
                        '${p.name}: "${p.rawText}"',
                        style: text.bodySmall,
                      ),
                  ],
                ],
              ),
            ),
            const Divider(),
            Text('Automation log', style: text.titleMedium),
            const SizedBox(height: Spacing.sm),
            if (_logs.isEmpty)
              Text('Nothing logged yet.', style: text.bodySmall)
            else
              for (final entry in _logs.take(120))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${entry.timestamp.toIso8601String().substring(11, 19)} '
                    '[${entry.provider ?? entry.sessionId}] ${entry.event} '
                    '${entry.detail}',
                    style: text.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.ok});

  final String label;
  final String value;
  final bool? ok;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              color: ok == null
                  ? scheme.onSurfaceVariant
                  : (ok! ? scheme.primary : scheme.error),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
