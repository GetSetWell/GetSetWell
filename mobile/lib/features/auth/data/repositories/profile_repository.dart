import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  ProfileRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String?> _getCustomerId() async {
    if (FirebaseAuth.instance.currentUser == null) {
      return null;
    }

    final id = await _client.rpc('current_customer_id');

    return id?.toString();
  }

  Future<bool> hasCompletedProfile() async {
    final customerId = await _getCustomerId();

    if (customerId == null) {
      return false;
    }

    final profile = await _client
        .from('customer_profiles')
        .select('full_name, city')
        .eq('id', customerId)
        .maybeSingle();

    if (profile == null) {
      return false;
    }

    final fullName = profile['full_name']?.toString().trim() ?? '';

    final city = profile['city']?.toString().trim() ?? '';

    return fullName.isNotEmpty && city.isNotEmpty;
  }

  Future<void> saveBasicProfile({required String fullName, required String city}) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      throw StateError('Cannot save profile without an authenticated user.');
    }

    final customerId = await _getCustomerId();

    if (customerId == null) {
      throw StateError('Firebase customer identity has not been created.');
    }

    final phone = firebaseUser.phoneNumber;

    if (phone == null || phone.trim().isEmpty) {
      throw StateError('Authenticated user has no phone number.');
    }

    await _client.from('customer_profiles').upsert({
      'id': customerId,
      'phone': phone,
      'full_name': fullName.trim(),
      'city': city,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id');
  }
}
