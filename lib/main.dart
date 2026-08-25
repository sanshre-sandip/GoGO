import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_providers.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/floating_assistant/overlay_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.create();
  runApp(
    ProviderScope(
      overrides: [storageProvider.overrideWithValue(storage)],
      child: const GoGoApp(),
    ),
  );
}

class GoGoApp extends ConsumerStatefulWidget {
  const GoGoApp({super.key});

  @override
  ConsumerState<GoGoApp> createState() => _GoGoAppState();
}

class _GoGoAppState extends ConsumerState<GoGoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _handleOverlayRequest();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _handleOverlayRequest();
  }

  /// The floating overlay hands priorities over by launching the app.
  Future<void> _handleOverlayRequest() async {
    final prefs = await ref.read(overlayServiceProvider).consumePendingRequest();
    if (prefs == null || !mounted) return;
    ref.read(searchProvider.notifier).setPreferences(prefs);
    final search = ref.read(searchProvider);
    final router = ref.read(routerProvider);
    if (search.destination == null) {
      router.go('/destination');
    } else if (await ref.read(searchProvider.notifier).findRides()) {
      router.go('/results');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: Brand.name,
      debugShowCheckedModeBanner: false,
      theme: buildGoGoTheme(Brightness.light),
      darkTheme: buildGoGoTheme(Brightness.dark),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
