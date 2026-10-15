import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/services/customer_identity_service.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/common/gsw_logo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// App header from Figma 7.x / 8.1 (node 818:3053).
///
/// Logo mark 30px, 4px gap, "GetSetWell" in Outfit SemiBold 18/22.
/// Right side: a 36px bell button (1px Border/Disabled) that opens the
/// notifications inbox, with a lime dot while anything is unread.
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
            const SizedBox(width: 30, height: 30, child: GSWLogo()),
            const SizedBox(width: 4),
            Text(
              'GetSetWell',
              style: GSWTextStyles.titleExtraSmall.copyWith(
                color: GSWColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 22 / 18,
              ),
            ),
          ],
        ),
        if (showNotifications) const _NotificationsButton(),
      ],
    );
  }
}

class _NotificationsButton extends StatefulWidget {
  const _NotificationsButton();

  @override
  State<_NotificationsButton> createState() => _NotificationsButtonState();
}

class _NotificationsButtonState extends State<_NotificationsButton> {
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    _checkUnread();
  }

  /// Best effort: a failed check just hides the dot.
  Future<void> _checkUnread() async {
    try {
      final client = Supabase.instance.client;
      final customerId = await CustomerIdentityService(client: client).getCustomerId();
      final rows = await client
          .from('notifications')
          .select('id')
          .eq('user_id', customerId)
          .eq('is_read', false)
          .limit(1);
      if (!mounted) return;
      setState(() => _hasUnread = rows.isNotEmpty);
    } catch (error) {
      debugPrint('Unread notifications check failed: $error');
    }
  }

  Future<void> _open() async {
    await context.push(GSWRoutes.notifications);
    if (!mounted) return;
    await _checkUnread();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _hasUnread ? 'Notifications, new' : 'Notifications',
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(side: BorderSide(color: GSWColors.borderDisabled)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _open,
                child: Center(
                  child: SvgPicture.asset(
                    GSWIcons.bell,
                    width: 17,
                    height: 19,
                    colorFilter: const ColorFilter.mode(GSWColors.textPrimary, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
            if (_hasUnread)
              Positioned(
                top: 6,
                right: 7,
                child: IgnorePointer(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: GSWColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: GSWColors.backgroundPrimary, width: 1.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
