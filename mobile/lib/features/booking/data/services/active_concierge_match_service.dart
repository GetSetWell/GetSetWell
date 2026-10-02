import 'package:mobile/features/booking/domain/models/active_concierge_match.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActiveConciergeMatchService {
  ActiveConciergeMatchService(this._client);

  final SupabaseClient _client;

  static const Set<String> _terminalStatuses = {
    'confirmed',
    'booked',
    'completed',
    'closed',
    'cancelled',
    'canceled',
    'lost',
  };

  Future<ActiveConciergeMatch?> getCurrent() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return null;
    }

    final rows = await _client
        .from('booking_requests')
        .select('id, reference_code, status, goal, trainer_id, created_at')
        .eq('user_id', user.id)
        .eq('request_type', 'concierge_match')
        .order('created_at', ascending: false)
        .limit(10);

    for (final rawRow in rows) {
      final row = Map<String, dynamic>.from(rawRow);
      final status = row['status']?.toString().trim().toLowerCase() ?? '';

      if (status.isEmpty || _terminalStatuses.contains(status)) {
        continue;
      }

      return ActiveConciergeMatch.fromJson(row);
    }

    return null;
  }

  Future<bool> hasActiveMatch() async {
    return await getCurrent() != null;
  }
}
