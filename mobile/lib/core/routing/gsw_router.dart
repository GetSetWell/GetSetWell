import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/auth/domain/model/auth_flow_intent.dart';
import 'package:mobile/features/auth/domain/model/otp_route_args.dart';
import 'package:mobile/features/auth/presentation/navigation/auth_flow_resolver.dart';
import 'package:mobile/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:mobile/features/auth/presentation/screens/phone_auth_screen.dart';
import 'package:mobile/features/auth/presentation/screens/user_details_screen.dart';
import 'package:mobile/features/booking/data/services/active_concierge_match_service.dart';
import 'package:mobile/features/booking/domain/models/booking_checkout_data.dart';
import 'package:mobile/features/booking/domain/models/booking_request_route_data.dart';
import 'package:mobile/features/booking/domain/models/booking_success_data.dart';
import 'package:mobile/features/booking/presentation/screens/booking_confirmation_screen.dart';
import 'package:mobile/features/booking/presentation/screens/booking_payment_screen.dart';
import 'package:mobile/features/booking/presentation/screens/booking_request_screen.dart';
import 'package:mobile/features/booking/presentation/screens/booking_success_screen.dart';
import 'package:mobile/features/sessions/presentation/screens/session_details_screen.dart';
import 'package:mobile/features/booking/presentation/screens/concierge_request_status_screen.dart';
import 'package:mobile/features/booking/presentation/screens/help_me_choose_screen.dart';
import 'package:mobile/features/home/presentation/screens/home_screen.dart';
import 'package:mobile/features/legal/presentation/screens/cancellation_refunds_screen.dart';
import 'package:mobile/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:mobile/features/legal/presentation/screens/prohibited_services_screen.dart';
import 'package:mobile/features/legal/presentation/screens/terms_of_service_screen.dart';
import 'package:mobile/features/matching/presentation/screens/matched_trainer_screen.dart';
import 'package:mobile/features/matching/presentation/screens/your_match_screen.dart';
import 'package:mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:mobile/features/profile/presentation/screens/account_deleted_screen.dart';
import 'package:mobile/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:mobile/features/profile/presentation/screens/help_and_support_screen.dart';
import 'package:mobile/features/profile/presentation/screens/language_settings_screen.dart';
import 'package:mobile/features/profile/presentation/screens/legal_screen.dart';
import 'package:mobile/features/profile/presentation/screens/notification_settings_screen.dart';
import 'package:mobile/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:mobile/features/sessions/presentation/screens/sessions_screen.dart';
import 'package:mobile/features/splash/presentation/splash_screen.dart';
import 'package:mobile/features/trainers/domain/models/trainer.dart';
import 'package:mobile/features/trainers/presentation/screens/browse_trainers_screen.dart';
import 'package:mobile/features/trainers/presentation/screens/trainer_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'gsw_routes.dart';

final GoRouter gswRouter = GoRouter(
  routes: [
    // -------------------------------------------------------------------------
    // SPLASH
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.splash,
      builder: (context, state) {
        return const SplashScreen();
      },
    ),

    // -------------------------------------------------------------------------
    // ONBOARDING
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.onboarding,
      builder: (context, state) {
        return const OnboardingScreen();
      },
    ),

    // -------------------------------------------------------------------------
    // TRAINERS
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.browseTrainers,
      builder: (context, state) {
        return const BrowseTrainersScreen();
      },
    ),

    // -------------------------------------------------------------------------
    // Sessions
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.sessions,
      builder: (context, state) {
        return const SessionsScreen();
      },
    ),

    // -------------------------------------------------------------------------
    // User Profile
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.userProfile,
      builder: (context, state) {
        return const UserProfileScreen();
      },
    ),

    // -------------------------------------------------------------------------
    // Matched Trainer
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.matchedTrainer,
      builder: (context, state) {
        final requestId = state.extra as String;

        return MatchedTrainerScreen(requestId: requestId);
      },
    ),

    // -------------------------------------------------------------------------
    // Notification Settings
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.notificationSettings,
      builder: (context, state) {
        return const NotificationSettingsScreen();
      },
    ),

    // -------------------------------------------------------------------------
    // Language Settings
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.languageSettings,
      builder: (context, state) {
        return const LanguageScreen();
      },
    ),

    // -------------------------------------------------------------------------
    // Booking payment
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.bookingPayment,
      builder: (context, state) {
        final checkoutData = state.extra as BookingCheckoutData;

        return BookingPaymentScreen(checkoutData: checkoutData);
      },
    ),

    // -------------------------------------------------------------------------
    // Help & Support
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.helpAndSupport,
      builder: (context, state) {
        return const HelpScreen();
      },
    ),

    // -------------------------------------------------------------------------
    // Concierge Request status
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.conciergeRequestStatus,
      builder: (context, state) {
        final requestId = state.extra?.toString() ?? '';

        return ConciergeRequestStatusScreen(requestId: requestId);
      },
    ),
// -------------------------------------------------------------------------
// Session Details
// -------------------------------------------------------------------------

GoRoute(
  path: GSWRoutes.sessionDetails,
  builder: (context, state) {
    final sessionId = state.extra?.toString() ?? '';

    return SessionDetailsScreen(
      sessionId: sessionId,
    );
  },
),
    // -------------------------------------------------------------------------
    // Booking Confirmation
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.bookingConfirmation,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;

        final checkoutData = extra['checkoutData'] as BookingCheckoutData;

        final referenceCode = extra['referenceCode'] as String?;

        final sessionId = extra['sessionId'] as String?;
        final scheduledAt = extra['scheduledAt'] as String?;

        final locationLabel = extra['locationLabel'] as String?;

        final status = extra['status'] as String?;

        return BookingConfirmationScreen(
          checkoutData: checkoutData,
          referenceCode: referenceCode,
          sessionId: sessionId,
          scheduledAt: scheduledAt,
          locationLabel: locationLabel,
          status: status,
        );
      },
    ),

    // -------------------------------------------------------------------------
    // Legal
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.legal,
      builder: (context, state) {
        return LegalScreen(
          onTermsOfService: () {
            context.push(GSWRoutes.termsOfService);
          },
          onPrivacyPolicy: () {
            context.push(GSWRoutes.privacyPolicy);
          },
          onCancellationAndRefunds: () {
            context.push(GSWRoutes.cancellationAndRefund);
          },
          onProhibitedServices: () {
            context.push(GSWRoutes.prohibitedServices);
          },
        );
      },
    ),

    // -------------------------------------------------------------------------
    // Terms of Service
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.termsOfService,
      builder: (context, state) {
        return const TermsOfServiceScreen();
      },
    ),

    // -------------------------------------------------------------------------
    // Cancellation & Refunds
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.cancellationAndRefund,
      builder: (context, state) {
        return const CancellationRefundsScreen();
      },
    ),

    // -------------------------------------------------------------------------
    // Privacy Policy
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.privacyPolicy,
      builder: (context, state) {
        return const PrivacyPolicyScreen();
      },
    ),

    // -------------------------------------------------------------------------
    // Prohibited Services
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.prohibitedServices,
      builder: (context, state) {
        return const ProhibitedServicesScreen();
      },
    ),

    // -------------------------------------------------------------------------
    // Delete Account
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.deleteAccount,
      builder: (context, state) {
        return DeleteAccountScreen(
          onKeepAccount: () {
            context.go(GSWRoutes.userProfile);
          },
        );
      },
    ),

    // -------------------------------------------------------------------------
    // You Match
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.yourMatch,
      builder: (context, state) {
        final requestId = state.extra as String;

        return YourMatchScreen(requestId: requestId);
      },
    ),
    // -------------------------------------------------------------------------
    // HOME
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.home,
      builder: (context, state) {
        return const HomeScreen();
      },
    ),

    // -------------------------------------------------------------------------
    // TRAINER PROFILE
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.trainerProfile,
      builder: (context, state) {
        final trainer = state.extra;

        if (trainer is! Trainer) {
          return const Scaffold(body: Center(child: Text('Missing trainer data')));
        }

        return TrainerProfileScreen(trainer: trainer);
      },
    ),

    // -------------------------------------------------------------------------
    // DIRECT TRAINER REQUEST
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.bookingRequest,
      builder: (context, state) {
        final data = state.extra as BookingRequestRouteData;

        return BookingRequestScreen(
          trainer: data.trainer,
          sourceConciergeRequestId: data.sourceConciergeRequestId,
        );
      },
    ),

    // -------------------------------------------------------------------------
    // HELP ME CHOOSE
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.helpMeChoose,
      builder: (context, state) {
        final requireAuth = state.extra as bool? ?? false;

        return HelpMeChooseScreen(requireAuth: requireAuth);
      },
    ),

    // -------------------------------------------------------------------------
    // NOTIFICATIONS
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.notifications,
      builder: (context, state) {
        return const NotificationsScreen();
      },
    ),

    // -------------------------------------------------------------------------
    // EDIT PROFILE
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.editProfile,
      builder: (context, state) {
        return const EditProfileScreen();
      },
    ),

    // -------------------------------------------------------------------------
    // BOOKING SUCCESS
    //
    // Shared destination for:
    //
    // 1. ConciergeMatchSuccessData
    // 2. TrainerRequestSuccessData
    //
    // Nothing changes here.
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.bookingSuccess,
      builder: (context, state) {
        final data = state.extra;

        if (data is! BookingSuccessData) {
          return const Scaffold(body: Center(child: Text('Missing booking success data')));
        }

        return BookingSuccessScreen(data: data);
      },
    ),

    // -------------------------------------------------------------------------
    // PHONE AUTH
    //
    // Entry can be:
    //
    // AuthFlowIntent.home()
    // AuthFlowIntent.conciergeMatch(payload)
    //
    // If nothing is supplied, default to home so the existing Get Started /
    // login flow keeps working.
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.userAuth,
      builder: (context, state) {
        final intent = state.extra is AuthFlowIntent
            ? state.extra as AuthFlowIntent
            : const AuthFlowIntent.getStarted();

        return PhoneAuthScreen(
          onClose: () {
            context.pop();
          },

          onOtpSent: (phone) {
            context.push(
              GSWRoutes.userAuthOtp,
              extra: OtpRouteArgs(phone: phone, intent: intent),
            );
          },

          onTermsTap: () {
            context.push(GSWRoutes.termsOfService);
          },

          onPrivacyTap: () {
            context.push(GSWRoutes.privacyPolicy);
          },
        );
      },
    ),

    // -------------------------------------------------------------------------
    // OTP VERIFICATION
    //
    // Important:
    // AuthFlowIntent survives Phone → OTP.
    //
    // We are NOT resolving the intent here yet.
    // Current working routing behaviour is preserved.
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.userAuthOtp,
      builder: (context, state) {
        final args = state.extra;

        if (args is! OtpRouteArgs) {
          return const Scaffold(body: Center(child: Text('Missing OTP route data')));
        }

        return OtpVerificationScreen(
          phone: args.phone,

          onBack: () {
            context.pop();
          },

          onChangeNumber: () {
            context.pop();
          },

          onVerified: (hasCompletedProfile) async {
            debugPrint('OTP verified successfully');

            debugPrint('Profile complete: $hasCompletedProfile');

            debugPrint('Auth intent: ${args.intent.type}');

            debugPrint('Entry point: ${args.intent.entryPoint}');

            debugPrint(
              'Has concierge payload: '
              '${args.intent.conciergePayload != null}',
            );
            // -----------------------------------------------------------------------
            // HELP ME CHOOSE + EXISTING ACTIVE MATCH
            //
            // OTP has now verified ownership of this phone number.
            // Before creating another concierge request, check whether this user
            // already has one in progress or ready.
            // -----------------------------------------------------------------------
            if (args.intent.entryPoint == AuthEntryPoint.helpMeChoose) {
              try {
                final activeMatchService = ActiveConciergeMatchService(Supabase.instance.client);

                final activeMatch = await activeMatchService.getCurrent();

                if (!context.mounted) {
                  return;
                }

                if (activeMatch != null) {
                  final isMatchReady = activeMatch.isMatched;

                  final goal = activeMatch.goal?.trim();
                  final goalLabel = goal == null || goal.isEmpty
                      ? 'Your trainer match'
                      : '${goal[0].toUpperCase()}${goal.substring(1)}';

                  final shouldOpenRequest = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (sheetContext) {
                      return SafeArea(
                        top: false,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                          decoration: const BoxDecoration(
                            color: GSWColors.backgroundPrimary,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                'YOU ALREDY HAVE ONE OPEN REQUEST',
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.displaySmall?.copyWith(color: GSWColors.textPrimary),
                              ),

                              const SizedBox(height: 20),

                              Text(
                                'A person reads every request by hand, so we keep it '
                                'to one at a time. We will come back on these first, '
                                'usually by the next morning.',
                                style: GSWTextStyles.bodyMedium.copyWith(
                                  color: GSWColors.textSecondary,
                                ),
                              ),

                              const SizedBox(height: 20),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: GSWColors.surfacePrimary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        goalLabel,
                                        style: GSWTextStyles.bodyLarge.copyWith(
                                          color: GSWColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: GSWColors.primary,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        isMatchReady ? 'Match ready' : 'Match in progress',
                                        style: GSWTextStyles.bodySmall.copyWith(
                                          color: GSWColors.textInverse,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 32),

                              GSWButton(
                                size: GSWButtonSize.large,
                                variant: GSWButtonVariant.primary,
                                label: 'Go to Home',
                                onPressed: () {
                                  context.go(GSWRoutes.home);
                                },
                              ),

                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      );
                    },
                  );

                  if (!context.mounted) {
                    return;
                  }

                  if (shouldOpenRequest == true) {
                    context.go(GSWRoutes.yourMatch);
                  }

                  return;
                }
              } catch (error) {
                debugPrint('Active concierge match check failed after OTP: $error');
              }
            }
            // -----------------------------------------------------------------------
            // GET STARTED + EXISTING MEMBER
            //
            // They chose Get Started, but this verified phone already belongs
            // to a completed GetSetWell profile.
            // -----------------------------------------------------------------------
            if (args.intent.entryPoint == AuthEntryPoint.getStarted && hasCompletedProfile) {
              await showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) {
                  return AlertDialog(
                    backgroundColor: GSWColors.surfaceElevated,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(
                      'You already have an account',
                      style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.textPrimary),
                    ),
                    content: Text(
                      'This number is already linked to a GetSetWell account. '
                      'We’ll log you in instead.',
                      style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                    ),
                    actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    actions: [
                      SizedBox(
                        width: double.infinity,
                        child: GSWButton(
                          size: GSWButtonSize.large,
                          label: 'Continue',
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                        ),
                      ),
                    ],
                  );
                },
              );

              if (!context.mounted) {
                return;
              }

              context.go(GSWRoutes.home);

              return;
            }
            // -----------------------------------------------------------------------
            // "I ALREADY HAVE AN ACCOUNT" + NO EXISTING PROFILE
            //
            // The phone was successfully verified, but there is no completed
            // GetSetWell profile for this number.
            //
            // Treat them as a new account from this point forward.
            // -----------------------------------------------------------------------
            if (args.intent.entryPoint == AuthEntryPoint.existingAccount && !hasCompletedProfile) {
              await showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) {
                  return AlertDialog(
                    backgroundColor: GSWColors.surfaceElevated,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(
                      'No account found',
                      style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.textPrimary),
                    ),
                    content: Text(
                      'We couldn’t find a GetSetWell account set up for this number. '
                      'Let’s create your profile instead.',
                      style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                    ),
                    actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    actions: [
                      SizedBox(
                        width: double.infinity,
                        child: GSWButton(
                          size: GSWButtonSize.large,
                          label: 'Create profile',
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                        ),
                      ),
                    ],
                  );
                },
              );

              if (!context.mounted) {
                return;
              }

              // Switch them to the new-account flow so
              // Almost There shows "Create account".
              context.go(GSWRoutes.userDetails, extra: const AuthFlowIntent.getStarted());

              return;
            }
            // -----------------------------------------------------------------------
            // RETURNING USER WHO INTENTIONALLY CHOSE LOGIN
            // -----------------------------------------------------------------------
            if (args.intent.entryPoint == AuthEntryPoint.existingAccount && hasCompletedProfile) {
              context.go(GSWRoutes.home);

              return;
            }

            // -----------------------------------------------------------------------
            // RETURNING USER FROM HELP ME CHOOSE
            //
            // Submit the pending concierge request
            // -----------------------------------------------------------------------
            if (args.intent.entryPoint == AuthEntryPoint.helpMeChoose && hasCompletedProfile) {
              debugPrint('Existing member with pending concierge request');

              // Concierge request payload submission.
              await resolveAuthFlow(context, args.intent);

              return;
            }

            // -----------------------------------------------------------------------
            // PROFILE NOT COMPLETE
            //
            // New Get Started user or an incomplete existing profile.
            // Keep the intent alive through Almost There.
            // -----------------------------------------------------------------------
            context.go(GSWRoutes.userDetails, extra: args.intent);
          },
        );
      },
    ),

    // -------------------------------------------------------------------------
    // USER DETAILS / ALMOST THERE
    //
    // New users arrive here after OTP.
    //
    // The AuthFlowIntent now survives:
    //
    // Phone → OTP → User Details
    //
    // For this step we still preserve the existing completion destination.
    // Next we will resolve the intent here.
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.userDetails,
      builder: (context, state) {
        final intent = state.extra is AuthFlowIntent
            ? state.extra as AuthFlowIntent
            : const AuthFlowIntent.getStarted();

        return UserDetailsScreen(
          intent: intent,
          onCompleted: () async {
            debugPrint('User details completed');

            debugPrint('Auth intent: ${intent.type}');

            debugPrint('Entry point: ${intent.entryPoint}');

            debugPrint(
              'Has concierge payload: '
              '${intent.conciergePayload != null}',
            );

            // Concierge request payload submission.
            await resolveAuthFlow(context, intent);
          },
        );
      },
    ),
  ],
);
