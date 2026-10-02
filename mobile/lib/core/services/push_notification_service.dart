import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  PushNotificationService({FirebaseMessaging? messaging, SupabaseClient? supabase})
    : _messaging = messaging ?? FirebaseMessaging.instance,
      _supabase = supabase ?? Supabase.instance.client;

  final FirebaseMessaging _messaging;
  final SupabaseClient _supabase;

  Future<void> registerCurrentDevice() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return;
    }
    debugPrint('Push user: ${user.id}');

    final token = await _messaging.getToken();
    debugPrint('Push FCM token: $token');

    if (token == null || token.isEmpty) {
      return;
    }

    final platform = Platform.isIOS ? 'ios' : 'android';

    try {
      await _supabase.from('device_push_tokens').upsert({
        'user_id': user.id,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');

      debugPrint('Push token saved successfully');
    } catch (error) {
      debugPrint('Push token save failed: $error');
    }
  }

  Future<void> deleteCurrentDeviceToken() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    final token = await _messaging.getToken();

    if (token == null || token.isEmpty) {
      return;
    }

    await _supabase.from('device_push_tokens').delete().eq('user_id', user.id).eq('token', token);
  }

  void listenForTokenRefresh() {
    _messaging.onTokenRefresh.listen((token) async {
      final user = _supabase.auth.currentUser;

      if (user == null || token.isEmpty) {
        return;
      }

      final platform = Platform.isIOS ? 'ios' : 'android';

      try {
        await _supabase.from('device_push_tokens').upsert({
          'user_id': user.id,
          'token': token,
          'platform': platform,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'token');
      } catch (error) {
        debugPrint('Push token refresh save failed: $error');
      }
    });
  }
}
