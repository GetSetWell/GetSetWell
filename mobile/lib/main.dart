import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';
import 'core/services/push_notification_service.dart';
import 'features/splash/presentation/startup_error_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _start();
}

bool _firebaseReady = false;
bool _supabaseReady = false;

/// Initialises Firebase and Supabase, then runs the app. Any failure shows a
/// branded error screen with a retry instead of a blank window.
Future<void> _start() async {
  try {
    if (SupabaseConfig.url.isEmpty || SupabaseConfig.publishableKey.isEmpty) {
      throw StateError('Supabase configuration is missing.');
    }

    if (!_firebaseReady) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      _firebaseReady = true;
    }

    if (!_supabaseReady) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        accessToken: () async {
          return FirebaseAuth.instance.currentUser?.getIdToken();
        },
      );
      _supabaseReady = true;
    }
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('App startup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    runApp(StartupErrorApp(onRetry: _start));

    return;
  }

  runApp(const GetSetWellApp());

  unawaited(_registerPush());
}

Future<void> _registerPush() async {
  final pushNotificationService = PushNotificationService();

  pushNotificationService.listenForTokenRefresh();

  await pushNotificationService.configureForegroundPresentation();

  try {
    await pushNotificationService.registerCurrentDevice();
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Push token registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
