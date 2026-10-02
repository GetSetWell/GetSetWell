import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/features/auth/domain/model/auth_flow_intent.dart';
import 'package:mobile/features/booking/data/services/booking_request_service.dart';
import 'package:mobile/features/booking/domain/models/booking_success_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthFlowType;

Future<void> resolveAuthFlow(
  BuildContext context,
  AuthFlowIntent intent,
) async {
  final client = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // NORMAL AUTH FLOW
  // ---------------------------------------------------------------------------
  if (intent.type == AuthFlowType.home) {
    context.go(GSWRoutes.home);
    return;
  }

  // ---------------------------------------------------------------------------
  // CONCIERGE MATCH
  // ---------------------------------------------------------------------------
  if (intent.type == AuthFlowType.conciergeMatch) {
    final payload = intent.conciergePayload;

    if (payload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not find your matching request. Please try again.',
          ),
        ),
      );
      return;
    }

    // A concierge request must belong to an authenticated customer.
    // If the session disappeared, return to the existing auth flow and
    // preserve the pending concierge payload.
    final user = client.auth.currentUser;

    if (user == null) {
      if (!context.mounted) return;

      context.go(GSWRoutes.userAuth, extra: intent);
      return;
    }

    // Check the profile before calling the Edge Function.
    //
    // The backend requires:
    // - authenticated phone from Supabase Auth/customer_profiles
    // - full_name
    // - city
    //
    // Phone is already guaranteed by the authenticated phone/OTP flow.
    // If name/city are missing, send the user to the existing "Almost There"
    // screen instead of allowing the Edge Function to return HTTP 409.
    try {
      final profile = await client
          .from('customer_profiles')
          .select('full_name, city')
          .eq('id', user.id)
          .maybeSingle();

      final fullName = profile?['full_name']?.toString().trim() ?? '';
      final city = profile?['city']?.toString().trim() ?? '';

      final isProfileComplete = fullName.isNotEmpty && city.isNotEmpty;

      if (!isProfileComplete) {
        if (!context.mounted) return;

        context.go(GSWRoutes.userDetails, extra: intent);
        return;
      }
    } catch (error) {
      debugPrint(
        'Failed to check customer profile before concierge request: $error',
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We could not check your profile. Please try again.'),
        ),
      );
      return;
    }

    try {
      final bookingRequestService = BookingRequestService(client);

      final result = await bookingRequestService.submitConciergeMatch(payload);

      if (!context.mounted) {
        return;
      }

      context.go(
        GSWRoutes.bookingSuccess,
        extra: ConciergeMatchSuccessData(
          requestId: result.requestId,
          referenceCode: result.referenceCode,
          goal: payload.goal,
          days: _formatDays(payload.preferredDays),
          time: _formatLabel(payload.preferredTime),
          trainingLocation: payload.trainingLocationName,
          preferredArea: payload.preferredArea,
          trainerPreference: payload.trainerGenderPreference == 'female'
              ? 'Female'
              : null,
          budget: _formatBudget(payload.budgetMin, payload.budgetMax),
          language: payload.languagePreference,
        ),
      );
    } on FunctionsHttpException catch (error) {
      debugPrint('Concierge Edge Function failed: $error');

      if (!context.mounted) {
        return;
      }

      // Safety fallback:
      // the profile can become incomplete between the client-side check
      // and the server-side validation. Treat the backend 409 the same way.
      if (_isProfileIncompleteError(error)) {
        context.go(GSWRoutes.userDetails, extra: intent);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We could not send your request. Please try again.'),
        ),
      );
    } on BookingRequestException catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      debugPrint('Failed to resolve concierge request: $error');

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We could not send your request. Please try again.'),
        ),
      );
    }
  }
}

bool _isProfileIncompleteError(FunctionsHttpException error) {
  if (error.status != 409) {
    return false;
  }

  final details = error.details;

  if (details is Map) {
    final errorValue = details['error']?.toString().trim().toLowerCase();

    return errorValue == 'profile incomplete';
  }

  return details.toString().toLowerCase().contains('profile incomplete');
}

String _formatDays(List<String> days) {
  return days
      .map((day) {
        final trimmed = day.trim();

        if (trimmed.isEmpty) {
          return '';
        }

        final short = trimmed.length > 3 ? trimmed.substring(0, 3) : trimmed;

        return '${short[0].toUpperCase()}'
            '${short.substring(1).toLowerCase()}';
      })
      .where((day) {
        return day.isNotEmpty;
      })
      .join(', ');
}

String _formatLabel(String value) {
  final trimmed = value.trim();

  if (trimmed.isEmpty) {
    return '';
  }

  return '${trimmed[0].toUpperCase()}'
      '${trimmed.substring(1).toLowerCase()}';
}

String? _formatBudget(int? minimum, int? maximum) {
  if (minimum == null || maximum == null) {
    return null;
  }

  return 'AED $minimum–$maximum';
}
