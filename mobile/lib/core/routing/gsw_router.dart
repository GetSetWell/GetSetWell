import 'package:go_router/go_router.dart';

import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/trainers/presentation/screens/browse_trainers_screen.dart';
import 'gsw_routes.dart';

final GoRouter gswRouter = GoRouter(
  routes: [
    GoRoute(path: GSWRoutes.splash, builder: (context, state) => const SplashScreen()),
    GoRoute(path: GSWRoutes.onboarding, builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/trainers', builder: (context, state) => const BrowseTrainersScreen()),
  ],
);
