import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FcmService {
  final _messaging = FirebaseMessaging.instance;
  final _firestore = FirebaseFirestore.instance;

  /// Request notification permission and save FCM token to Firestore.
  Future<void> init(String userId) async {
    // Request permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get and save token
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(userId, token);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _saveToken(userId, newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      // Already handled by NotificationListener via Firestore
      // This is for FCM-specific payloads if needed later
    });
  }

  Future<void> _saveToken(String userId, String token) async {
    await _firestore.collection('users').doc(userId).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
  }

  /// Remove token on sign out.
  Future<void> removeToken(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'fcmToken': FieldValue.delete(),
    });
  }
}
