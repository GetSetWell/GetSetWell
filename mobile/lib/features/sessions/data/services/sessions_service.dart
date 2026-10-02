import 'package:supabase_flutter/supabase_flutter.dart';

class SessionsService {
  const SessionsService(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> getUpcomingSessions() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return [];
    }

    final nowUtc = DateTime.now().toUtc().toIso8601String();

    final rows = await _client
        .from('sessions')
        .select('''
          id,
          booking_request_id,
          trainer_id,
          scheduled_at,
          location_label,
          status,
          trainers(
            full_name,
            profile_image_url,
            price_per_session
          )
        ''')
        .eq('user_id', user.id)
        .eq('status', 'confirmed')
        .gte('scheduled_at', nowUtc)
        .order('scheduled_at', ascending: true);

    return rows.map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row)).toList();
  }
}
