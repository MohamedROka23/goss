import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'backend_manager.dart';

/// Firebase Cloud Messaging helper.
///
/// Registers the device token against a stable identity:
///  - customers use the persistent identity from [BackendManager.customerId]
///    (Firebase anonymous uid in cloud mode, a random uuid locally)
///  - admins use their Firebase auth uid
/// and shows local notifications for messages received in the foreground
/// (background messages are shown by the OS notification tray).
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _local = FlutterLocalNotificationsPlugin();
  bool _initializing = false;

  String? _token;
  String? get token => _token;

  /// The identity used for this device/customer (see [BackendManager.customerId]).
  Future<String> customerId() => BackendManager.customerId();

  Future<void> init() async {
    if (_initializing) return;
    _initializing = true;
    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      FirebaseMessaging.onMessage.listen(_handleForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened);
      messaging.onTokenRefresh.listen(_onTokenRefresh);

      await _registerToken();
    } catch (_) {
      // Push is best-effort; the app keeps working without it.
    } finally {
      _initializing = false;
    }
  }

  Future<void> _registerToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      _token = await messaging.getToken();
      if (_token != null) {
        await _registerCustomerToken();
      }
    } catch (_) {}
  }

  Future<void> _onTokenRefresh(String newToken) async {
    _token = newToken;
    await _registerCustomerToken();
  }

  Future<void> _handleForeground(RemoteMessage message) async {
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    if (title.isEmpty && body.isEmpty) return;
    try {
      await _local.show(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'goss_notifications',
            'GOSST notifications',
            channelDescription: 'Price quote updates and requests',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {}
  }

  void _handleOpened(RemoteMessage message) {}

  Future<void> _registerCustomerToken() async {
    final id = await customerId();
    await FirebaseFirestore.instance
        .collection('customer_tokens')
        .doc(id)
        .set({
      'token': _token!,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Registers (or refreshes) the admin device token under the uid.
  Future<void> registerAdminToken(String uid, String token) async {
    if (token.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('admin_tokens')
          .doc(uid)
          .set({
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Called when an admin signs in; stores that identity's token.
  Future<void> onAdminLoggedIn(String uid) async {
    if (_token == null && _initializing) {
      // init still in progress; wait briefly for it to finish
      for (var i = 0; i < 50 && _initializing; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    try {
      if (_token == null) await _registerToken();
    } catch (_) {}
    final t = _token;
    if (t != null && t.isNotEmpty) {
      await registerAdminToken(uid, t);
    }
  }

  /// No-op for admin logout; the token doc is left (re-registered on next login).
  void forgetLoggedInAdmin() {}
}