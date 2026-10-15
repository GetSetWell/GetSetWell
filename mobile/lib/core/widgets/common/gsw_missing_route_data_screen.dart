import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routing/gsw_routes.dart';
import '../../theme/gsw_colors.dart';
import '../../theme/gsw_typography.dart';
import '../buttons/gsw_button.dart';

/// Shown when a screen is opened without the data it needs, for example after
/// Android restores the app or from an old notification. Replaces the crashes
/// caused by hard casts of `state.extra`.
class GSWMissingRouteDataScreen extends StatelessWidget {
  const GSWMissingRouteDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                'This page needs refreshing',
                style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'We lost track of what you were looking at. Head back home and open it again.',
                style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
              ),
              const Spacer(),
              GSWButton(
                label: 'Back to home',
                onPressed: () => context.go(GSWRoutes.home),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
