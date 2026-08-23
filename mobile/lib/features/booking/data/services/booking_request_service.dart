import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/features/booking/domain/models/booking_request_result.dart';
import 'package:mobile/features/booking/domain/models/concierge_match_payload.dart';
import 'package:mobile/features/booking/domain/models/trainer_request_payload.dart';

class BookingRequestService {
  BookingRequestService(this._client);

  final SupabaseClient _client;

  Future<BookingRequestResult> submitTrainerRequest(
    TrainerRequestPayload payload,
  ) {
    return _submit(payload.toJson());
  }

  Future<BookingRequestResult> submitConciergeMatch(
    ConciergeMatchPayload payload,
  ) {
    return _submit(payload.toJson());
  }

  Future<BookingRequestResult> _submit(
    Map<String, dynamic> body,
  ) async {
    final response = await _client.functions.invoke(
      'create-booking-request',
      body: body,
    );

    final data = response.data;

    if (data is! Map) {
      throw const BookingRequestException(
        'We could not send your request. Please try again.',
      );
    }

    final json = Map<String, dynamic>.from(data);

    if (json['success'] != true) {
      throw BookingRequestException(
        _messageFromResponse(json),
      );
    }

    final requestId = json['request_id'];
    final referenceCode = json['reference_code'];
    final requestType = json['request_type'];

    if (requestId is! String ||
        referenceCode is! String ||
        requestType is! String) {
      throw const BookingRequestException(
        'We could not confirm your request. Please try again.',
      );
    }

    return BookingRequestResult.fromJson(json);
  }

  String _messageFromResponse(
    Map<String, dynamic> json,
  ) {
    final details = json['details'];

    if (details is List && details.isNotEmpty) {
      return details.first.toString();
    }

    return 'We could not send your request. Please try again.';
  }
}

class BookingRequestException implements Exception {
  const BookingRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}