import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/services/push_notification_service.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/core/widgets/navigation/gsw_bottom_nav.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final user = client.auth.currentUser;

    if (user == null) {
      throw StateError('AUTH_REQUIRED');
    }

    final profile = await client
        .from('customer_profiles')
        .select('full_name, phone, city, email, profile_photo_path')
        .eq('id', user.id)
        .maybeSingle();

    final fullName = profile?['full_name']?.toString().trim() ?? '';

    final city = profile?['city']?.toString().trim() ?? '';

    final authPhone = user.phone?.trim() ?? '';

    final profilePhone = profile?['phone']?.toString().trim() ?? '';

    final phone = authPhone.isNotEmpty ? authPhone : profilePhone;

    final email = profile?['email']?.toString().trim() ?? user.email?.trim() ?? '';

    final photoPath = profile?['profile_photo_path']?.toString().trim();

    String? profilePhotoUrl;

    if (photoPath != null && photoPath.isNotEmpty) {
      profilePhotoUrl = await client.storage
          .from('profile-photos')
          .createSignedUrl(photoPath, 60 * 60);
    }

    final sessionRows = await client.from('sessions').select('id').eq('user_id', user.id);

    final sessionCount = sessionRows.length;

    final memberSince = DateTime.tryParse(user.createdAt) ?? DateTime.now();

    return _UserProfileData(
      fullName: fullName,
      phone: phone,
      city: city,
      email: email,
      sessionCount: sessionCount,
      memberSince: memberSince,
      profilePhotoUrl: profilePhotoUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROFILE',
                  style: Theme.of(
                    context,
                  ).textTheme.displaySmall?.copyWith(color: GSWColors.textPrimary),
                ),

                const SizedBox(height: 24),

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

                    if (snapshot.hasError) {
                      debugPrint('Profile load failed: ${snapshot.error}');

                      return Text(
                        'We could not load your profile.',
                        style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                      );
                    }

                    final profile = snapshot.data!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileCard(context, profile),

                        const SizedBox(height: 24),

                        _buildSectionTitle(context, 'Personal details'),

                        const SizedBox(height: 12),

                        _buildSettingsCard(
                          children: [
                            _buildRow(
                              context,
                              icon: Icons.person_outline,
                              label: 'Name',
                              value: profile.fullName,
                            ),

                            _divider(),

                            _buildRow(
                              context,
                              icon: Icons.phone_outlined,
                              label: 'Phone',
                              value: profile.phone,
                            ),

                            _divider(),

                            _buildRow(
                              context,
                              icon: Icons.location_on_outlined,
                              label: 'City',
                              value: profile.city,
                            ),

                            _divider(),

                            _buildRow(
                              context,
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: profile.email,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                _buildSectionTitle(context, 'Account settings'),

                const SizedBox(height: 12),

                _buildSettingsCard(
                  children: [
                    _buildActionRow(
                      context,
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      onTap: () {
                        context.push(GSWRoutes.notificationSettings);
                      },
                    ),

                    _divider(),

                    _buildActionRow(
                      context,
                      icon: Icons.language_outlined,
                      label: 'Language',
                      onTap: () {
                        context.push(GSWRoutes.languageSettings);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                _buildSectionTitle(context, 'Support & legal'),

                const SizedBox(height: 12),

                _buildSettingsCard(
                  children: [
                    _buildActionRow(
                      context,
                      icon: Icons.help_outline,
                      label: 'Help & support',
                      onTap: () {
                        context.push(GSWRoutes.helpAndSupport);
                      },
                    ),

                    _divider(),

                    _buildActionRow(
                      context,
                      icon: Icons.description_outlined,
                      label: 'Legal',
                      onTap: () {
                        context.push(GSWRoutes.legal);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                _buildSettingsCard(
                  children: [
                    _buildActionRow(
                      context,
                      icon: Icons.logout,
                      label: 'Log out',
                      isDestructive: true,
                      color: GSWColors.textPrimary,
                      onTap: _showLogoutSheet,
                    ),

                    _buildActionRow(
                      context,
                      icon: Icons.delete_outline,
                      label: 'Delete account',
                      isDestructive: true,
                      color: GSWColors.error,
                      onTap: () async {
                        context.push(GSWRoutes.deleteAccount);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Center(
                  child: Text(
                    'GetSetWell is operated by Get Set Fit LLC, licence 2541939, Sharjah Media City. support@getsetwell.com · WhatsApp +971 50 525 1393',
                    style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textTertiary),
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

  void _showLogoutSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: GSWColors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: GSWColors.neutral700,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Log out?',
                    style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "You'll need a code on WhatsApp to log back in. "
                    'Your sessions and requests stay as they are.',
                    style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                  ),

                  const SizedBox(height: 20),

                  GSWButton(
                    size: GSWButtonSize.large,
                    variant: GSWButtonVariant.primary,
                    label: 'Log out',
                    onPressed: () async {
                      try {
                        await PushNotificationService().deleteCurrentDeviceToken();

                        await Supabase.instance.client.auth.signOut();

                        if (!mounted) return;

                        if (!sheetContext.mounted) {
                          return;
                        }

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
                  ),

                  const SizedBox(height: 12),

                  GSWButton(
                    size: GSWButtonSize.large,
                    variant: GSWButtonVariant.tertiary,
                    label: 'Stay logged in',
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileCard(BuildContext context, _UserProfileData profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
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
                          errorBuilder: (context, error, stackTrace) {
                            return _buildProfileInitialAvatar(profile.fullName);
                          },
                        )
                      : _buildProfileInitialAvatar(profile.fullName),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: GSWTextStyles.titleMedium.copyWith(color: GSWColors.textPrimary),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      _formatPhone(profile.phone),
                      style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            '${profile.sessionCount} ${profile.sessionCount == 1 ? 'session' : 'sessions'}'
            ' · member since ${_memberSinceLabel(profile.memberSince)}',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),

          const SizedBox(height: 10),

          GSWButton(
            size: GSWButtonSize.medium,
            variant: GSWButtonVariant.secondary,
            label: 'Edit your details',
            onPressed: () async {
              await context.push(GSWRoutes.editProfile);

              if (!mounted) return;

              setState(() {
                _profileFuture = _loadProfile();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInitialAvatar(String fullName) {
    return Container(
      color: GSWColors.backgroundPrimary,
      alignment: Alignment.center,
      child: Text(
        _initials(fullName),
        style: GSWTextStyles.titleMedium.copyWith(
          color: GSWColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _memberSinceLabel(DateTime date) {
    const months = [
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

    return '${months[date.month - 1]} ${date.year}';
  }

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

    if (parts.isEmpty) {
      return '';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildSectionTitle(BuildContext context, String label) {
    return Text(label, style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.textPrimary));
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: GSWColors.textSecondary),

          const SizedBox(width: 14),

          Expanded(
            child: Text(
              label,
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary),
            ),
          ),

          const SizedBox(width: 12),

          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(
    BuildContext context, {
    required IconData icon,
    Color? color,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isDestructive ? color : GSWColors.textSecondary),

            const SizedBox(width: 14),

            Expanded(
              child: Text(
                label,
                style: GSWTextStyles.bodyMedium.copyWith(
                  color: isDestructive ? color : GSWColors.textPrimary,
                ),
              ),
            ),

            if (!isDestructive) const Icon(Icons.chevron_right, color: GSWColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: GSWColors.neutral700),
    );
  }
}
