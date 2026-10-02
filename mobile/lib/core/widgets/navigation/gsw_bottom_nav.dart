import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';

enum GSWBottomNavItem { home, trainers, sessions, profile }

class GSWBottomNav extends StatelessWidget {
  const GSWBottomNav({super.key, required this.currentItem});

  final GSWBottomNavItem currentItem;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: GSWColors.surfacePrimary,
        border: Border(
          top: BorderSide(color: GSWColors.borderSecondary, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  label: 'Home',
                  iconPath: GSWIcons.home,
                  isSelected: currentItem == GSWBottomNavItem.home,
                  onTap: () {
                    if (currentItem != GSWBottomNavItem.home) {
                      context.go(GSWRoutes.home);
                    }
                  },
                ),
              ),

              Expanded(
                child: _NavItem(
                  label: 'Trainers',
                  iconPath: GSWIcons.search,
                  isSelected: currentItem == GSWBottomNavItem.trainers,
                  onTap: () {
                    if (currentItem != GSWBottomNavItem.trainers) {
                      context.go(GSWRoutes.browseTrainers);
                    }
                  },
                ),
              ),

              Expanded(
                child: _NavItem(
                  label: 'Sessions',
                  iconPath: GSWIcons.calendar,
                  isSelected: currentItem == GSWBottomNavItem.sessions,
                  onTap: () {
                    if (currentItem != GSWBottomNavItem.sessions) {
                      context.go(GSWRoutes.sessions);
                    }
                  },
                ),
              ),

              Expanded(
                child: _NavItem(
                  label: 'Profile',
                  iconPath: GSWIcons.profile,
                  isSelected: currentItem == GSWBottomNavItem.profile,
                  onTap: () {
                    if (currentItem != GSWBottomNavItem.profile) {
                      context.go(GSWRoutes.userProfile);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
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
    final color = isSelected ? GSWColors.primary : GSWColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconPath,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),

            const SizedBox(height: 6),

            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
