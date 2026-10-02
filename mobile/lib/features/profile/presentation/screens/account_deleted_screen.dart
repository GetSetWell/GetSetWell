import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/profile/data/services/account_deletion_service.dart';
import 'package:mobile/features/sessions/data/services/sessions_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/routing/gsw_routes.dart';
import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';
import '../../../../core/widgets/buttons/gsw_button.dart';
import '../../../../core/widgets/inputs/gsw_text_field.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key, required this.onKeepAccount});

  final VoidCallback onKeepAccount;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final TextEditingController _deleteController = TextEditingController();
  late final SessionsService _sessionsService;
  late Future<List<Map<String, dynamic>>> _upcomingSessionsFuture;

  bool _isDeleting = false;

  bool get _canDelete => _deleteController.text.trim().toUpperCase() == 'DELETE';

  @override
  void initState() {
    super.initState();

    _sessionsService = SessionsService(Supabase.instance.client);

    _upcomingSessionsFuture = _sessionsService.getUpcomingSessions();
  }

  @override
  void dispose() {
    _deleteController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    if (!_canDelete || _isDeleting) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await AccountDeletionService().deleteAccount();

      if (!mounted) return;

      context.go(GSWRoutes.onboarding);
    } on AccountDeletionException catch (error) {
      debugPrint('Delete account failed: ${error.message}');
    } catch (error) {
      debugPrint('Delete account failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _upcomingSessionsFuture,
          builder: (context, snapshot) {
            final sessions = snapshot.data ?? [];
            final hasUpcomingSession = sessions.isNotEmpty;

            return Column(
              children: [
                Expanded(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBackButton(),

                          const SizedBox(height: 24),

                          Text(
                            'Delete your account',
                            style: GSWTextStyles.titleExtraLarge.copyWith(
                              color: GSWColors.textPrimary,
                            ),
                          ),

                          const SizedBox(height: 24),

                          if (hasUpcomingSession)
                            _buildUpcomingSessionState(sessions.first)
                          else
                            _buildNormalDeleteState(),
                        ],
                      ),
                    ),
                  ),
                ),

                _buildBottomActions(hasUpcomingSession: hasUpcomingSession),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildUpcomingSessionState(Map<String, dynamic> session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You can delete your account once you have no upcoming sessions. We then delete your account and personal details within 30 days.',
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
        ),

        const SizedBox(height: 24),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GSWColors.error, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have 1 upcoming session',
                style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.textPrimary),
              ),

              const SizedBox(height: 12),

              Text(
                "Cancel it before you delete your account. It's more than 24 hours away, so you'd get the AED 250 session fee back.",
                style: GSWTextStyles.bodyLarge.copyWith(
                  color: GSWColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'Want a copy of your data first? Email info@getsetwell.com.',
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildNormalDeleteState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "This can't be undone. To use GetSetWell again, you'd sign up as a new customer.",
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
        ),

        const SizedBox(height: 24),

        _buildWhatHappensCard(),

        const SizedBox(height: 24),

        Text(
          'Want a copy of your data first? Email info@getsetwell.com.',
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
        ),

        const SizedBox(height: 24),

        GSWTextField(
          controller: _deleteController,
          label: 'Type DELETE to confirm',
          hintText: 'DELETE',
          helpingText: "The button turns on once you've typed DELETE.",
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (context.canPop()) {
            context.pop();
          }
        },
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GSWColors.borderSecondary),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.chevron_left_rounded, color: GSWColors.primary, size: 30),
        ),
      ),
    );
  }

  Widget _buildWhatHappensCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What happens',
            style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.textPrimary),
          ),

          const SizedBox(height: 12),

          _buildBullet('Your account, name and mobile number are deleted within 30 days.'),

          const SizedBox(height: 12),

          _buildBullet(
            'Booking, payment and refund records are kept for 7 years, as UAE tax law requires.',
          ),

          const SizedBox(height: 12),

          _buildBullet("You're logged out straight away on this phone."),
        ],
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 1),
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: GSWColors.textSecondary, shape: BoxShape.circle),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            text,
            style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textSecondary, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions({required bool hasUpcomingSession}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: hasUpcomingSession
          ? GSWButton(
              label: 'Go to my booking',
              onPressed: () {
                context.go(GSWRoutes.sessions);
              },
              variant: GSWButtonVariant.primary,
              size: GSWButtonSize.large,
            )
          : Column(
              children: [
                GSWButton(
                  label: 'Delete my account',
                  onPressed: _canDelete && !_isDeleting ? _handleDelete : null,
                  variant: _canDelete && !_isDeleting
                      ? GSWButtonVariant.destructive
                      : GSWButtonVariant.disabled,
                  size: GSWButtonSize.large,
                  isLoading: _isDeleting,
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: widget.onKeepAccount,
                  style: TextButton.styleFrom(foregroundColor: GSWColors.textSecondary),
                  child: Text(
                    'Keep my account',
                    style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textSecondary),
                  ),
                ),
              ],
            ),
    );
  }
}
