import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_models.dart';
import '../security/app_security.dart';
import '../security/sensitive.dart';
import 'backend_manager.dart';
import 'chat_crypto.dart';
import 'chat_images.dart';

/// Firestore persistence + E2E orchestration for the support chat.
///
/// Roles:
///  - **Customer** ("طلب محادثة"): the customer opens the chat list, taps
///    "اطلب محادثة", a `pending` conversation is created. The conversation key
///    is wrapped to the customer device plus every enrolled team device.
///  - **Admin (the team)**: any member with the `chat` permission sees the
///    requests in a unified inbox, accepts (`pending` -> `open`) and replies.
///    Photos sent from the camera are compressed and encrypted with the same
///    conversation key before upload.
class ChatStore {
  ChatStore._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _convs =>
      _db.collection('chat_conversations');

  static CollectionReference<Map<String, dynamic>> _msgs(String convId) =>
      _convs.doc(convId).collection('messages');

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// ---- Key enrollment ----------------------------------------------------

  /// Publishes (or refreshes) the customer device public key. Idempotent;
  /// call it when the user opens the chat tab.
  static Future<void> ensureCustomerKey() async {
    try {
      final uid = _uid;
      if (uid.isEmpty) return;
      final pub = await ChatCrypto.myPublicKeyB64();
      await _db.collection('chat_public_keys').doc(uid).set({
        'publicB64': pub,
        'keyId': ChatCrypto.keyIdOf(pub),
        'role': 'customer',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Publishes (or refreshes) the team device public key. Called when the
  /// admin inbox opens so the device can decrypt the conversations it owns.
  static Future<void> ensureStaffKey() async {
    try {
      final uid = _uid;
      if (uid.isEmpty) return;
      final pub = await ChatCrypto.myPublicKeyB64();
      await _db.collection('chat_staff_keys').doc(uid).set({
        'publicB64': pub,
        'keyId': ChatCrypto.keyIdOf(pub),
        'role': 'staff',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// All enrolled team devices (public keys). Used to wrap new conversations.
  static Future<List<Map<String, String>>> staffKeys() async {
    try {
      final snap = await _db.collection('chat_staff_keys').get();
      final out = <Map<String, String>>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final pub = d['publicB64']?.toString() ?? '';
        if (pub.isEmpty) continue;
        out.add({
          'uid': doc.id,
          'keyId': d['keyId']?.toString() ?? ChatCrypto.keyIdOf(pub),
          'publicB64': pub,
        });
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// ---- Customer: request a conversation -----------------------------------

  /// Result of asking for a chat; [failure] is non-null when it cannot start.
  static ({String? conversationId, String? failure}) startChatResult({
    String? conversationId,
    String? failure,
  }) => (conversationId: conversationId, failure: failure);

  /// Creates a `pending` request. Returns the new conversation id, or a
  /// human-readable failure when no support device is enrolled yet.
  static Future<({String? conversationId, String? failure})> createRequest({
    required String customerId,
    required String customerName,
  }) async {
    final staff = await staffKeys();
    if (staff.isEmpty) {
      return startChatResult(
        failure: 'لا يوجد فريق دعم متاح حاليًا، حاول لاحقًا',
      );
    }
    // Random conversation key, sealed with ECDH for every team device.
    final convKey = ChatCrypto.newConversationKey();
    final ref = _convs.doc();
    final sealed = await ChatCrypto.sealConversationKey(
      conversationId: ref.id,
      convKeyB64: convKey,
      recipientsPublicB64: [
        for (final s in staff)
          if ((s['publicB64'] ?? '').isNotEmpty) s['publicB64']!,
      ],
    );

    final participants = <String>{customerId};
    for (final s in staff) {
      participants.add(s['uid']!);
    }

    try {
      await ref.set({
        'customerId': customerId,
        'customerName': customerName,
        'participants': participants.toList(),
        'ephPubB64': sealed.ephPubB64,
        'wrappedKeys': sealed.sealed,
        'wrapNonces': sealed.nonces,
        'wrapMacs': sealed.macs,
        'cryptoVersion': ChatCrypto.cryptoVersion,
        'status': 'pending',
        'lastSender': customerId,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await ChatCrypto.stashConversationKey(ref.id, convKey);
      return startChatResult(conversationId: ref.id);
    } catch (_) {
      return startChatResult(failure: 'تعذّر إرسال الطلب، حاول مرة أخرى');
    }
  }

  /// Opens the conversation key for the TEAM device: the sealed box was
  /// addressed to this device's public key at creation time. null when the
  /// device joined after the conversation was created.
  static Future<String?> openConversationKeyForTeam(ChatConversation c) async {
    if (c.ephPubB64.isEmpty) return null;
    final myKeyId = await ChatCrypto.myKeyId();
    final ct = c.wrappedKeys[myKeyId];
    final nonce = c.wrapNonces[myKeyId];
    final mac = c.wrapMacs[myKeyId];
    if (ct == null || nonce == null || mac == null) return null;
    return ChatCrypto.unwrapConversationKey(
      c.id,
      ephPubB64: c.ephPubB64,
      sealedB64: ct,
      nonceB64: nonce,
      macB64: mac,
    );
  }

  /// Opens the conversation key for the customer device (local vault stash).
  static Future<String?> openConversationKeyForCustomer(ChatConversation c) =>
      ChatCrypto.unwrapConversationKey(c.id);

  /// ---- Admin: approve / close ----------------------------------------------

  /// Sets the conversation lifecycle status. Returns a human-readable failure
  /// message (null on success). The team updates only the status field; the
  /// sealed key boxes and the customer identity are immutable on Firestore.
  static Future<String?> setStatus(
    String conversationId,
    ChatStatus status,
  ) async {
    try {
      await _convs.doc(conversationId).update({'status': status.raw});
      return null;
    } catch (e) {
      debugPrint('ChatStore.setStatus($conversationId) failed: $e');
      return 'تعذّرت العملية، تأكد من اتصالك ثم حاول مجددًا';
    }
  }

  static Future<String?> approve(String conversationId) =>
      setStatus(conversationId, ChatStatus.open);

  static Future<String?> close(String conversationId) =>
      setStatus(conversationId, ChatStatus.closed);

  /// Permanently deletes a conversation and every message under it
  /// (team only, enforced by the Firestore delete rule). Returns a readable
  /// failure message, or null on success.
  static Future<String?> deleteConversation(String conversationId) async {
    try {
      final msgs = await _msgs(conversationId).get();
      for (final d in msgs.docs) {
        await d.reference.delete();
      }
      await _convs.doc(conversationId).delete();
      return null;
    } catch (e) {
      debugPrint('ChatStore.deleteConversation($conversationId) failed: $e');
      return 'تعذّر حذف المحادثة، تحقق من اتصالك وحاول مجددًا';
    }
  }

  /// ---- Streams -------------------------------------------------------------

  /// Streams conversations. The team passes no uid (unified inbox: Firestore
  /// rules already scope reads to admins); a customer passes their own uid so
  /// they only see what they participate in.
  static Stream<List<ChatConversation>> conversations({String? onlyForUid}) {
    final Stream<QuerySnapshot<Map<String, dynamic>>> snap;
    if (onlyForUid == null || onlyForUid.isEmpty) {
      snap = _convs.snapshots();
    } else {
      snap = _convs
          .where('participants', arrayContains: onlyForUid)
          .snapshots();
    }
    return snap.map((s) {
      final list = [for (final d in s.docs) ChatConversation.fromDoc(d)]
        ..sort((a, b) {
          final at =
              (a.lastMessageAt ??
                      a.createdAt ??
                      DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                    b.lastMessageAt ??
                        b.createdAt ??
                        DateTime.fromMillisecondsSinceEpoch(0),
                  );
          // Pending requests always float on top for the team.
          if (a.status != b.status) {
            return a.status == ChatStatus.pending
                ? -1
                : (b.status == ChatStatus.pending ? 1 : at);
          }
          return at;
        });
      return list.reversed.toList();
    });
  }

  static Stream<List<ChatMessage>> messages(String conversationId) {
    return _msgs(conversationId)
        .orderBy('createdAt', descending: false)
        .limit(500)
        .snapshots()
        .map((s) => [for (final d in s.docs) ChatMessage.fromDoc(d)]);
  }

  /// Live view of a single conversation so the open screen reflects approval /
  /// closure in real time (the conversation status is never taken from a stale
  /// widget snapshot).
  static Stream<ChatConversation?> conversationStream(String conversationId) {
    return _convs.doc(conversationId).snapshots().map(
          (s) => s.exists ? ChatConversation.fromDoc(s) : null,
        );
  }

  /// ---- Sending ---------------------------------------------------------------

  static Future<String?> sendText({
    required String conversationId,
    required String senderRole,
    required String convKeyB64,
    required String text,
  }) async {
    final safe = AppSecurity.sanitizeText(text);
    if (safe.isEmpty) return null;
    final out = await ChatCrypto.encryptText(convKeyB64, safe);
    try {
      final dref = _msgs(conversationId).doc();
      await dref.set({
        'conversationId': conversationId,
        'senderUid': _uid,
        'senderRole': senderRole,
        'kind': 'text',
        'nonce': out.$1,
        'data': out.$2,
        'mac': out.$3,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _touchLast(conversationId, _uid);
      return null;
    } catch (_) {
      return 'لم تُرسل الرسالة، أعد المحاولة';
    }
  }

  static Future<String?> sendImage({
    required String conversationId,
    required String senderRole,
    required String convKeyB64,
    required List<int> originalBytes,
  }) async {
    final Uint8List payload;
    try {
      payload = await compressForChat(originalBytes);
    } catch (_) {
      return 'تعذّرت معالجة الصورة';
    }
    final out = await ChatCrypto.encryptBytes(convKeyB64, payload);
    SensitiveData.wipeBytes(payload);
    try {
      final dref = _msgs(conversationId).doc();
      await dref.set({
        'conversationId': conversationId,
        'senderUid': _uid,
        'senderRole': senderRole,
        'kind': 'image',
        'nonce': '',
        'data': '',
        'mac': '',
        'mediaNonce': out.$1,
        'mediaData': out.$2,
        'mediaMac': out.$3,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _touchLast(conversationId, _uid);
      return null;
    } catch (_) {
      return 'لم تُرسل الصورة، أعد المحاولة';
    }
  }

  static Future<void> _touchLast(
    String conversationId,
    String senderUid,
  ) async {
    try {
      await _convs.doc(conversationId).update({
        'lastSender': senderUid,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}

/// The customer's device id (used for chat participant scopes). Falls back to
/// the shared persistent id when Firebase wrote it there.
Future<String> chatCustomerId() async {
  try {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return auth.currentUser!.uid;
  } catch (_) {}
  return BackendManager.customerId();
}
