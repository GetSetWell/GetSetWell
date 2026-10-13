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

  void _showDeletionError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _retryUpcomingSessions() {
    if (!mounted) return;
    setState(() {
      _upcomingSessionsFuture = _sessionsService.getUpcomingSessions();
    });
  }

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
      final requiresRecentLogin = error.message.toLowerCase().contains('sign in again');
      _showDeletionError(
        requiresRecentLogin
            ? 'Please sign in again before deleting your account.'
            : 'We could not confirm account deletion. Contact info@getsetwell.com before trying again.',
      );
      _retryUpcomingSessions();
    } catch (error) {
      debugPrint('Delete account failed: $error');
      _showDeletionError(
        'We could not confirm account deletion. Please contact info@getsetwell.com before trying again.',
      );
      _retryUpcomingSessions();
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
            final isCheckingSessions = snapshot.connectionState != ConnectionState.done;
            final sessionCheckFailed = snapshot.hasError;
            final hasUpcomingSession =
                !isCheckingSessions && !sessionCheckFailed && sessions.isNotEmpty;
            final cannotConfirmNoUpcomingSessions = isCheckingSessions || sessionCheckFailed;

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

                          if (isCheckingSessions)
                            Text(
                              'Checking your upcoming sessions…',
                              style: GSWTextStyles.bodyMedium.copyWith(
                                color: GSWColors.textSecondary,
                              ),
                            )
                          else if (sessionCheckFailed)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'We could not check your upcoming sessions. Please try again.',
                                  style: GSWTextStyles.bodyMedium.copyWith(
                                    color: GSWColors.textSecondary,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _retryUpcomingSessions,
                                  child: const Text('Try again'),
                                ),
                              ],
                            )
                          else if (hasUpcomingSession)
                            _buildUpcomingSessionState(sessions)
                          else
                            _buildNormalDeleteState(),
                        ],
                      ),
                    ),
                  ),
                ),

                _buildBottomActions(
                  hasUpcomingSession: hasUpcomingSession,
                  sessionCheckUnavailable: cannotConfirmNoUpcomingSessions,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildUpcomingSessionState(List<Map<String, dynamic>> sessions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You can request account deletion once you have no upcoming confirmed or booked sessions.',
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
                'You have ${sessions.length} upcoming ${sessions.length == 1 ? 'session' : 'sessions'}',
                style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.textPrimary),
              ),

              const SizedBox(height: 12),

              Text(
                'Please review your upcoming bookings before deleting your account. Cancellation and refund eligibility depend on your booking and the applicable policy.',
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
          "Deleting your sign-in account can't be undone. If you return to GetSetWell, you'll need to sign up again.",
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

          _buildBullet(
            'Your sign-in account is removed when the request succeeds. Other personal data is not yet automatically erased.',
          ),

          const SizedBox(height: 12),

          _buildBullet(
            'Some booking, payment and refund records may need to be retained for legal or operational reasons.',
          ),

          const SizedBox(height: 12),

          _buildBullet('You are signed out on this device when the sign-in account is removed.'),
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

  Widget _buildBottomActions({
    required bool hasUpcomingSession,
    required bool sessionCheckUnavailable,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: sessionCheckUnavailable
          ? GSWButton(
              label: 'Delete my account',
              onPressed: null,
              variant: GSWButtonVariant.disabled,
              size: GSWButtonSize.large,
            )
          : hasUpcomingSession
          ? GSWButton(
              label: 'Go to my booking',
              onPressed: () {
                context.go(GSWRoutes.sessions, extra: 1);
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
