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
import 'package:mobile/features/booking/domain/models/booking_success_data.dart';
import 'package:mobile/features/booking/presentation/screens/booking_request_screen.dart';
import 'package:mobile/features/booking/presentation/screens/booking_success_screen.dart';
import 'package:mobile/features/booking/presentation/screens/help_me_choose_screen.dart';
import 'package:mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:mobile/features/splash/presentation/splash_screen.dart';
import 'package:mobile/features/trainers/domain/models/trainer.dart';
import 'package:mobile/features/trainers/presentation/screens/browse_trainers_screen.dart';
import 'package:mobile/features/home/presentation/screens/home_screen.dart';
import 'package:mobile/features/trainers/presentation/screens/trainer_profile_screen.dart';

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
        final trainer = state.extra;

        if (trainer is! Trainer) {
          return const Scaffold(body: Center(child: Text('Missing trainer data')));
        }

        return BookingRequestScreen(trainer: trainer);
      },
    ),

    // -------------------------------------------------------------------------
    // HELP ME CHOOSE
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.helpMeChoose,
      builder: (context, state) {
        return const HelpMeChooseScreen();
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
            context.push(GSWRoutes.terms);
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
