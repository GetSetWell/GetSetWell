import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/widgets/sheets/gsw_sheet_drag_dismiss.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/services/customer_identity_service.dart';
import 'package:mobile/core/services/push_notification_service.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/core/widgets/navigation/gsw_bottom_nav.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 12.1 Profile (Figma 819:3468).
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileData {
  const _UserProfileData({
    required this.fullName,
    required this.phone,
    required this.city,
    required this.email,
    required this.sessionCount,
    required this.memberSince,
    required this.profilePhotoUrl,
  });

  final String fullName;
  final String phone;
  final String city;
  final String email;
  final int sessionCount;
  final DateTime memberSince;
  final String? profilePhotoUrl;
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<_UserProfileData> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<_UserProfileData> _loadProfile() async {
    final client = Supabase.instance.client;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('AUTH_REQUIRED');
    }

    final customerId = await CustomerIdentityService(client: client).getCustomerId();

    final profile = await client
        .from('customer_profiles')
        .select('full_name, phone, city, email, profile_photo_path')
        .eq('id', customerId)
        .maybeSingle();

    final fullName = profile?['full_name']?.toString().trim() ?? '';
    final city = profile?['city']?.toString().trim() ?? '';
    final authPhone = user.phoneNumber?.trim() ?? '';
    final profilePhone = profile?['phone']?.toString().trim() ?? '';
    final phone = authPhone.isNotEmpty ? authPhone : profilePhone;
    final email = profile?['email']?.toString().trim() ?? '';
    final photoPath = profile?['profile_photo_path']?.toString().trim();

    String? profilePhotoUrl;

    if (photoPath != null && photoPath.isNotEmpty) {
      // A missing or unreadable photo should not break the whole screen.
      try {
        profilePhotoUrl = await client.storage
            .from('profile-photos')
            .createSignedUrl(photoPath, 60 * 60);
      } catch (error) {
        debugPrint('Profile photo URL failed: $error');
      }
    }

    final sessionRows = await client.from('sessions').select('id').eq('user_id', customerId);

    final created = user.metadata.creationTime;
    final memberSince = created != null ? GSWTime.toDubai(created) : GSWTime.nowDubai();

    return _UserProfileData(
      fullName: fullName,
      phone: phone,
      city: city,
      email: email,
      sessionCount: sessionRows.length,
      memberSince: memberSince,
      profilePhotoUrl: profilePhotoUrl,
    );
  }

  void _reload() {
    setState(() {
      _profileFuture = _loadProfile();
    });
  }

  Future<void> _openEditDetails() async {
    await context.push(GSWRoutes.editProfile);
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        bottom: false,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROFILE',
                  style: GSWTextStyles.displaySmall.copyWith(
                    fontSize: 40,
                    height: 44 / 40,
                    color: GSWColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 28),

                FutureBuilder<_UserProfileData>(
                  future: _profileFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: CircularProgressIndicator(color: GSWColors.primary),
                        ),
                      );
                    }

                    if (snapshot.hasError || !snapshot.hasData) {
                      debugPrint('Profile load failed: ${snapshot.error}');
                      return _buildLoadError();
                    }

                    final profile = snapshot.data!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildIdentityCard(profile),

                        const SizedBox(height: 28),

                        _buildSection(
                          title: 'Personal details',
                          children: [
                            _buildDetailRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Name',
                              value: profile.fullName,
                            ),
                            _divider(),
                            _buildDetailRow(
                              icon: Icons.phone_outlined,
                              label: 'Mobile',
                              value: _formatPhone(profile.phone),
                            ),
                            _divider(),
                            _buildDetailRow(
                              icon: Icons.location_on_outlined,
                              label: 'City',
                              value: profile.city.isEmpty ? 'Dubai' : profile.city,
                              valueColor: GSWColors.textTertiary,
                            ),
                            _divider(),
                            _buildDetailRow(
                              icon: Icons.mail_outline_rounded,
                              label: 'Email',
                              value: profile.email.isEmpty ? 'Add email' : profile.email,
                              valueColor: profile.email.isEmpty
                                  ? GSWColors.textAccent
                                  : GSWColors.textSecondary,
                              onTap: _openEditDetails,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 28),

                _buildSection(
                  title: 'Account settings',
                  children: [
                    _buildNavRow(
                      icon: Icons.notifications_none_rounded,
                      label: 'Notifications',
                      onTap: () => context.push(GSWRoutes.notificationSettings),
                    ),
                    _divider(),
                    _buildNavRow(
                      icon: Icons.language_rounded,
                      label: 'Language',
                      trailingValue: 'English',
                      onTap: () => context.push(GSWRoutes.languageSettings),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                _buildSection(
                  title: 'Support & legal',
                  children: [
                    _buildNavRow(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & support',
                      onTap: () => context.push(GSWRoutes.helpAndSupport),
                    ),
                    _divider(),
                    _buildNavRow(
                      icon: Icons.description_outlined,
                      label: 'Terms of service',
                      onTap: () => context.push(GSWRoutes.termsOfService),
                    ),
                    _divider(),
                    _buildNavRow(
                      icon: Icons.lock_outline_rounded,
                      label: 'Privacy policy',
                      onTap: () => context.push(GSWRoutes.privacyPolicy),
                    ),
                    _divider(),
                    _buildNavRow(
                      icon: Icons.receipt_long_outlined,
                      label: 'Refunds and other policies',
                      onTap: () => context.push(GSWRoutes.legal),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                _buildCard(
                  children: [
                    _buildNavRow(
                      icon: Icons.logout_rounded,
                      label: 'Log out',
                      showChevron: false,
                      onTap: _showLogoutSheet,
                    ),
                    _buildNavRow(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete account',
                      color: GSWColors.error,
                      showChevron: false,
                      onTap: () => context.push(GSWRoutes.deleteAccount),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Text(
                  'GetSetWell is operated by Get Set Fit LLC, licence 2541939, Sharjah Media City. '
                  'support@getsetwell.com · WhatsApp +971 50 525 1393',
                  style: GSWTextStyles.bodyExtraSmall.copyWith(
                    height: 16 / 11,
                    color: GSWColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const GSWBottomNav(currentItem: GSWBottomNavItem.profile),
    );
  }

  // ---------------------------------------------------------------------------
  // Log out sheet (12.8, Figma 1077:3707)
  // ---------------------------------------------------------------------------

  void _showLogoutSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: GSWColors.scrim,
      enableDrag: false,
      builder: (_) => GSWSheetDragDismiss(
        child: Builder(builder: (sheetContext) {
        return _LogoutSheet(
          onLogOut: () async {
            try {
              await PushNotificationService().deleteCurrentDeviceToken();
              await FirebaseAuth.instance.signOut();

              if (!mounted || !sheetContext.mounted) return;

              Navigator.of(sheetContext).pop();
              context.go(GSWRoutes.onboarding);
            } catch (error) {
              debugPrint('Logout failed: $error');
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not log out. Please try again.')),
              );
            }
          },
          onStay: () => Navigator.of(sheetContext).pop(),
        );
      }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pieces
  // ---------------------------------------------------------------------------

  Widget _buildLoadError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'We could not load your profile.',
            style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Check your connection and try again.',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
          const SizedBox(height: 12),
          GSWButton(
            label: 'Try again',
            size: GSWButtonSize.medium,
            variant: GSWButtonVariant.secondary,
            onPressed: _reload,
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard(_UserProfileData profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: GSWColors.primary, width: 2),
                ),
                child: ClipOval(
                  child: profile.profilePhotoUrl != null
                      ? Image.network(
                          profile.profilePhotoUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildInitials(profile.fullName),
                        )
                      : _buildInitials(profile.fullName),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GSWTextStyles.titleSmall.copyWith(
                        height: 24 / 20,
                        color: GSWColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatPhone(profile.phone),
                      style: GSWTextStyles.bodyMedium.copyWith(
                        fontSize: 13,
                        height: 18 / 13,
                        color: GSWColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            '${profile.sessionCount} ${profile.sessionCount == 1 ? 'session' : 'sessions'}'
            ' · member since ${_monthYear(profile.memberSince)}',
            style: GSWTextStyles.bodySmall.copyWith(
              height: 16 / 12,
              color: GSWColors.textTertiary,
            ),
          ),

          const SizedBox(height: 10),

          Material(
            color: Colors.transparent,
            shape: const StadiumBorder(side: BorderSide(color: GSWColors.surfaceInteractive)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _openEditDetails,
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Edit your details',
                    textAlign: TextAlign.center,
                    style: GSWTextStyles.labelMedium.copyWith(
                      height: 16 / 14,
                      color: GSWColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitials(String fullName) {
    return Container(
      alignment: Alignment.center,
      child: Text(
        _initials(fullName),
        style: GSWTextStyles.titleSmall.copyWith(height: 24 / 20, color: GSWColors.textPrimary),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GSWTextStyles.titleSmall.copyWith(height: 26 / 20, color: GSWColors.textPrimary),
        ),
        const SizedBox(height: 14),
        _buildCard(children: children),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
      ),
      child: Column(children: children),
    );
  }

  Widget _rowIcon(IconData icon, Color color) => SizedBox(
    width: 22,
    height: 22,
    child: Icon(icon, size: 22, color: color),
  );

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color valueColor = GSWColors.textSecondary,
    VoidCallback? onTap,
  }) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          _rowIcon(icon, GSWColors.iconPrimary),
          const SizedBox(width: 14),
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: GSWTextStyles.bodyLarge.copyWith(height: 22 / 16, color: GSWColors.textPrimary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GSWTextStyles.bodyLarge.copyWith(height: 22 / 16, color: valueColor),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return row;

    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
  }

  Widget _buildNavRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? trailingValue,
    Color color = GSWColors.textPrimary,
    bool showChevron = true,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            _rowIcon(icon, color == GSWColors.textPrimary ? GSWColors.iconPrimary : color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GSWTextStyles.bodyLarge.copyWith(height: 22 / 16, color: color),
              ),
            ),
            if (trailingValue != null) ...[
              const SizedBox(width: 14),
              Text(
                trailingValue,
                style: GSWTextStyles.bodyMedium.copyWith(
                  height: 20 / 14,
                  color: GSWColors.textSecondary,
                ),
              ),
            ],
            if (showChevron) ...[
              const SizedBox(width: 14),
              SvgPicture.asset(
                GSWIcons.arrowheadRight,
                width: 16.667,
                height: 20,
                colorFilter: const ColorFilter.mode(GSWColors.iconSecondary, BlendMode.srcIn),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return const SizedBox(
      height: 1,
      width: double.infinity,
      child: ColoredBox(color: GSWColors.surfaceInteractive),
    );
  }

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  static const List<String> _monthsLong = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// "September 2026". Input is already Dubai time.
  String _monthYear(DateTime dubai) => '${_monthsLong[dubai.month - 1]} ${dubai.year}';

  String _formatPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 12 && digits.startsWith('971')) {
      return '+971 ${digits.substring(3, 5)} '
          '${digits.substring(5, 8)} '
          '${digits.substring(8)}';
    }

    return phone;
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();

    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

/// 12.8 Log out (Figma 1077:3707). Bottom sheet per the shared sheet spec.
class _LogoutSheet extends StatefulWidget {
  const _LogoutSheet({required this.onLogOut, required this.onStay});

  final Future<void> Function() onLogOut;
  final VoidCallback onStay;

  @override
  State<_LogoutSheet> createState() => _LogoutSheetState();
}

class _LogoutSheetState extends State<_LogoutSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: GSWColors.backgroundPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GSWRadius.sheet)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 28 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 28,
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: GSWColors.surfaceInteractive,
                    borderRadius: BorderRadius.circular(GSWRadius.full),
                  ),
                ),
              ),
            ),
            Text(
              'Log out?',
              style: GSWTextStyles.titleLarge.copyWith(height: 1, color: GSWColors.textPrimary),
            ),
            const SizedBox(height: 20),
            Text(
              "You'll need a code by SMS to log back in. "
              'Your sessions and requests stay as they are.',
              style: GSWTextStyles.bodyMedium.copyWith(
                height: 20 / 14,
                color: GSWColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            GSWButton(
              label: 'Log out',
              isLoading: _busy,
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await widget.onLogOut();
                      if (mounted) setState(() => _busy = false);
                    },
            ),
            const SizedBox(height: 20),
            GSWButton(
              label: 'Stay logged in',
              variant: GSWButtonVariant.tertiary,
              onPressed: widget.onStay,
            ),
          ],
        ),
      ),
    );
  }
}
