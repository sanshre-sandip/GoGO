import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/comparison/results_screen.dart';
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
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/destination', builder: (_, __) => const DestinationScreen()),
      GoRoute(path: '/results', builder: (_, __) => const ResultsScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
});
