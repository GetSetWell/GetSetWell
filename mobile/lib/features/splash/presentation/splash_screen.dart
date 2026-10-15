import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/gsw_routes.dart';
import '../../../core/theme/gsw_colors.dart';
import '../../../core/theme/gsw_typography.dart';
import '../../auth/domain/model/auth_flow_intent.dart';
import '../../auth/presentation/navigation/session_gate.dart';

/// 1.1 Splash. Two seconds at most and never blocked on the network: if the
/// session check is slow or fails, the app goes to Welcome, which keeps
/// resolving in the background (Figma note 809:2476).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration _minimumDisplay = Duration(milliseconds: 800);

  static const Duration _sessionBudget = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    final results = await Future.wait<Object?>([
      Future<void>.delayed(_minimumDisplay),
      resolveSessionDestination(timeout: _sessionBudget),
    ]);

    if (!mounted) return;

    final destination = results[1] as SessionDestination;

    switch (destination) {
      case SessionDestination.home:
        context.go(GSWRoutes.home);

      case SessionDestination.details:
        context.go(GSWRoutes.userDetails, extra: const AuthFlowIntent.getStarted());

      case SessionDestination.welcome:
      case SessionDestination.unresolved:
        context.go(GSWRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: Stack(
        children: [
          // Soft lime glows centred on the top-right and bottom-left corners
          // (Figma 809:2473 / 809:2474: 403px blurred ellipses, centres at
          // (width + 12.5, -0.5) and (0.5, height - 0.5)).
          const Positioned(top: -298, right: -310, child: _CornerGlow()),

          const Positioned(bottom: -297, left: -297, child: _CornerGlow()),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logos/logo.png', width: 56, height: 68.6),

                const SizedBox(height: 16),

                Text(
                  'GetSetWell',
                  textAlign: TextAlign.center,
                  style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerGlow extends StatelessWidget {
  const _CornerGlow();

  /// 403px ellipse plus its blur spread (23.82% each side).
  static const double _size = 595;

  /// Peak strength of the lime glow, measured from the Figma render.
  static const double _peak = 0.0275;

  @override
  Widget build(BuildContext context) {
    // Flat core, then a soft fall-off that is gone well before the box edge,
    // matching the blurred ellipse profile.
    return IgnorePointer(
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              GSWColors.primary.withValues(alpha: _peak),
              GSWColors.primary.withValues(alpha: _peak),
              GSWColors.primary.withValues(alpha: _peak * 0.67),
              GSWColors.primary.withValues(alpha: _peak * 0.5),
              GSWColors.primary.withValues(alpha: _peak * 0.17),
              GSWColors.primary.withValues(alpha: 0),
            ],
            stops: const [0, 0.4, 0.555, 0.655, 0.77, 0.86],
          ),
        ),
      ),
    );
  }
}
