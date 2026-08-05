import 'package:go_router/go_router.dart';
import 'package:mobile/features/splash/presentation/splash_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [GoRoute(path: '/', builder: (context, state) => const SplashScreen())],
);
