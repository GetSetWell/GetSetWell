import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/routing/gsw_router.dart';
import '../core/routing/gsw_routes.dart';
import '../core/services/push_notification_service.dart';
import '../core/theme/gsw_theme.dart';

class GetSetWellApp extends StatefulWidget {
  const GetSetWellApp({super.key});

  @override
  State<GetSetWellApp> createState() => _GetSetWellAppState();
}

class _GetSetWellAppState extends State<GetSetWellApp> {
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<firebase_auth.User?>? _authSubscription;
  Map<String, dynamic>? _pendingNotification;
  bool _navigationScheduled = false;

  @override
  void initState() {
    super.initState();

    // Register foreground local notification tap handling.
    PushNotificationService.onNotificationTap = _queueNotification;

    // Firebase notification tapped while app is backgrounded.
    _messageSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _queueNotification(message.data),
    );

    // Retry pending navigation when authentication changes.
    _authSubscription = firebase_auth.FirebaseAuth.instance.authStateChanges().listen(
      (_) => _scheduleNavigation(),
    );

    // Wait for the splash/router to finish initial navigation.
    gswRouter.routeInformationProvider.addListener(_scheduleNavigation);

    // Check both Firebase and local notification cold starts.
    unawaited(_checkInitialNotification());
  }

  Future<void> _checkInitialNotification() async {
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();

      if (message != null) {
        _queueNotification(message.data);
        return;
      }

      final localNotifications = FlutterLocalNotificationsPlugin();

      final details = await localNotifications.getNotificationAppLaunchDetails();

      if (details?.didNotificationLaunchApp != true) return;

      final payload = details?.notificationResponse?.payload;

      if (payload == null || payload.isEmpty) return;

      final decoded = jsonDecode(payload);

      if (decoded is Map<String, dynamic>) {
        _queueNotification(decoded);
      }
    } catch (error) {
      debugPrint('Initial notification handling failed: $error');
    }
  }

  void _queueNotification(Map<String, dynamic> data) {
    if (!mounted) return;

    _pendingNotification = Map<String, dynamic>.from(data);
    _scheduleNavigation();
  }

  void _scheduleNavigation() {
    if (!mounted || _navigationScheduled) return;

    _navigationScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationScheduled = false;
      if (!mounted) return;
      _openPendingNotification();
    });
  }

  void _openPendingNotification() {
    final data = _pendingNotification;
    if (data == null) return;

    // Never bypass authentication.
    if (firebase_auth.FirebaseAuth.instance.currentUser == null) {
      return;
    }

    final currentPath = gswRouter.routeInformationProvider.value.uri.path;

    // Let the existing splash and authentication flow finish.
    const blockedRoutes = [
      GSWRoutes.splash,
      GSWRoutes.onboarding,
      GSWRoutes.userAuth,
      GSWRoutes.userAuthOtp,
      GSWRoutes.userDetails,
    ];

    if (blockedRoutes.contains(currentPath)) {
      return;
    }

    final type = data['type']?.toString();
    final bookingId = data['booking_request_id']?.toString();
    final sessionId = data['session_id']?.toString();

    _pendingNotification = null;

    if (type == 'trainer_match' && bookingId != null && bookingId.isNotEmpty) {
      gswRouter.push(GSWRoutes.matchedTrainer, extra: bookingId);
      return;
    }

    final sessionNotificationTypes = {
      'booking_confirmed',
      'booking_cancelled',
      'booking_rescheduled',
      'session_reminder',
      'session_feedback',
    };

    if (sessionNotificationTypes.contains(type) && sessionId != null && sessionId.isNotEmpty) {
      gswRouter.push(
        GSWRoutes.sessionDetails,
        extra: type == 'session_feedback'
            ? {'sessionId': sessionId, 'openFeedback': true}
            : sessionId,
      );
      return;
    }

    // Safe destination for other notification types until
    // their detail navigation has been implemented.
    gswRouter.push(GSWRoutes.notifications);
  }

  @override
  void dispose() {
    PushNotificationService.onNotificationTap = null;

    gswRouter.routeInformationProvider.removeListener(_scheduleNavigation);

    _messageSubscription?.cancel();
    _authSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GetSetWell',
      debugShowCheckedModeBanner: false,
      theme: GSWTheme.darkTheme,
      routerConfig: gswRouter,
    );
  }
}
