import 'package:mobile/features/booking/domain/models/booking_request_result.dart';
import 'package:mobile/features/booking/domain/models/concierge_match_payload.dart';
import 'package:mobile/features/booking/domain/models/trainer_request_payload.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingRequestService {
  BookingRequestService(this._client);

  final SupabaseClient _client;

  Future<BookingRequestResult> submitTrainerRequest(TrainerRequestPayload payload) {
    return _submit(payload.toJson());
  }

  Future<BookingRequestResult> submitConciergeMatch(ConciergeMatchPayload payload) {
    return _submit(payload.toJson());
  }

  Future<BookingRequestResult> _submit(Map<String, dynamic> body) async {
    final response = await _client.functions.invoke('create-booking-request', body: body);

    final data = response.data;

    if (data is! Map) {
      throw const BookingRequestException('We could not send your request. Please try again.');
    }

    final json = Map<String, dynamic>.from(data);

    if (json['success'] != true) {
      throw BookingRequestException(_messageFromResponse(json));
    }

    final requestId = json['request_id'];
    final referenceCode = json['reference_code'];
    final requestType = json['request_type'];

    if (requestId is! String || referenceCode is! String || requestType is! String) {
      throw const BookingRequestException('We could not confirm your request. Please try again.');
    }

    return BookingRequestResult.fromJson(json);
  }

  String _messageFromResponse(Map<String, dynamic> json) {
    final details = json['details'];

    if (details is List && details.isNotEmpty) {
      return details.first.toString();
    }

    return 'We could not send your request. Please try again.';
  }

  Future<List<Map<String, dynamic>>> getMyRequests() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return [];
    }

    final rows = await _client
        .from('booking_requests')
        .select('''
        id,
        reference_code,
        request_type,
        status,
        goal,
        preferred_days,
        preferred_time,
        preferred_area,
        trainer_gender_preference,
        budget_min,
        budget_max,
        language_preference,
        message,
        trainer_id,
        created_at,
        training_locations (
          name
        ),
        trainers!booking_requests_trainer_id_fkey(
        id,
        full_name,
        profile_image_url,
        price_per_session
        )
      ''')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return rows.map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row)).toList();
  }
}

class BookingRequestException implements Exception {
  const BookingRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}
