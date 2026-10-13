import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
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

  static const String _supportEmail = 'info@getsetwell.com';

  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AccountDeletionException(
        'Please sign in before requesting account deletion.',
      );
    }

    final String token;
    try {
      final idToken = await user.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Firebase returned an empty ID token.');
      }
      token = idToken;
    } catch (_) {
      throw const AccountDeletionException(
        'We could not confirm your sign-in. Please sign in again.',
      );
    }

    final FunctionResponse response;
    try {
      response = await _supabase.functions.invoke(
        'delete-account',
        headers: {'Authorization': 'Bearer $token'},
      );
    } on FunctionException catch (error) {
      final details = _responseMap(error.details);
      await _handleFailure(details);
      return;
    } catch (_) {
      // The request might have reached the server. Never blindly retry an
      // irreversible operation when the response was lost.
      throw const AccountDeletionException(
        'We could not confirm your account deletion. Please contact '
        '$_supportEmail before trying again.',
      );
    }

    final data = _responseMap(response.data);
    if (response.status < 200 || response.status >= 300) {
      await _handleFailure(data);
      return;
    }

    if (data['firebaseAccountDeleted'] == true) {
      await _signOutAfterAccountClosure();
      if (data['success'] == true) {
        // A 202 response confirms login deletion, not full data erasure.
        return;
      }
      throw const AccountDeletionException(
        'Your login has been deleted, but account cleanup needs support. '
        'Please contact $_supportEmail.',
      );
    }

    // Never sign out or report success on an incomplete/unknown response.
    throw const AccountDeletionException(
      'We could not confirm your account deletion. Please contact '
      '$_supportEmail before trying again.',
    );
  }

  Future<void> _handleFailure(Map<String, dynamic> data) async {
    final code = data['code']?.toString();

    if (data['firebaseAccountDeleted'] == true) {
      await _signOutAfterAccountClosure();
      throw const AccountDeletionException(
        'Your login has been deleted, but account cleanup needs support. '
        'Please contact $_supportEmail.',
      );
    }

    switch (code) {
      case 'upcoming_session':
        throw const AccountDeletionException(
          'You cannot delete your account while you have an upcoming session.',
        );
      case 'recent_login_required':
        throw const AccountDeletionException(
          'Please sign in again before deleting your account.',
        );
      case 'auth_required':
        throw const AccountDeletionException(
          'Your sign-in could not be confirmed. Please sign in again.',
        );
      case 'deletion_status_unknown':
      case 'restore_failed':
        // The Firebase-to-customer mapping may be detached. Sign out to avoid
        // continuing with an identity that the backend no longer recognises.
        await _signOutAfterAccountClosure();
        throw const AccountDeletionException(
          'Your account deletion needs a review. Please contact '
          '$_supportEmail before trying again.',
        );
      case 'partial_deletion':
        // An older or unexpected backend response may omit the deletion flag.
        // Treat the outcome as uncertain and require support review.
        throw const AccountDeletionException(
          'Your account deletion needs a review. Please contact '
          '$_supportEmail before trying again.',
        );
      case 'deletion_already_tracked':
      case 'deletion_requires_review':
        throw const AccountDeletionException(
          'Your account deletion needs a review. Please contact '
          '$_supportEmail before trying again.',
        );
      default:
        throw const AccountDeletionException(
          'We could not confirm your account deletion. Please contact '
          '$_supportEmail before trying again.',
        );
    }
  }

  Future<void> _signOutAfterAccountClosure() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      throw const AccountDeletionException(
        'Your login deletion was processed, but this device could not sign out '
        'automatically. Please restart the app and contact $_supportEmail.',
      );
    }
  }

  static Map<String, dynamic> _responseMap(dynamic value) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map((key, item) => MapEntry(key.toString(), item));
        }
      } catch (_) {
        // Never display raw server error bodies to customers.
      }
    }
    return <String, dynamic>{};
  }
}
