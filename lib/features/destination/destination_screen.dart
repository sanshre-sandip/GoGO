import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/location_point.dart';

/// No geocoding API in the MVP: a short local list plus free text.
const _presets = <LocationPoint>[
  LocationPoint(latitude: 27.7172, longitude: 85.3240, label: 'Kathmandu Durbar Square'),
  LocationPoint(latitude: 27.7215, longitude: 85.3620, label: 'Boudhanath Stupa'),
  LocationPoint(latitude: 27.6966, longitude: 85.2907, label: 'Tribhuvan Airport'),
  LocationPoint(latitude: 27.7096, longitude: 85.3145, label: 'Thamel'),
  LocationPoint(latitude: 27.6710, longitude: 85.4298, label: 'Bhaktapur'),
  LocationPoint(latitude: 27.6588, longitude: 85.3247, label: 'Patan Durbar Square'),
];

class DestinationScreen extends ConsumerStatefulWidget {
  const DestinationScreen({super.key});

  @override
  ConsumerState<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends ConsumerState<DestinationScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _choose(LocationPoint point) {
    ref.read(searchProvider.notifier).setDestination(point);
    context.pop();
  }

  /// Free text has no coordinates to look up, so place it near the pickup
  /// in a stable, made-up spot. Good enough for mock quotes.
  LocationPoint _approximate(String label) {
    final origin = ref.read(searchProvider).pickup ?? _presets.first;
    final seed = label.hashCode;
    return LocationPoint(
      latitude: origin.latitude + ((seed % 60) - 30) / 1000,
      longitude: origin.longitude + ((seed ~/ 60 % 60) - 30) / 1000,
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final recents = ref.read(storageProvider).recentDestinations;
    final matches = _presets
        .where((p) => p.label.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Destination')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Search destination',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
              onSubmitted: (v) {
                final label = v.trim();
                if (label.isNotEmpty) _choose(_approximate(label));
              },
            ),
            if (recents.isNotEmpty && _query.isEmpty) ...[
              const _SectionTitle('Recent'),
              for (final r in recents)
                ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: Text(r.label),
                  onTap: () => _choose(r),
                ),
            ],
            const _SectionTitle('Popular places'),
            for (final p in matches)
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(p.label),
                onTap: () => _choose(p),
              ),
            if (matches.isEmpty && _query.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.add_location_alt_outlined),
                title: Text('Use "$_query"'),
                subtitle: const Text('Approximate location'),
                onTap: () => _choose(_approximate(_query)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xs, Spacing.lg, 0, Spacing.xs),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
