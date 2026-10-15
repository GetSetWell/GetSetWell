import 'package:flutter/material.dart';

import '../../../core/theme/gsw_colors.dart';
import '../../../core/theme/gsw_theme.dart';
import '../../../core/theme/gsw_typography.dart';
import '../../../core/widgets/buttons/gsw_button.dart';

/// Shown instead of a blank screen when Firebase or Supabase cannot start.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: GSWTheme.darkTheme,
      home: _StartupErrorScreen(onRetry: onRetry),
    );
  }
}

class _StartupErrorScreen extends StatefulWidget {
  const _StartupErrorScreen({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  State<_StartupErrorScreen> createState() => _StartupErrorScreenState();
}

class _StartupErrorScreenState extends State<_StartupErrorScreen> {
  bool _isRetrying = false;

  Future<void> _retry() async {
    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
    });

    try {
      await widget.onRetry();
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/logos/logo.png', width: 56, height: 68.6),

                      const SizedBox(height: 24),

                      Text(
                        'GetSetWell could not start',
                        textAlign: TextAlign.center,
                        style: GSWTextStyles.titleLarge.copyWith(
                          color: GSWColors.textPrimary,
                          height: 30 / 24,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Check your internet connection and try again. '
                        'If it keeps happening, close the app and open it again.',
                        textAlign: TextAlign.center,
                        style: GSWTextStyles.bodyMedium.copyWith(
                          color: GSWColors.textSecondary,
                          height: 20 / 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              GSWButton(
                size: GSWButtonSize.large,
                label: 'Try again',
                isLoading: _isRetrying,
                onPressed: _retry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
