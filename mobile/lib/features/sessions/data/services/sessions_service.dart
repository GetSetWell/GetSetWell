import 'package:mobile/core/services/customer_identity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Columns every sessions screen reads. The trainer join carries the primary
/// service and gender so cards and copy never hardcode them.
///
/// `*` returns every sessions column the database has, so the query works
/// before and after the price snapshot migration (session_rate, service_fee,
/// total_amount). Screens fall back to trainers.price_per_session when those
/// are missing or null. Never list the snapshot columns by name here: naming a
/// column the database does not have yet fails the whole query.
const String kSessionSelect = '''
  *,
  booking_requests(
    reference_code,
    goal,
    message,
    created_at
  ),
  trainers(
    id,
    full_name,
    gender,
    profile_image_url,
    price_per_session,
    trainer_services(
      is_primary,
      services(
        name
      )
    )
  )
''';

/// Statuses that mean the session is still booked.
const List<String> kActiveSessionStatusList = ['confirmed', 'booked'];

class SessionsService {
  const SessionsService(this._client);

  final SupabaseClient _client;

  Future<String> _customerId() => CustomerIdentityService(client: _client).getCustomerId();

  /// Booked sessions that have not ended yet. A session stays here until one
  /// hour after its start (the fixed 60 minute length), so one in progress
  /// does not disappear.
  Future<List<Map<String, dynamic>>> getUpcomingSessions() async {
    final customerId = await _customerId();

    final cutoffUtc = DateTime.now().toUtc().subtract(const Duration(hours: 1)).toIso8601String();

    final rows = await _client
        .from('sessions')
        .select(kSessionSelect)
        .eq('user_id', customerId)
        .inFilter('status', kActiveSessionStatusList)
        .gte('scheduled_at', cutoffUtc)
        .order('scheduled_at', ascending: true);

    return rows.map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Sessions that have ended or are closed (completed, reported, cancelled),
  /// newest event first.
  Future<List<Map<String, dynamic>>> getPastSessions() async {
    final customerId = await _customerId();

    final rows = await _client.from('sessions').select(kSessionSelect).eq('user_id', customerId);

    final nowUtc = DateTime.now().toUtc();

    final sessions = rows.map((row) => Map<String, dynamic>.from(row)).where((session) {
      final status = session['status']?.toString().trim().toLowerCase() ?? '';
      if (!kActiveSessionStatusList.contains(status)) return true;

      final start = DateTime.tryParse(session['scheduled_at']?.toString() ?? '');
      if (start == null) return false;
      return !start.toUtc().add(const Duration(hours: 1)).isAfter(nowUtc);
    }).toList();

    DateTime eventTime(Map<String, dynamic> session) {
      final status = session['status']?.toString().trim().toLowerCase() ?? '';
      if (status == 'cancelled' || status == 'canceled') {
        final cancelledAt = DateTime.tryParse(session['cancelled_at']?.toString() ?? '');
        if (cancelledAt != null) return cancelledAt.toUtc();
      }
      final start = DateTime.tryParse(session['scheduled_at']?.toString() ?? '');
      if (start != null) return start.toUtc().add(const Duration(hours: 1));
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    sessions.sort((a, b) => eventTime(b).compareTo(eventTime(a)));

    return sessions;
  }

  /// One session owned by the current customer.
  Future<Map<String, dynamic>> getSession(String sessionId) async {
    if (sessionId.trim().isEmpty) throw Exception('Missing session ID.');

    final customerId = await _customerId();

    final row = await _client
        .from('sessions')
        .select(kSessionSelect)
        .eq('id', sessionId)
        .eq('user_id', customerId)
        .single();

    return Map<String, dynamic>.from(row);
  }

  /// The customer's Help me choose requests, newest first, with the trainer
  /// (for the recommendation or booking) and any session booked from them.
  Future<List<Map<String, dynamic>>> getConciergeRequests() async {
    final customerId = await _customerId();

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
          trainer_id,
          matched_at,
          created_at,
          trainers!booking_requests_trainer_id_fkey(
            id,
            full_name,
            gender,
            profile_image_url
          ),
          sessions(
            id,
            scheduled_at,
            status
          )
        ''')
        .eq('user_id', customerId)
        .eq('request_type', 'concierge_match')
        .order('created_at', ascending: false);

    return rows.map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// The booked session that came from a request, if any.
  Future<String?> getSessionIdForRequest(String requestId) async {
    if (requestId.trim().isEmpty) return null;

    final customerId = await _customerId();

    final row = await _client
        .from('sessions')
        .select('id')
        .eq('booking_request_id', requestId)
        .eq('user_id', customerId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final id = row?['id']?.toString().trim() ?? '';
    return id.isEmpty ? null : id;
  }
}
