import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/domain/model/auth_flow_intent.dart';
import 'package:mobile/features/auth/domain/model/otp_route_args.dart';
import 'package:mobile/features/auth/presentation/navigation/auth_flow_resolver.dart';
import 'package:mobile/features/auth/presentation/navigation/post_verification_flow.dart';
import 'package:mobile/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:mobile/features/auth/presentation/screens/phone_auth_screen.dart';
import 'package:mobile/features/auth/presentation/screens/user_details_screen.dart';
import 'package:mobile/features/booking/domain/models/booking_checkout_data.dart';
import 'package:mobile/features/booking/domain/models/booking_request_route_data.dart';
import 'package:mobile/features/booking/domain/models/booking_success_data.dart';
import 'package:mobile/features/booking/presentation/screens/booking_confirmation_screen.dart';
import 'package:mobile/features/booking/presentation/screens/booking_payment_screen.dart';
import 'package:mobile/features/booking/presentation/screens/booking_request_screen.dart';
import 'package:mobile/features/booking/presentation/screens/booking_success_screen.dart';
import 'package:mobile/features/booking/presentation/screens/concierge_request_status_screen.dart';
import 'package:mobile/features/booking/presentation/screens/help_me_choose_screen.dart';
import 'package:mobile/features/home/presentation/screens/home_screen.dart';
import 'package:mobile/features/legal/presentation/screens/cancellation_refunds_screen.dart';
import 'package:mobile/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:mobile/features/legal/presentation/screens/prohibited_services_screen.dart';
import 'package:mobile/features/legal/presentation/screens/terms_of_service_screen.dart';
import 'package:mobile/core/widgets/common/gsw_missing_route_data_screen.dart';
import 'package:mobile/features/matching/presentation/screens/matched_trainer_screen.dart';
import 'package:mobile/features/matching/presentation/screens/nobody_fits_screen.dart';
import 'package:mobile/features/matching/presentation/screens/your_match_screen.dart';
import 'package:mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:mobile/features/profile/presentation/screens/account_deleted_screen.dart';
import 'package:mobile/features/profile/presentation/screens/change_phone_screen.dart';
import 'package:mobile/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:mobile/features/profile/presentation/screens/help_and_support_screen.dart';
import 'package:mobile/features/profile/presentation/screens/language_settings_screen.dart';
import 'package:mobile/features/profile/presentation/screens/legal_screen.dart';
import 'package:mobile/features/profile/presentation/screens/notification_settings_screen.dart';
import 'package:mobile/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:mobile/features/sessions/presentation/screens/cancel_session_screen.dart';
import 'package:mobile/features/sessions/presentation/screens/move_session_screen.dart';
import 'package:mobile/features/sessions/presentation/screens/session_cancelled_screen.dart';
import 'package:mobile/features/sessions/presentation/screens/session_details_screen.dart';
import 'package:mobile/features/sessions/presentation/screens/sessions_screen.dart';
import 'package:mobile/features/splash/presentation/splash_screen.dart';
import 'package:mobile/features/trainers/domain/models/trainer.dart';
import 'package:mobile/features/trainers/presentation/screens/browse_trainers_screen.dart';
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

    // Session cancelled

    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.sessionCancelled,

      builder: (context, state) {
        final sessionId = state.extra?.toString() ?? '';

        return SessionCancelledScreen(sessionId: sessionId);
      },
    ),

    // -------------------------------------------------------------------------

    // Change phone

    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.changePhone,

      builder: (context, state) {
        final currentPhone = state.extra?.toString() ?? '';

        return ChangePhoneScreen(currentPhone: currentPhone);
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

    // Cancel session

    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.cancelSession,

      builder: (context, state) {
        final sessionId = state.extra?.toString() ?? '';

        return CancelSessionScreen(sessionId: sessionId);
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
        final initialTab = state.extra is int ? state.extra as int : 0;

        return SessionsScreen(initialTab: initialTab);
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
        final requestId = state.extra?.toString() ?? '';
        if (requestId.isEmpty) return const GSWMissingRouteDataScreen();

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
        final checkoutData = state.extra;
        if (checkoutData is! BookingCheckoutData) {
          return const GSWMissingRouteDataScreen();
        }

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
        final extra = state.extra;

        if (extra is Map) {
          return SessionDetailsScreen(
            sessionId: extra['sessionId']?.toString() ?? '',
            openFeedback: extra['openFeedback'] == true,
          );
        }

        return SessionDetailsScreen(sessionId: extra?.toString() ?? '');
      },
    ),

    // -------------------------------------------------------------------------

    // Move Session

    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.moveSession,

      builder: (context, state) {
        final sessionId = state.extra?.toString() ?? '';

        return MoveSessionScreen(sessionId: sessionId);
      },
    ),

    // -------------------------------------------------------------------------

    // Booking Confirmation

    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.bookingConfirmation,

      builder: (context, state) {
        final extra = state.extra;
        if (extra is! Map || extra['checkoutData'] is! BookingCheckoutData) {
          return const GSWMissingRouteDataScreen();
        }

        final checkoutData = extra['checkoutData'] as BookingCheckoutData;

        final referenceCode = extra['referenceCode']?.toString();

        final sessionId = extra['sessionId']?.toString();

        final scheduledAt = extra['scheduledAt']?.toString();

        final locationLabel = extra['locationLabel']?.toString();

        final status = extra['status']?.toString();

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
        final requestId = state.extra?.toString() ?? '';
        if (requestId.isEmpty) return const GSWMissingRouteDataScreen();

        return YourMatchScreen(requestId: requestId);
      },
    ),

    // -------------------------------------------------------------------------

    // Nobody fits yet (4.4)

    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.matchNoFit,

      builder: (context, state) {
        final requestId = state.extra?.toString() ?? '';
        if (requestId.isEmpty) return const GSWMissingRouteDataScreen();

        return NobodyFitsScreen(requestId: requestId);
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
          return const GSWMissingRouteDataScreen();
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
        final data = state.extra;
        if (data is! BookingRequestRouteData) {
          return const GSWMissingRouteDataScreen();
        }

        return BookingRequestScreen(
          trainer: data.trainer,
          sourceConciergeRequestId: data.sourceConciergeRequestId,
          initialGoal: data.initialGoal,
          initialTrainingPlace: data.initialTrainingPlace,
          initialVenueChoice: data.initialVenueChoice,
          initialLocationLabel: data.initialLocationLabel,
          initialNotes: data.initialNotes,
          isRepeatBooking: data.isRepeatBooking,
        );
      },
    ),

    // -------------------------------------------------------------------------

    // HELP ME CHOOSE

    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.helpMeChoose,

      builder: (context, state) {
        final requireAuth = state.extra == true;

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

    // ConciergeMatchSuccessData

    //

    // Nothing changes here.

    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.bookingSuccess,

      builder: (context, state) {
        final data = state.extra;

        if (data is! BookingSuccessData) {
          return const GSWMissingRouteDataScreen();
        }

        return BookingSuccessScreen(data: data);
      },
    ),

    // -------------------------------------------------------------------------
    // PHONE AUTH (3.1)
    //
    // Entry intents: getStarted, existingAccount, conciergeMatch(payload),
    // returnToCaller. Nothing supplied means getStarted.
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.userAuth,

      builder: (context, state) {
        final intent = state.extra is AuthFlowIntent
            ? state.extra as AuthFlowIntent
            : const AuthFlowIntent.getStarted();

        return PhoneAuthScreen(
          onClose: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(GSWRoutes.onboarding);
            }
          },

          onOtpSent: (phone, request) {
            context.push(
              GSWRoutes.userAuthOtp,
              extra: OtpRouteArgs(
                phone: phone,
                intent: intent,
                verificationId: request.verificationId,
                resendToken: request.resendToken,
                autoVerified: request.autoVerified,
              ),
            );
          },
        );
      },
    ),

    // -------------------------------------------------------------------------
    // CODE (3.2 to 3.4), then the account-state decisions (3.6 to 3.9) in
    // handlePhoneVerified. The code screen stays busy until that completes.
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.userAuthOtp,

      builder: (context, state) {
        final args = state.extra;

        if (args is! OtpRouteArgs) {
          return const GSWMissingRouteDataScreen();
        }

        // Once a code is accepted the person is signed in, so leaving this
        // screen also signs out (and removes this device's push token).
        Future<void> changeNumber() => signOutAndChangeNumber(context, args.intent);

        return OtpVerificationScreen(
          phone: args.phone,
          verificationId: args.verificationId,
          resendToken: args.resendToken,
          autoVerified: args.autoVerified,

          onBack: changeNumber,

          onChangeNumber: changeNumber,

          onVerified: (hasCompletedProfile) {
            return handlePhoneVerified(
              context: context,
              intent: args.intent,
              phone: args.phone,
              hasCompletedProfile: hasCompletedProfile,
            );
          },
        );
      },
    ),

    // -------------------------------------------------------------------------
    // YOUR DETAILS (3.5)
    //
    // Reached after the code for new accounts. For returnToCaller it is
    // pushed on top of phone entry and code, so three screens pop on finish.
    // -------------------------------------------------------------------------
    GoRoute(
      path: GSWRoutes.userDetails,

      builder: (context, state) {
        final intent = state.extra is AuthFlowIntent
            ? state.extra as AuthFlowIntent
            : const AuthFlowIntent.getStarted();

        return UserDetailsScreen(
          intent: intent,

          onCompleted: () {
            return resolveAuthFlow(context, intent, authRoutesOnStack: 3);
          },
        );
      },
    ),
  ],
);
