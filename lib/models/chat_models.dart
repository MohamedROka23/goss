import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle of a support chat request:
///  - [pending]: the customer asked for a chat and the admin team has not
///    accepted it yet (this is the "chat request" the team approves).
///  - [open]: approved, both sides can exchange encrypted messages.
///  - [closed]: the team closed the conversation.
enum ChatStatus {
  pending,
  open,
  closed;

  static ChatStatus fromString(String? s) {
    switch (s) {
      case 'open':
        return ChatStatus.open;
      case 'closed':
        return ChatStatus.closed;
      default:
        return ChatStatus.pending;
    }
  }

  String get raw => switch (this) {
        ChatStatus.pending => 'pending',
        ChatStatus.open => 'open',
        ChatStatus.closed => 'closed',
      };
}

/// A support conversation. All message content is stored encrypted; the
/// conversation symmetric key lives only in [wrappedKeys], each entry being the
/// 256-bit key wrapped (RSA-OAEP) to one device's public key. Only devices that
/// hold one of these private keys can decrypt the messages.
class ChatConversation {
  final String id;
  final String customerId;
  final String customerName;

  /// Auth uids allowed to read (the customer + the customer device always;
  /// the team devices are identified by the wrapped-key entries). Kept minimal:
  /// [customerId] plus every uid holding a wrapped key.
  final List<String> participants;

  /// The per-conversation ECDH ephemeral public key (base64 X25519). Used to
  /// derive the AES KEK together with a participant's private key.
  final String ephPubB64;

  /// recipient device-key id -> base64 AES-GCM(KEK, conversation key).
  final Map<String, String> wrappedKeys;

  /// Per-recipient AES-GCM nonce / MAC for the sealed conversation key.
  final Map<String, String> wrapNonces;
  final Map<String, String> wrapMacs;
  final ChatStatus status;
  final DateTime? lastMessageAt;
  final String lastSender;
  final DateTime? createdAt;

  const ChatConversation({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.participants,
    required this.ephPubB64,
    required this.wrappedKeys,
    required this.wrapNonces,
    required this.wrapMacs,
    required this.status,
    required this.lastSender,
    this.lastMessageAt,
    this.createdAt,
  });

  factory ChatConversation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final wrapped = <String, String>{
      for (final e in (data['wrappedKeys'] as Map?)?.entries ?? <MapEntry<String, dynamic>>[])
        e.key: e.value.toString(),
    };
    final nonces = <String, String>{
      for (final e in (data['wrapNonces'] as Map?)?.entries ?? <MapEntry<String, dynamic>>[])
        e.key: e.value.toString(),
    };
    final macs = <String, String>{
      for (final e in (data['wrapMacs'] as Map?)?.entries ?? <MapEntry<String, dynamic>>[])
        e.key: e.value.toString(),
    };
    final participants = <String>[
      for (final p in (data['participants'] as List?) ?? const <dynamic>[])
        p.toString(),
    ];
    return ChatConversation(
      id: doc.id,
      customerId: data['customerId']?.toString() ?? '',
      customerName: data['customerName']?.toString() ?? '',
      participants: participants,
      ephPubB64: data['ephPubB64']?.toString() ?? '',
      wrappedKeys: wrapped,
      wrapNonces: nonces,
      wrapMacs: macs,
      status: ChatStatus.fromString(data['status']?.toString()),
      lastSender: data['lastSender']?.toString() ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get canDecrypt => wrappedKeys.isNotEmpty;
}

/// One encrypted message. The actual bytes are stored in [nonce]/[data]/[mac]
/// (text payload) and, for photos, additionally in [mediaNonce]/[mediaData]/
/// [mediaMac]. Everything is base64 of AES-256-GCM output produced with the
/// conversation key, so plaintext never touches Firestore.
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderUid;
  final String senderRole; // 'customer' | 'admin'
  final String kind; // 'text' | 'image'
  final String nonce;
  final String data;
  final String mac;
  final String mediaNonce;
  final String mediaData;
  final String mediaMac;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUid,
    required this.senderRole,
    required this.kind,
    required this.nonce,
    required this.data,
    required this.mac,
    this.mediaNonce = '',
    this.mediaData = '',
    this.mediaMac = '',
    this.createdAt,
  });

  bool get isImage => kind == 'image' && mediaData.isNotEmpty;

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return ChatMessage(
      id: doc.id,
      conversationId: d['conversationId']?.toString() ?? doc.reference.parent.id,
      senderUid: d['senderUid']?.toString() ?? '',
      senderRole: d['senderRole']?.toString() ?? 'customer',
      kind: d['kind']?.toString() ?? 'text',
      nonce: d['nonce']?.toString() ?? '',
      data: d['data']?.toString() ?? '',
      mac: d['mac']?.toString() ?? '',
      mediaNonce: d['mediaNonce']?.toString() ?? '',
      mediaData: d['mediaData']?.toString() ?? '',
      mediaMac: d['mediaMac']?.toString() ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}