import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  ProfileRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User? get _currentUser => _client.auth.currentUser;

  Future<bool> hasCompletedProfile() async {
    final user = _currentUser;

    if (user == null) {
      return false;
    }

    final profile = await _client
        .from('customer_profiles')
        .select('full_name, city')
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) {
      return false;
    }

    final fullName = profile['full_name']?.toString().trim() ?? '';

    final city = profile['city']?.toString().trim() ?? '';

    return fullName.isNotEmpty && city.isNotEmpty;
  }

  Future<void> saveBasicProfile({
    required String fullName,
    required String city,
  }) async {
    final user = _currentUser;

    if (user == null) {
      throw StateError('Cannot save profile without an authenticated user.');
    }

    final phone = user.phone;

    if (phone == null || phone.trim().isEmpty) {
      throw StateError('Authenticated user has no phone number.');
    }

    await _client.from('customer_profiles').upsert({
      'id': user.id,
      'phone': phone,
      'full_name': fullName.trim(),
      'city': city,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id');
  }
}
