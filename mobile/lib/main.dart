import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';
import 'core/services/push_notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final fcmToken = await FirebaseMessaging.instance.getToken();

  final notificationSettings = await FirebaseMessaging.instance
      .requestPermission();

  debugPrint(
    'Notification permission: ${notificationSettings.authorizationStatus}',
  );

  debugPrint('FCM token: $fcmToken');

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(const GetSetWellApp());

  final pushNotificationService = PushNotificationService();

  pushNotificationService.listenForTokenRefresh();

  try {
    await pushNotificationService.registerCurrentDevice();
  } catch (error, stackTrace) {
    debugPrint('Push token registration failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
