import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';

enum GSWBottomNavItem { home, trainers, sessions, profile }

/// Tab bar from Figma (735:164): Home / Trainers / Sessions / Profile.
///
/// Surface/Primary fill with a 1px Border/Disabled top line, 10px top
/// padding, 16px sides, each tab 8px vertical padding with a 22px icon,
/// 6px gap and a Medium 11/12 label. Active tab uses Text/Accent.
/// The 24px bottom padding in Figma is the home-indicator area, so it comes
/// from the device safe area (with a minimum of 8px).
class GSWBottomNav extends StatelessWidget {
  const GSWBottomNav({super.key, required this.currentItem});

  final GSWBottomNavItem currentItem;

  void _go(BuildContext context, GSWBottomNavItem item, String route) {
    if (currentItem == item) return;

    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: GSWColors.surfacePrimary,
        border: Border(top: BorderSide(color: GSWColors.borderDisabled, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset > 8 ? bottomInset : 8),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              label: 'Home',
              iconPath: GSWIcons.home,
              isSelected: currentItem == GSWBottomNavItem.home,
              onTap: () => _go(context, GSWBottomNavItem.home, GSWRoutes.home),
            ),
          ),
          Expanded(
            child: _NavItem(
              label: 'Trainers',
              iconPath: GSWIcons.search,
              isSelected: currentItem == GSWBottomNavItem.trainers,
              onTap: () => _go(context, GSWBottomNavItem.trainers, GSWRoutes.browseTrainers),
            ),
          ),
          Expanded(
            child: _NavItem(
              label: 'Sessions',
              iconPath: GSWIcons.calendar,
              isSelected: currentItem == GSWBottomNavItem.sessions,
              onTap: () => _go(context, GSWBottomNavItem.sessions, GSWRoutes.sessions),
            ),
          ),
          Expanded(
            child: _NavItem(
              label: 'Profile',
              iconPath: GSWIcons.profile,
              isSelected: currentItem == GSWBottomNavItem.profile,
              onTap: () => _go(context, GSWBottomNavItem.profile, GSWRoutes.userProfile),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.iconPath,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String iconPath;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? GSWColors.textAccent : GSWColors.textSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                iconPath,
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),

              const SizedBox(height: 6),

              Text(
                label,
                maxLines: 1,
                style: GSWTextStyles.labelExtraSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                  height: 12 / 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
