import 'package:go_router/go_router.dart';

import '../../features/booking/presentation/screens/booking_request_screen.dart';
import '../../features/booking/presentation/screens/help_me_choose_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/trainers/domain/models/trainer.dart';
import '../../features/trainers/presentation/screens/browse_trainers_screen.dart';
import '../../features/trainers/presentation/screens/trainer_profile_screen.dart';
import 'gsw_routes.dart';

final GoRouter gswRouter = GoRouter(
  routes: [
    GoRoute(path: GSWRoutes.splash, builder: (context, state) => const SplashScreen()),

    GoRoute(path: GSWRoutes.onboarding, builder: (context, state) => const OnboardingScreen()),

    GoRoute(path: GSWRoutes.trainer, builder: (context, state) => const BrowseTrainersScreen()),

    GoRoute(
      path: GSWRoutes.trainerProfile,
      builder: (context, state) {
        final trainer = state.extra as Trainer;

        return TrainerProfileScreen(trainer: trainer);
      },
    ),

    GoRoute(
      path: GSWRoutes.bookingRequest,
      builder: (context, state) {
        final trainer = state.extra as Trainer;

        return BookingRequestScreen(trainer: trainer);
      },
    ),

    GoRoute(
      path: GSWRoutes.helpMeChoose,
      builder: (context, state) {
        return const HelpMeChooseScreen();
      },
    ),
  ],
);
