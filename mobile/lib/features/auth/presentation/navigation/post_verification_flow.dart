import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/services/customer_identity_service.dart';
import 'package:mobile/core/services/push_notification_service.dart';
import 'package:mobile/features/booking/data/services/active_concierge_match_service.dart';
import 'package:mobile/features/booking/domain/models/active_concierge_match.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthFlowType;

import '../../data/repositories/profile_repository.dart';
import '../../domain/model/auth_flow_intent.dart';
import '../screens/open_request_choice_screen.dart';
import '../widgets/account_state_sheets.dart';
import 'auth_flow_resolver.dart';

/// Signs out (removing this device's push token first) and returns to phone
/// entry with the same intent, keeping the screens below it.
///
/// Used by "Not you? Use a different number" (3.8), "Use a different number"
/// (3.9 and 3.4) and "Change number" once a code has been accepted.
Future<void> signOutAndChangeNumber(BuildContext context, AuthFlowIntent intent) async {
  if (FirebaseAuth.instance.currentUser != null) {
    try {
      await PushNotificationService().deleteCurrentDeviceToken();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Push token removal before sign-out failed: $error');
      }
    }

    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Sign-out failed: $error');
      }
    }
  }

  if (!context.mounted) return;

  // The code screen sits on top of phone entry, so popping it returns there
  // with the number still filled in.
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(GSWRoutes.userAuth, extra: intent);
  }
}

/// Decides what happens once the code is verified and the profile check
/// succeeded. Completes only after navigation has started (or after a sheet
/// was answered), so the code screen stays busy until then.
Future<void> handlePhoneVerified({
  required BuildContext context,
  required AuthFlowIntent intent,
  required String phone,
  required bool hasCompletedProfile,
}) async {
  // ---------------------------------------------------------------------------
  // SIGN IN FROM A BOOKING: return to the booking
  // ---------------------------------------------------------------------------
  if (intent.type == AuthFlowType.returnToCaller) {
    if (hasCompletedProfile) {
      await resolveAuthFlow(context, intent);
      return;
    }

    final action = await showNoAccountSheet(context: context, phone: phone);

    if (!context.mounted) return;

    if (action == AccountSheetAction.secondary) {
      await signOutAndChangeNumber(context, intent);
      return;
    }

    // Pushed (not go) so the booking stays underneath and Your details can
    // pop back to it once the profile is saved.
    unawaited(context.push(GSWRoutes.userDetails, extra: intent));
    return;
  }

  // ---------------------------------------------------------------------------
  // HELP ME CHOOSE: one open request at a time (3.6 / 3.7)
  // ---------------------------------------------------------------------------
  if (intent.entryPoint == AuthEntryPoint.helpMeChoose) {
    final handled = await _handleExistingOpenRequest(
      context: context,
      intent: intent,
      hasCompletedProfile: hasCompletedProfile,
    );

    if (handled || !context.mounted) return;

    if (hasCompletedProfile) {
      await resolveAuthFlow(context, intent);
    } else {
      context.go(GSWRoutes.userDetails, extra: intent);
    }

    return;
  }

  // ---------------------------------------------------------------------------
  // "I ALREADY HAVE AN ACCOUNT"
  // ---------------------------------------------------------------------------
  if (intent.entryPoint == AuthEntryPoint.existingAccount) {
    if (hasCompletedProfile) {
      context.go(GSWRoutes.home);
      return;
    }

    // 3.9 No account on this number yet.
    final action = await showNoAccountSheet(context: context, phone: phone);

    if (!context.mounted) return;

    if (action == AccountSheetAction.secondary) {
      await signOutAndChangeNumber(context, intent);
      return;
    }

    // Keeps the existingAccount entry so Your details reads "Continue"
    // (Figma note 1006:3364). Finishing still goes Home, as for Get started.
    context.go(GSWRoutes.userDetails, extra: intent);
    return;
  }

  // ---------------------------------------------------------------------------
  // GET STARTED
  // ---------------------------------------------------------------------------
  if (!hasCompletedProfile) {
    context.go(GSWRoutes.userDetails, extra: intent);
    return;
  }

  // 3.8 This number already has an account: signed in instead.
  final firstName = await _firstNameOrNull();

  if (!context.mounted) return;

  final action = await showAccountExistsSheet(context: context, firstName: firstName);

  if (!context.mounted) return;

  if (action == AccountSheetAction.secondary) {
    await signOutAndChangeNumber(context, intent);
    return;
  }

  context.go(GSWRoutes.home);
}

Future<String?> _firstNameOrNull() async {
  try {
    return await ProfileRepository().fetchFirstName();
  } catch (error) {
    if (kDebugMode) {
      debugPrint('First name lookup failed: $error');
    }

    return null;
  }
}

/// Returns true when an open request existed and the person's choice was
/// carried out (or the flow should stop here).
Future<bool> _handleExistingOpenRequest({
  required BuildContext context,
  required AuthFlowIntent intent,
  required bool hasCompletedProfile,
}) async {
  final payload = intent.conciergePayload;

  if (payload == null) return false;

  final client = Supabase.instance.client;

  final ActiveConciergeMatch? activeMatch;

  try {
    activeMatch = await ActiveConciergeMatchService(client).getCurrent();
  } catch (error) {
    // The database still enforces one open request; let the submit report it.
    if (kDebugMode) {
      debugPrint('Active concierge check after sign-in failed: $error');
    }

    return false;
  }

  if (activeMatch == null || activeMatch.id.isEmpty || !context.mounted) {
    return false;
  }

  final match = activeMatch;

  final firstName = await _firstNameOrNull();

  // 3.6: same goal asked again. Keep the open request and add the new note
  // to it rather than creating a second request. Best effort: if saving the
  // note fails, the screen simply does not claim it was added.
  String? addedNote;
  final newNote = payload.message?.trim() ?? '';
  final isSameGoal = OpenRequestChoiceScreen(
    activeMatch: match,
    newGoal: payload.goal,
  ).isSameGoal;

  if (isSameGoal && newNote.isNotEmpty) {
    try {
      await client.rpc(
        'append_concierge_note',
        params: {'p_request_id': match.id, 'p_note': newNote},
      );
      addedNote = newNote;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Adding the note to the open request failed: $error');
      }
    }
  }

  if (!context.mounted) return true;

  final choice = await Navigator.of(context).push<OpenRequestChoice>(
    MaterialPageRoute<OpenRequestChoice>(
      builder: (_) => OpenRequestChoiceScreen(
        activeMatch: match,
        newGoal: payload.goal,
        firstName: firstName,
        addedNote: addedNote,
      ),
    ),
  );

  if (!context.mounted) return true;

  if (choice == OpenRequestChoice.seeRequest) {
    context.go(
      match.isMatched ? GSWRoutes.yourMatch : GSWRoutes.conciergeRequestStatus,
      extra: match.id,
    );
    return true;
  }

  if (choice != OpenRequestChoice.sendNew) {
    // Go to Home, Keep my open request, or system back.
    context.go(GSWRoutes.home);
    return true;
  }

  try {
    final customerId = await CustomerIdentityService(client: client).getCustomerId();

    await client
        .from('booking_requests')
        .update({'status': 'cancelled'})
        .eq('id', match.id)
        .eq('user_id', customerId)
        .eq('request_type', 'concierge_match');
  } catch (error) {
    if (kDebugMode) {
      debugPrint('Closing the open request failed: $error');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We could not close your open request. Please try again.'),
        ),
      );
    }

    return true;
  }

  if (!context.mounted) return true;

  if (hasCompletedProfile) {
    await resolveAuthFlow(context, intent);
  } else {
    context.go(GSWRoutes.userDetails, extra: intent);
  }

  return true;
}
