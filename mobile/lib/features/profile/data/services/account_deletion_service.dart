import 'package:supabase_flutter/supabase_flutter.dart';

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AccountDeletionService {
  AccountDeletionService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<void> deleteAccount() async {
    try {
      final response = await _supabase.functions.invoke('delete-account');

      if (response.status < 200 || response.status >= 300) {
        final data = response.data;

        final message = data is Map<String, dynamic> ? data['message'] as String? : null;

        throw AccountDeletionException(
          message ?? 'We could not delete your account. Please try again.',
        );
      }
      await _supabase.auth.signOut(scope: SignOutScope.local);
    } on FunctionException catch (error) {
      throw AccountDeletionException(
        error.details?.toString() ?? 'We could not delete your account. Please try again.',
      );
    } catch (error) {
      if (error is AccountDeletionException) {
        rethrow;
      }

      throw const AccountDeletionException('We could not delete your account. Please try again.');
    }
  }
}
