import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:mobile/features/profile/data/services/account_deletion_service.dart';
import 'package:mobile/features/sessions/data/services/sessions_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/routing/gsw_routes.dart';
import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';
import '../../../../core/widgets/buttons/gsw_button.dart';
import '../../../../core/widgets/inputs/gsw_text_field.dart';

/// 12.6a Delete account, session booked (Figma 819:3698) and
/// 12.6b Delete account, nothing booked (Figma 1086:3780).
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

  /// Deletion can fail after the person was already signed out. A signed-out
  /// person must not stay on this screen, so send them to Welcome.
  bool _leaveIfSignedOut() {
    if (FirebaseAuth.instance.currentUser != null) return false;
    if (mounted) context.go(GSWRoutes.onboarding);
    return true;
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
      if (_leaveIfSignedOut()) return;
      final requiresRecentLogin = error.message.toLowerCase().contains('sign in again');
      _showDeletionError(
        requiresRecentLogin
            ? 'Please sign in again before deleting your account.'
            : 'We could not confirm account deletion. Contact info@getsetwell.com before trying again.',
      );
      _retryUpcomingSessions();
    } catch (error) {
      debugPrint('Delete account failed: $error');
      if (_leaveIfSignedOut()) return;
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBackButton(),

                          const SizedBox(height: 24),

                          Text(
                            'Delete your account',
                            style: GSWTextStyles.titleLarge.copyWith(
                              height: 30 / 24,
                              color: GSWColors.textPrimary,
                            ),
                          ),

                          const SizedBox(height: 24),

                          if (isCheckingSessions)
                            Text(
                              'Checking your upcoming sessions...',
                              style: GSWTextStyles.bodyMedium.copyWith(
                                height: 20 / 14,
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
                                    height: 20 / 14,
                                    color: GSWColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                GSWButton(
                                  label: 'Try again',
                                  variant: GSWButtonVariant.secondary,
                                  size: GSWButtonSize.medium,
                                  fullWidth: false,
                                  onPressed: _retryUpcomingSessions,
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

  TextStyle get _introStyle =>
      GSWTextStyles.bodyMedium.copyWith(height: 20 / 14, color: GSWColors.textSecondary);

  Widget _buildDataCopyNote() {
    return Text(
      'Want a copy of your data first? Email info@getsetwell.com.',
      style: GSWTextStyles.bodySmall.copyWith(height: 16 / 12, color: GSWColors.textTertiary),
    );
  }

  /// Refund line for the warning card, bound to the first upcoming session.
  /// Uses the price snapshot on the session (falls back to the trainer rate).
  String _upcomingRefundLine(List<Map<String, dynamic>> sessions) {
    if (sessions.length != 1) {
      return 'Cancel them before you delete your account. What you get back depends on '
          'how far away each one is.';
    }

    final session = sessions.first;
    final trainer = session['trainers'];
    final rate =
        GSWMoney.parse(session['session_rate']) ??
        (trainer is Map ? GSWMoney.parse(trainer['price_per_session']) : null);

    final start = GSWTime.parseToDubai(session['scheduled_at']);
    if (start == null || rate == null) {
      return 'Cancel it before you delete your account.';
    }

    final hoursAway = start.difference(GSWTime.nowDubai()).inMinutes / 60;

    if (hoursAway >= 24) {
      return "Cancel it before you delete your account. It's more than 24 hours away, "
          "so you'd get the ${GSWMoney.aed(rate)} session rate back.";
    }

    return "Cancel it before you delete your account. It's less than 24 hours away, "
        "so you'd get half the session rate back, ${GSWMoney.aed(GSWMoney.half(rate))}.";
  }

  /// 12.6a: an upcoming session blocks deletion.
  Widget _buildUpcomingSessionState(List<Map<String, dynamic>> sessions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You can delete your account once you have no upcoming sessions.',
          style: _introStyle,
        ),

        const SizedBox(height: 24),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(GSWRadius.card),
            border: Border.all(color: GSWColors.borderError),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have ${sessions.length} upcoming ${sessions.length == 1 ? 'session' : 'sessions'}',
                style: GSWTextStyles.labelLarge.copyWith(
                  height: 22 / 16,
                  color: GSWColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              Text(_upcomingRefundLine(sessions), style: _introStyle),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _buildDataCopyNote(),
      ],
    );
  }

  /// 12.6b: nothing booked, type DELETE to confirm.
  Widget _buildNormalDeleteState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "This can't be undone. To use GetSetWell again, you'd sign up as a new customer.",
          style: _introStyle,
        ),

        const SizedBox(height: 24),

        _buildWhatHappensCard(),

        const SizedBox(height: 24),

        _buildDataCopyNote(),

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

  Widget _buildWhatHappensCard() {
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
            'What happens',
            style: GSWTextStyles.bodyLarge.copyWith(
              fontSize: 15,
              height: 20 / 15,
              fontWeight: FontWeight.w600,
              color: GSWColors.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          // Figma 12.6a/12.6b. True end to end: the sign-in account, profile,
          // photo and notifications go immediately, and a daily job strips
          // names, numbers, notes and addresses from retained booking records
          // (migration 20261013170500).
          _buildBullet(
            'Your account, name, mobile number and email are deleted within 30 days.',
          ),

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
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: GSWColors.textSecondary, shape: BoxShape.circle),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(child: Text(text, style: _introStyle)),
      ],
    );
  }

  Widget _buildBottomActions({
    required bool hasUpcomingSession,
    required bool sessionCheckUnavailable,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
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

                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _isDeleting ? null : widget.onKeepAccount,
                  child: SizedBox(
                    width: double.infinity,
                    child: Opacity(
                      opacity: 0.6,
                      child: Text(
                        'Keep my account',
                        textAlign: TextAlign.center,
                        style: GSWTextStyles.labelMedium.copyWith(
                          height: 20 / 14,
                          color: GSWColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
