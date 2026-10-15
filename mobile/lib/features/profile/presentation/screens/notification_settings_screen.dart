import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/services/customer_identity_service.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 12.3 Notifications (Figma 819:3571).
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _trainerMatches = true;
  bool _bookingUpdates = true;
  bool _sessionReminders = true;
  bool _newTrainers = false;
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();

    _loadPreferences();
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackButton(context),

                const SizedBox(height: 24),

                Text(
                  'Notification settings',
                  style: GSWTextStyles.titleLarge.copyWith(
                    height: 30 / 24,
                    color: GSWColors.textPrimary,
                  ),
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 48),

                  const Center(child: CircularProgressIndicator(color: GSWColors.primary)),
                ] else ...[
                  const SizedBox(height: 24),

                  _buildPushCard(),

                  const SizedBox(height: 24),

                  _buildWhatsAppCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _savePreference(String column, bool value) async {
    final client = Supabase.instance.client;

    try {
      final customerId = await CustomerIdentityService(client: client).getCustomerId();

      await client.from('notification_preferences').upsert({
        'user_id': customerId,
        column: value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');

      return true;
    } catch (error) {
      debugPrint('Notification preference save failed: $error');

      return false;
    }
  }

  Widget _buildBackButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(),
        borderRadius: BorderRadius.circular(GSWRadius.full),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GSWColors.borderSecondary),
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            GSWIcons.arrowheadLeft,
            width: 30,
            height: 30,
            colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  Future<void> _loadPreferences() async {
    final client = Supabase.instance.client;

    try {
      final customerId = await CustomerIdentityService(client: client).getCustomerId();

      final preferences = await client
          .from('notification_preferences')
          .select('trainer_matches, booking_updates, session_reminders, new_trainers')
          .eq('user_id', customerId)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _trainerMatches = preferences?['trainer_matches'] as bool? ?? true;

        _bookingUpdates = preferences?['booking_updates'] as bool? ?? true;

        _sessionReminders = preferences?['session_reminders'] as bool? ?? true;

        _newTrainers = preferences?['new_trainers'] as bool? ?? false;

        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Notification preferences load failed: $error');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildPushCard() {
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
            'Push',
            style: GSWTextStyles.titleExtraSmall.copyWith(height: 1, color: GSWColors.textPrimary),
          ),

          const SizedBox(height: 12),

          _buildToggleRow(
            label: 'Trainer matches',
            value: _trainerMatches,
            onChanged: (value) async {
              final previousValue = _trainerMatches;

              setState(() {
                _trainerMatches = value;
              });

              final saved = await _savePreference('trainer_matches', value);

              if (!saved && mounted) {
                setState(() {
                  _trainerMatches = previousValue;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not update notification settings.')),
                );
              }
            },
          ),

          const SizedBox(height: 12),

          _buildToggleRow(
            label: 'Booking updates',
            value: _bookingUpdates,
            onChanged: (value) async {
              final previousValue = _bookingUpdates;

              setState(() {
                _bookingUpdates = value;
              });

              final saved = await _savePreference('booking_updates', value);

              if (!saved && mounted) {
                setState(() {
                  _bookingUpdates = previousValue;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not update notification settings.')),
                );
              }
            },
          ),

          const SizedBox(height: 12),

          _buildToggleRow(
            label: 'Session reminders',
            value: _sessionReminders,
            onChanged: (value) async {
              final previousValue = _sessionReminders;

              setState(() {
                _sessionReminders = value;
              });

              final saved = await _savePreference('session_reminders', value);

              if (!saved && mounted) {
                setState(() {
                  _sessionReminders = previousValue;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not update notification settings.')),
                );
              }
            },
          ),

          const SizedBox(height: 12),

          _buildToggleRow(
            label: 'New trainers in Dubai',
            value: _newTrainers,
            onChanged: (value) async {
              final previousValue = _newTrainers;

              setState(() {
                _newTrainers = value;
              });

              final saved = await _savePreference('new_trainers', value);

              if (!saved && mounted) {
                setState(() {
                  _newTrainers = previousValue;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not update notification settings.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GSWTextStyles.bodyMedium.copyWith(
                height: 20 / 14,
                color: GSWColors.textPrimary,
              ),
            ),
          ),

          const SizedBox(width: 16),

          _NotificationToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildWhatsAppCard() {
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
            'WhatsApp',
            style: GSWTextStyles.labelLarge.copyWith(height: 20 / 16, color: GSWColors.textPrimary),
          ),

          const SizedBox(height: 12),

          Text(
            'Booking confirmations and session reminders are always sent '
            'on WhatsApp. We use it to confirm your sessions, so it cannot '
            'be switched off.',
            style: GSWTextStyles.bodyMedium.copyWith(
              fontSize: 13,
              height: 18 / 13,
              color: GSWColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

}

/// 44x26 switch from Figma 819:3571. The shared GSWToggle is 40x24, so this
/// screen keeps its own at the design size (same colours as GSWToggle).
class _NotificationToggle extends StatelessWidget {
  const _NotificationToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 26,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? GSWColors.primary : GSWColors.surfaceElevated,
            borderRadius: BorderRadius.circular(GSWRadius.full),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? GSWColors.surfacePrimary : GSWColors.neutral400,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
