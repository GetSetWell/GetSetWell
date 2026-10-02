import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/gsw_routes.dart';
import '../../../core/theme/gsw_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _moveLogo = false;
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  Future<void> _startAnimation() async {
    // Wait until the first Flutter frame is rendered.
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() => _moveLogo = true);

    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;
    setState(() => _showTitle = true);

    await Future.delayed(const Duration(milliseconds: 150));

    // Hold the completed animation briefly.
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    context.go(GSWRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSlide(
              offset: _moveLogo ? const Offset(0, -0.25) : Offset.zero,
              duration: const Duration(seconds: 1),
              curve: Curves.easeOutCubic,
              child: Image.asset(
                'assets/logos/splash_logo_flutter.png',
                width: 100,
              ),
            ),

            AnimatedOpacity(
              opacity: _showTitle ? 1 : 0,
              duration: const Duration(seconds: 1),
              curve: Curves.easeOut,
              child: AnimatedSlide(
                offset: _showTitle ? Offset.zero : const Offset(0, 0),
                duration: const Duration(seconds: 1),
                curve: Curves.easeOut,
                child: Text('GetSetWell', style: textTheme.titleLarge),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
