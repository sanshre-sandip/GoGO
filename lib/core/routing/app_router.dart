import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/comparison/results_screen.dart';
import '../../features/debug/debug_screen.dart';
import '../../features/destination/destination_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../app_providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final storage = ref.read(storageProvider);
  return GoRouter(
    initialLocation: storage.onboardingComplete ? '/' : '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/destination', builder: (_, _) => const DestinationScreen()),
      GoRoute(path: '/results', builder: (_, _) => const ResultsScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/debug', builder: (_, _) => const DebugScreen()),
    ],
  );
});
