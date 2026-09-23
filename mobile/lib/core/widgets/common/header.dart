import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_sizes.dart';
import 'package:mobile/core/theme/gsw_spacing.dart';
import 'package:mobile/core/widgets/common/gsw_logo.dart';

class Header extends StatelessWidget {
  const Header({super.key, this.showNotifications = true});
  final bool showNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 30, child: const GSWLogo()),
            const SizedBox(width: GSWSpacing.xxs),
            Image.asset('assets/logos/wordmark.png', width: 100),
          ],
        ),

        // Notifications
        if (showNotifications)
          IconButton(
            onPressed: () {
              context.push(GSWRoutes.notifications);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: 'Notifications',
            icon: SvgPicture.asset(
              GSWIcons.bell,
              width: GSWSizes.sm,
              height: GSWSizes.sm,
              colorFilter: const ColorFilter.mode(GSWColors.iconPrimary, BlendMode.srcIn),
            ),
          ),

        // Language selector
        // Row(
        //   mainAxisSize: MainAxisSize.min,
        //   children: [
        //     Text('EN', style: Theme.of(context).textTheme.bodyMedium),
        //     const SizedBox(width: 16),
        //     Text('|', style: Theme.of(context).textTheme.bodyMedium),
        //     const SizedBox(width: 16),
        //     Text('العربية', style: Theme.of(context).textTheme.bodyMedium),
        //   ],
        // ),
      ],
    );
  }
}
