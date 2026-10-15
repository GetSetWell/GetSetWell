import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'customer_identity_service.dart';

class PushNotificationService {
  PushNotificationService({FirebaseMessaging? messaging, SupabaseClient? supabase})
    : _messaging = messaging ?? FirebaseMessaging.instance,
      _supabase = supabase ?? Supabase.instance.client;

  final FirebaseMessaging _messaging;
  final SupabaseClient _supabase;

  static void Function(Map<String, dynamic>)? onNotificationTap;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _notificationChannel = AndroidNotificationChannel(
    'getsetwell_important_notifications',
    'GetSetWell Notifications',
    description: 'Trainer matches, bookings and session updates.',
    importance: Importance.high,
    playSound: true,
  );

  static Future<void>? _foregroundInitialization;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<String>? _tokenRefreshSubscription;

  static bool get _supportsMobilePush => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Initialise Android foreground notification banners once.
  Future<void> initializeForegroundNotifications() {
    if (kIsWeb || !Platform.isAndroid) return Future.value();

    return _foregroundInitialization ??= _initializeForegroundNotifications().catchError((
      Object error,
    ) {
      _foregroundInitialization = null;
      debugPrint('Foreground notification setup failed: $error');
    });
  }

  Future<void> _initializeForegroundNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;

        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            onNotificationTap?.call(decoded);
          }
        } catch (error) {
          debugPrint('Notification tap payload error: $error');
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_notificationChannel);

    _foregroundSubscription ??= FirebaseMessaging.onMessage.listen((message) async {
      try {
        await _showForegroundNotification(message);
      } catch (error) {
        debugPrint('Foreground notification failed: $error');
      }
    });

    debugPrint('Foreground notifications initialised');
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (FirebaseAuth.instance.currentUser == null) return;

    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title ?? 'GetSetWell';
    final body = notification.body ?? '';
    final identifier =
        message.messageId ??
        message.data['notification_id']?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final notificationId = identifier.hashCode & 0x7fffffff;

    const androidDetails = AndroidNotificationDetails(
      'getsetwell_important_notifications',
      'GetSetWell Notifications',
      channelDescription: 'Trainer matches, bookings and session updates.',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: jsonEncode(message.data),
    );

    debugPrint('Foreground notification displayed');
  }

  /// Set once the system prompt has been shown on Android in this app
  /// launch, so the person is never asked repeatedly in one session.
  static bool _androidPermissionRequestedThisLaunch = false;

  /// Whether the system notification prompt should be shown now.
  ///
  /// On iOS this is only true while the person has never been asked. On
  /// Android firebase_messaging reports `denied` before the person was ever
  /// asked (Android 13+), so ask whenever notifications are not enabled, at
  /// most once per app launch.
  Future<bool> shouldRequestPermission() async {
    if (!_supportsMobilePush) return false;

    final current = await _messaging.getNotificationSettings();

    if (Platform.isIOS) {
      return current.authorizationStatus == AuthorizationStatus.notDetermined;
    }

    if (_androidPermissionRequestedThisLaunch) return false;
    if (current.authorizationStatus == AuthorizationStatus.authorized) return false;

    bool? enabled;
    try {
      enabled = await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
    } catch (error) {
      debugPrint('Notification enabled check failed: $error');
    }

    return enabled != true;
  }

  /// Shows the system notification prompt and returns the resulting settings.
  Future<NotificationSettings> requestPermission() {
    if (!kIsWeb && Platform.isAndroid) {
      _androidPermissionRequestedThisLaunch = true;
    }

    return _messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  /// Asks for notification permission when [shouldRequestPermission] allows
  /// it, so it is safe to call on every sign-in. Without this, iPhone and
  /// Android 13+ users who skip Help me choose would never receive match,
  /// booking or reminder notifications.
  Future<void> requestPermissionIfNeeded() async {
    if (!_supportsMobilePush) return;

    try {
      if (!await shouldRequestPermission()) return;

      await requestPermission();
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
    }
  }

  /// On iOS, show notification banners while the app is in the foreground.
  /// Android foreground banners are handled by [initializeForegroundNotifications].
  Future<void> configureForegroundPresentation() async {
    if (kIsWeb || !Platform.isIOS) return;

    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (error) {
      debugPrint('Foreground presentation setup failed: $error');
    }
  }

  /// Register this device only for the Firebase user who started the request.
  Future<void> registerCurrentDevice() async {
    if (!_supportsMobilePush) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await initializeForegroundNotifications();

      // On iOS the APNs token must be ready before requesting the FCM token.
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null || apnsToken.isEmpty) {
          debugPrint('Push registration deferred: APNs token is not ready');
          return;
        }
      }

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;

      if (FirebaseAuth.instance.currentUser?.uid != uid) return;

      await _saveToken(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
        expectedUid: uid,
      );
      debugPrint('Push token saved successfully');
    } catch (error) {
      // Push registration must not prevent login or application startup.
      debugPrint('Push token registration failed: $error');
    }
  }

  /// Remove only this device's token for the user signing out.
  Future<void> deleteCurrentDeviceToken() async {
    if (!_supportsMobilePush) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;

      if (FirebaseAuth.instance.currentUser?.uid != uid) return;

      final customerId = await CustomerIdentityService().getCustomerId();
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;

      await _supabase
          .from('device_push_tokens')
          .delete()
          .eq('user_id', customerId)
          .eq('token', token);

      debugPrint('Push token deleted successfully');
    } catch (error) {
      // Preserve existing best-effort logout behaviour.
      debugPrint('Push token delete failed: $error');
    }
  }

  /// Track FCM token rotation with one listener for the app lifetime.
  void listenForTokenRefresh() {
    if (!_supportsMobilePush || _tokenRefreshSubscription != null) return;

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      if (token.isEmpty) return;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      try {
        await _saveToken(
          token: token,
          platform: Platform.isIOS ? 'ios' : 'android',
          expectedUid: uid,
        );
        debugPrint('Push token refresh saved successfully');
      } catch (error) {
        debugPrint('Push token refresh save failed: $error');
      }
    });
  }

  /// Preserve the existing Supabase RPC. Never submit for a different user.
  Future<void> _saveToken({
    required String token,
    required String platform,
    required String expectedUid,
  }) async {
    if (FirebaseAuth.instance.currentUser?.uid != expectedUid) return;

    await _supabase.rpc(
      'claim_device_push_token',
      params: {'p_token': token, 'p_platform': platform},
    );
  }
}
