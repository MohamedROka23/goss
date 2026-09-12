import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_models.dart';
import '../models/models.dart' show requestStatusLabel;
import 'chat_store.dart';
import 'fcm_service.dart';

/// Firestore-driven in-app notification watcher.
///
/// Both apps listen to the collections they are allowed to read and turn every
/// relevant event (new request, order tracking stage change, chat message,
/// conversation approval) into an immediate local "pop" notification. This is
/// what makes notifications work right away, even without FCM credentials
/// (foreground and while the app is backgrounded). When the process is fully
/// terminated the same events are delivered by the push relay on the server and
/// rendered by the FCM background handler in [FcmService].
class NotificationWatcher {
  NotificationWatcher._();

  static final NotificationWatcher instance = NotificationWatcher._();

  final List<StreamSubscription<dynamic>> _subs = [];
  final Map<String, String> _requestStatus = {};
  final Map<String, String> _convStatus = {};
  final Map<String, String> _convLatestMessage = {};
  final Map<String, StreamSubscription<dynamic>> _convMsgSubs = {};

  bool _customerRunning = false;
  bool _adminRunning = false;

  /// Id of the conversation currently open on screen; its events are not
  /// notified because the user is already reading them.
  String? currentConversation;

  bool get active => _customerRunning || _adminRunning;

  static CollectionReference<Map<String, dynamic>> get _requests =>
      FirebaseFirestore.instance.collection('requests');

  static CollectionReference<Map<String, dynamic>> get _convs =>
      FirebaseFirestore.instance.collection('chat_conversations');

  static CollectionReference<Map<String, dynamic>> _msgs(String convId) =>
      _convs.doc(convId).collection('messages');

  // ---- Lifecycle -----------------------------------------------------------

  Future<void> startCustomer() async {
    if (_customerRunning) return;
    if (!_fsUsable()) return;
    String cid;
    try {
      cid = await chatCustomerId();
    } catch (_) {
      return;
    }
    if (cid.isEmpty) return;
    _customerRunning = true;
    _watchRequests(customerId: cid);
    _watchConversations(onlyForUid: cid);
  }

  Future<void> startAdmin(String uid) async {
    if (_adminRunning || uid.isEmpty) return;
    if (!_fsUsable()) return;
    _adminRunning = true;
    _watchRequests(adminUid: uid);
    _watchConversations(adminUid: uid);
  }

  void stopAll() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    for (final s in _convMsgSubs.values) {
      unawaited(s.cancel());
    }
    _convMsgSubs.clear();
    _requestStatus.clear();
    _convStatus.clear();
    _convLatestMessage.clear();
    _customerRunning = false;
    _adminRunning = false;
  }

  bool _fsUsable() {
    try {
      FirebaseFirestore.instance.collection('requests');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---- Requests ------------------------------------------------------------

  void _watchRequests({String? customerId, String? adminUid}) {
    Query<Map<String, dynamic>> q = _requests;
    if (customerId != null) {
      q = q.where('customerId', isEqualTo: customerId);
    } else {
      // "New" orders only interest the team; the customer follows their own.
      q = q.where('status', isEqualTo: 'new');
    }
    _subs.add(q.snapshots().listen((snap) {
      for (final doc in snap.docs) {
        final status = doc['status'] as String? ?? 'new';
        final prev = _requestStatus[doc.id];
        if (prev == null) {
          // First snapshot is the baseline; never notify past events.
          _requestStatus[doc.id] = status;
          continue;
        }
        _requestStatus[doc.id] = status;
        if (prev == status) continue;
        if (customerId != null) {
          if (status == 'new') continue;
          FcmService.instance.showLocal(
            title: 'GOSST — تتبع طلبك / Order status',
            body: '${requestStatusLabel(status, ar: true)} — '
                '${requestStatusLabel(status, ar: false)}',
            payload: _json({
              'type': 'request_status',
              'requestId': doc.id,
            }),
          );
        }
      }
    }, onError: (Object _) {}));
  }

  // ---- Conversations / chat ------------------------------------------------

  void _watchConversations({String? onlyForUid, String? adminUid}) {
    Query<Map<String, dynamic>> q = _convs;
    if (onlyForUid != null) {
      q = q.where('participants', arrayContains: onlyForUid);
    }
    _subs.add(q.snapshots().listen((snap) {
      for (final doc in snap.docs) {
        final status = doc['status'] as String? ?? ChatStatus.pending.raw;
        final prev = _convStatus[doc.id];
        _convStatus[doc.id] = status;
        // Approval: pending -> open.
        if (prev == ChatStatus.pending.raw && status == ChatStatus.open.raw) {
          if (currentConversation != doc.id) {
            FcmService.instance.showLocal(
              title: 'GOSST — محادثة الدعم / Support chat',
              body: 'تمت الموافقة على محادثة الدعم. / Support chat approved.',
              payload: _json({
                'type': 'chat',
                'conversationId': doc.id,
                'senderRole': 'admin',
              }),
            );
          }
        }
        _syncConversationMessages(
          doc.id,
          onlyForUid: onlyForUid,
          adminUid: adminUid,
        );
      }
    }, onError: (Object _) {}));

    if (adminUid != null) {
      // A fresh pending conversation is the customer's chat REQUEST.
      _subs.add(_convs.where('status', isEqualTo: 'pending').snapshots().listen((snap) {
        for (final doc in snap.docs) {
          final prev = _requestStatus[doc.id];
          if (prev != null) continue; // baseline or already notified
          _requestStatus[doc.id] = 'pending';
          if (currentConversation == doc.id) continue;
          FcmService.instance.showLocal(
            title: 'GOSST — محادثة الدعم / Support chat',
            body: 'طلب محادثة جديد بانتظار الموافقة. / New chat request.',
            payload: _json({
              'type': 'chat_request',
              'conversationId': doc.id,
              'senderRole': 'customer',
            }),
          );
        }
      }, onError: (Object _) {}));
    }
  }

  void _syncConversationMessages(
    String convId, {
    String? onlyForUid,
    String? adminUid,
  }) {
    if (_convMsgSubs.containsKey(convId)) return;
    // Bound the number of live message listeners on a team device.
    if (adminUid != null && _convMsgSubs.length >= 25) return;
    final sub = _msgs(convId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isEmpty) return;
      final doc = snap.docs.first;
      final senderRole = doc['senderRole'] as String? ?? '';
      final senderUid = doc['senderUid'] as String? ?? '';
      final prev = _convLatestMessage[convId];
      if (prev == doc.id) return;
      _convLatestMessage[convId] = doc.id;
      if (currentConversation == convId) return;
      // Never notify a device about its own outbound message.
      if (adminUid != null && senderUid == adminUid) return;
      if (onlyForUid != null && senderRole == 'customer') return;
      if (onlyForUid != null && senderRole != 'admin') return;
      FcmService.instance.showLocal(
        title: 'GOSST — محادثة الدعم / Support chat',
        body: senderRole == 'admin'
            ? 'رسالة جديدة من فريق الدعم. / New message from the support team.'
            : 'رسالة جديدة من العميل. / New message from a customer.',
        payload: _json({
          'type': 'chat',
          'conversationId': convId,
          'senderRole': senderRole,
        }),
      );
    }, onError: (Object _) {});
    _convMsgSubs[convId] = sub;
  }

  static String _json(Map<String, dynamic> data) =>
      Uri(queryParameters: data.map((k, v) => MapEntry(k, v.toString()))).query;
}