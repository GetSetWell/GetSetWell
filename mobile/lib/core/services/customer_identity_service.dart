import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerIdentityService {
  CustomerIdentityService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> getCustomerId() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      throw StateError('Customer is not authenticated.');
    }

    final result = await _client.rpc('current_customer_id');
    final customerId = result?.toString();

    if (customerId == null || customerId.isEmpty) {
      throw StateError('Customer identity is not initialised in Supabase.');
    }

    return customerId;
  }

  Future<String> ensureCustomerIdentity() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      throw StateError('Customer is not authenticated.');
    }

    // Refresh the token to obtain the latest custom role claim.
    await firebaseUser.getIdToken(true);

    final result = await _client.rpc('ensure_customer_identity');
    final customerId = result?.toString();

    if (customerId == null || customerId.isEmpty) {
      throw StateError('Failed to initialise customer identity.');
    }

    return customerId;
  }
}
