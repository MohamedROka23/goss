import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'backend_manager.dart';
import 'notification_watcher.dart';

/// Renders a push in the BACKGROUND isolate. FCM hands data-only messages to
/// this handler when the app is backgrounded/terminated; from here we pop a
/// local notification (same channel as the in-app watcher for a consistent UI).
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  try {
    await FcmService.instance.showLocalForData(message.data);
  } catch (_) {
    // Background push is best-effort; never crash the engine for it.
  }
}

/// Firebase Cloud Messaging helper.
///
/// Registers the device token against a stable identity:
///  - customers use the persistent identity from [BackendManager.customerId]
///    (Firebase anonymous uid in cloud mode, a random uuid locally)
///  - admins use their Firebase auth uid
///
/// and renders pushes on the device. In-app events are additionally surfaced by
/// [NotificationWatcher] so notifications pop even without FCM credentials.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _local = FlutterLocalNotificationsPlugin();
  bool _initializing = false;

  /// Invoked when the user taps a notification (local or FCM) -> deep link.
  void Function(Map<String, String> data)? onOpen;

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
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (resp) => _route(resp.payload),
      );

      // Android 13+ needs an explicit runtime POST_NOTIFICATIONS grant.
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);

      FirebaseMessaging.onMessage.listen(_handleForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened);
      messaging.onTokenRefresh.listen(_onTokenRefresh);

      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleOpened(initial);

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

  /// Foreground messages: the in-app [NotificationWatcher] already pops
  /// notifications for the app's own events, so data-only pushes for covered
  /// types are skipped here to avoid double pops. Legacy notification-block
  /// messages (price updates ...) are still shown.
  Future<void> _handleForeground(RemoteMessage message) async {
    final data = message.data;
    if (NotificationWatcher.instance.active && data.containsKey('type')) {
      return;
    }
    if (data.containsKey('type')) {
      await showLocalForData(data);
      return;
    }
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    if (title.isEmpty && body.isEmpty) return;
    await showLocal(title: title, body: body);
  }

  void _handleOpened(RemoteMessage message) {
    final data = Map<String, String>.from(message.data);
    if (data.isNotEmpty) _run(data['type'] ?? '', data);
  }

  void _route(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final Map<String, String> data;
    try {
      data = Uri.splitQueryString(payload);
    } catch (_) {
      return;
    }
    if (data.isEmpty) return;
    _run(data['type'] ?? '', data);
  }

  void _run(String type, Map<String, String> data) {
    if (type.isEmpty || onOpen == null) return;
    try {
      onOpen?.call(data);
    } catch (_) {
      // Navigation is best-effort.
    }
  }

  /// Shows a local "pop" notification (bilingual). [payload] carries the
  /// navigation data for when the user taps it.
  Future<void> showLocal({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _local.show(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'goss_notifications',
            'GOSST notifications',
            channelDescription: 'Requests, tracking and support chat',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

  /// Renders an FCM data-only push (semantic fields, localized on the device).
  Future<void> showLocalForData(Map<String, dynamic> data) async {
    final type = data['type'] as String? ?? '';
    final (String title, String body) = _renderForData(type, data);
    if (body.isEmpty && title.isEmpty) return;
    await showLocal(
      title: title,
      body: body,
      payload: Uri(
        queryParameters: data.map((k, v) => MapEntry(k, v.toString())),
      ).query,
    );
  }

  static (String, String) _renderForData(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'chat_request':
        return (
          'GOSST — محادثة الدعم / Support chat',
          'طلب محادثة جديد بانتظار الموافقة. / New chat request.',
        );
      case 'chat':
        final admin = (data['senderRole'] == 'admin');
        return (
          'GOSST — محادثة الدعم / Support chat',
          admin
              ? 'رسالة جديدة من فريق الدعم. / New message from the support team.'
              : 'رسالة جديدة من العميل. / New message from a customer.',
        );
      case 'request_status':
        return (
          'GOSST — تتبع طلبك / Order status',
          'تم تحديث حالة طلبك. / Your order status has changed.',
        );
      default:
        return (
          data['title'] as String? ?? '',
          data['body'] as String? ?? '',
        );
    }
  }

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