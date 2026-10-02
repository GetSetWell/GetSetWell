import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_toggle.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackButton(context),

                const SizedBox(height: 40),

                Text(
                  'Notification settings',
                  style: GSWTextStyles.titleExtraLarge.copyWith(color: GSWColors.textPrimary),
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 48),

                  const Center(child: CircularProgressIndicator(color: GSWColors.primary)),
                ] else ...[
                  const SizedBox(height: 28),

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
    final user = client.auth.currentUser;

    if (user == null) {
      return false;
    }

    try {
      await client.from('notification_preferences').upsert({
        'user_id': user.id,
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
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GSWColors.borderSecondary),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.chevron_left, color: GSWColors.primary, size: 30),
        ),
      ),
    );
  }

  Future<void> _loadPreferences() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      return;
    }

    try {
      final preferences = await client
          .from('notification_preferences')
          .select('trainer_matches, booking_updates, session_reminders, new_trainers')
          .eq('user_id', user.id)
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Push', style: GSWTextStyles.titleMedium.copyWith(color: GSWColors.textPrimary)),

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

          _divider(),

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

          _divider(),

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

          _divider(),

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
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary),
            ),
          ),

          const SizedBox(width: 16),

          GSWToggle(value: value, onChanged: onChanged),
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WhatsApp', style: GSWTextStyles.titleMedium.copyWith(color: GSWColors.textPrimary)),

          const SizedBox(height: 12),

          Text(
            'Booking confirmations and session reminders are always sent '
            'on WhatsApp. We use it to confirm your sessions, so it cannot '
            'be switched off.',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, color: GSWColors.neutral700);
  }
}
