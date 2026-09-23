import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/features/auth/domain/model/auth_flow_intent.dart';
import 'package:mobile/features/booking/data/services/booking_request_service.dart';
import 'package:mobile/features/booking/domain/models/booking_success_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthFlowType;

Future<void> resolveAuthFlow(BuildContext context, AuthFlowIntent intent) async {
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
        const SnackBar(content: Text('We could not find your matching request. Please try again.')),
      );

      return;
    }

    try {
      final bookingRequestService = BookingRequestService(Supabase.instance.client);

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

          trainerPreference: payload.trainerGenderPreference == 'female' ? 'Female' : null,

          budget: _formatBudget(payload.budgetMin, payload.budgetMax),

          language: payload.languagePreference,
        ),
      );
    } on BookingRequestException catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      debugPrint('Failed to resolve concierge request: $error');

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not send your request. Please try again.')),
      );
    }
  }
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
