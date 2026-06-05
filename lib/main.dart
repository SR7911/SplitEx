import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/app.dart';
import 'package:split_ex/services/fcm_service.dart';
import 'package:split_ex/services/notification_listener.dart' as nl;
import 'package:split_ex/services/notification_service.dart';

/// Background message handler (must be top-level function).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Enable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Init local notifications
  final notificationService = NotificationService();
  await notificationService.init();

  // Setup FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permission (non-blocking)
  try {
    await _requestNotificationPermission();
  } catch (_) {}

  // Init FCM and notification listener for authenticated user
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
    FcmService().init(user.uid).catchError((_) {});
    nl.NotificationListener(
      notificationService: notificationService,
      userId: user.uid,
    ).startListening();
  }

  runApp(const ProviderScope(child: SplitExApp()));
}

Future<void> _requestNotificationPermission() async {
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  final flnPlugin = FlutterLocalNotificationsPlugin();
  final androidPlugin = flnPlugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.requestNotificationsPermission();
}
