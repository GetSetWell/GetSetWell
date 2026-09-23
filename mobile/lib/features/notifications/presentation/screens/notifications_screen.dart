import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: GSWColors.backgroundPrimary,
      ),
      child: Scaffold(
        backgroundColor: GSWColors.backgroundPrimary,
        body: SafeArea(
          child: ScrollConfiguration(
            behavior: const _NoScrollEffectBehavior(),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: GSWColors.borderSecondary),
                            color: Colors.black.withValues(alpha: 0.4),
                          ),
                          child: IconButton(
                            onPressed: () => context.pop(),
                            icon: SvgPicture.asset(
                              GSWIcons.arrowheadLeft,
                              width: 30,
                              height: 30,
                              colorFilter: const ColorFilter.mode(
                                GSWColors.iconAccent,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'NOTIFICATIONS',
                    style: GSWTextStyles.displaySmall.copyWith(color: GSWColors.textPrimary),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'TODAY',
                    style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                  ),

                  const SizedBox(height: 24),

                  _NotificationCard(
                    title: 'We picked your trainer',
                    description: 'Arash looks like the right fit. Tap to see why.',
                    time: '1h ago',
                    highlighted: true,
                    onTap: () {
                      // We will connect this to the matched trainer
                      // screen once that route is implemented.
                    },
                  ),

                  const SizedBox(height: 26),

                  Text(
                    'EARLIER',
                    style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                  ),

                  const SizedBox(height: 22),

                  _NotificationCard(
                    title: 'Your session is confirmed',
                    description: 'Saturday 12 September, 07:00 with Arash Vahedi',
                    time: '4d ago',
                    onTap: () {
                      // Later: open session details.
                    },
                  ),

                  const SizedBox(height: 24),

                  _NotificationCard(
                    title: 'Confirm whether your session took place',
                    description: 'It takes one tap and it is what pays your trainer.',
                    time: '4d ago',
                    onTap: () {
                      // Later: open session confirmation.
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Notification card
// -----------------------------------------------------------------------------

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.title,
    required this.description,
    required this.time,
    required this.onTap,
    this.highlighted = false,
  });

  final String title;
  final String description;
  final String time;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(12),
            border: highlighted ? Border.all(color: GSWColors.primary, width: 1) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GSWTextStyles.bodyMedium.copyWith(
                        color: highlighted ? GSWColors.primary : GSWColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      description,
                      style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  time,
                  textAlign: TextAlign.right,
                  style: GSWTextStyles.bodyExtraSmall.copyWith(color: GSWColors.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Scroll behavior
// -----------------------------------------------------------------------------

class _NoScrollEffectBehavior extends ScrollBehavior {
  const _NoScrollEffectBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
