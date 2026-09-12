import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart' as cg;

import 'secure_store.dart';

/// End-to-end encryption for the support chat (شات خدمة العملاء).
///
/// Threat model: Firestore admins, Firebase staff and anyone who can read the
/// database must NOT be able to read a single message. Plaintext exists only
/// inside the two participating devices.
///
/// Design
/// ------
///  * Every device generates one X25519 key pair. The private key lives only in
///    the platform keystore ([SecureStore]); the public key is published
///    (customers: `chat_public_keys/{uid}`, team: `chat_staff_keys/{uid}`).
///  * Each conversation gets one random 256-bit AES-GCM key (the "conversation
///    key"). It is handed to every participant with an ECDH ephemeral "sealed
///    box": a per-conversation X25519 ephemeral key is deleted right after
///    creation (forward secrecy); for each participant a KEK is derived via
///    `X25519(ephPrivate, participantPublic)` -> HKDF-SHA256, and the
///    conversation key is AES-GCM wrapped with that KEK and stored per device.
///  * Every message (text or photo) is AES-256-GCM encrypted with the same
///    conversation key. Firestore only ever sees ciphertext + nonces + MACs.
class ChatCrypto {
  ChatCrypto._();

  static const _cryptoVersion = 1;

  // X25519 for the device key + per-conversation ECDH.
  static final _x = cg.X25519();
  static final _hkdf = cg.Hkdf(hmac: cg.Hmac.sha256(), outputLength: 32);
  static final _aes = cg.AesGcm.with256bits();

  static final _deviceKeyCache = <String, String?>{'priv': null, 'pub': null};
  static final _localKeyCache = <String, List<int>>{};
  static String? _ownKeyId;

  /// Fingerprint of a public key (stable id used inside `wrappedKeys`).
  static String keyIdOf(String publicKeyB64) {
    final hash = crypto.sha256.convert(utf8.encode(publicKeyB64)).toString();
    return hash.substring(0, 24);
  }

  static List<int> _b64(String s) => base64Decode(s);

  static cg.SimplePublicKey _pubFromB64(String b64) =>
      cg.SimplePublicKey(_b64(b64), type: cg.KeyPairType.x25519);

  /// Creates (and persists) the device key pair on first use; otherwise loads
  /// it from the keystore. Best-effort like the rest of [SecureStore].
  static Future<cg.SimpleKeyPairData> ensureDevicePair() async {
    final loaded = _deviceKeyCache['priv'];
    if (loaded != null) {
      return cg.SimpleKeyPairData(
        _b64(loaded),
        publicKey: _pubFromB64(_deviceKeyCache['pub']!),
        type: cg.KeyPairType.x25519,
      );
    }
    try {
      final privB64 = await SecureStore.readChatPrivateKey();
      final pubB64 = await SecureStore.readChatPublicKey();
      if (privB64 != null && pubB64 != null && privB64.isNotEmpty) {
        _deviceKeyCache['priv'] = privB64;
        _deviceKeyCache['pub'] = pubB64;
        _ownKeyId = keyIdOf(pubB64);
        return cg.SimpleKeyPairData(
          _b64(privB64),
          publicKey: _pubFromB64(pubB64),
          type: cg.KeyPairType.x25519,
        );
      }
    } catch (_) {}
    // Fresh device key.
    final pair = await _x.newKeyPair();
    final pub = await pair.extractPublicKey();
    final cg.SimpleKeyPairData privData;
    try {
      privData = await pair.extract();
    } catch (_) {
      // Fallback for platforms where extract() is not available: not expected
      // with the pure-Dart X25519 implementation.
      return cg.SimpleKeyPairData(
        List<int>.generate(32, (i) => 0),
        publicKey: pub,
        type: cg.KeyPairType.x25519,
      );
    }
    final pubB64 = base64Encode(pub.bytes);
    final privB64 = base64Encode(privData.bytes);
    await SecureStore.writeChatKey(privateB64: privB64, publicB64: pubB64);
    _deviceKeyCache['priv'] = privB64;
    _deviceKeyCache['pub'] = pubB64;
    _ownKeyId = keyIdOf(pubB64);
    return privData;
  }

  /// Base64 X25519 public key of this device (generated on first use).
  static Future<String> myPublicKeyB64() async {
    final pair = await ensureDevicePair();
    final pub = await pair.extractPublicKey();
    return base64Encode(pub.bytes);
  }

  static Future<String> myKeyId() async {
    if (_ownKeyId != null) return _ownKeyId!;
    final pub = await myPublicKeyB64();
    _ownKeyId = keyIdOf(pub);
    return _ownKeyId!;
  }

  /// Fresh random 256-bit conversation key (base64, 32 bytes).
  static String newConversationKey() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64Encode(bytes);
  }

  /// Seals [convKeyB64] for every [recipients] public key (base64 X25519).
  ///
  /// Returns the shared ephemeral public key (base64) plus one AES-GCM wrapped
  /// copy of the conversation key per recipient, keyed by [keyIdOf] their pub.
  /// The ephemeral private key is deliberately NOT returned, so old
  /// conversations cannot be unwrapped even if the server is later breached.
  static Future<({
    String ephPubB64,
    Map<String, String> sealed,
    Map<String, String> nonces,
    Map<String, String> macs,
  })> sealConversationKey({
    required String conversationId,
    required String convKeyB64,
    required List<String> recipientsPublicB64,
  }) async {
    final eph = await _x.newKeyPair();
    final ephPub = await eph.extractPublicKey();
    final ephPubB64 = base64Encode(ephPub.bytes);

    final sealed = <String, String>{};
    final nonces = <String, String>{};
    final macs = <String, String>{};

    final convKey = cg.SecretKeyData(_b64(convKeyB64));
    for (final recipient in recipientsPublicB64) {
      try {
        final shared = await _x.sharedSecretKey(
          keyPair: eph,
          remotePublicKey: _pubFromB64(recipient),
        );
        final kek = await _hkdf.deriveKey(
          secretKey: shared,
          info: utf8.encode(conversationId),
        );
        final box = await _aes.encrypt(
          convKey.bytes,
          secretKey: kek,
          nonce: _aes.newNonce(),
        );
        final keyId = keyIdOf(recipient);
        sealed[keyId] = base64Encode(box.cipherText);
        nonces[keyId] = base64Encode(box.nonce);
        macs[keyId] = base64Encode(box.mac.bytes);
      } catch (_) {
        // A single broken recipient key must not block the conversation.
      }
    }
    eph.destroy();
    convKey.destroy();
    return (ephPubB64: ephPubB64, sealed: sealed, nonces: nonces, macs: macs);
  }

  /// Recovers the conversation key on this device from an ECDH sealed box
  /// written for this device's public key. Returns base64 conversation key.
  static Future<String?> openConversationKey({
    required String conversationId,
    required String ephPubB64,
    required String sealedB64,
    required String nonceB64,
    required String macB64,
  }) async {
    try {
      final pair = await ensureDevicePair();
      final shared = await _x.sharedSecretKey(
        keyPair: pair,
        remotePublicKey: _pubFromB64(ephPubB64),
      );
      final kek = await _hkdf.deriveKey(
        secretKey: shared,
        info: utf8.encode(conversationId),
      );
      final decrypted = await _aes.decrypt(
        cg.SecretBox(_b64(sealedB64), nonce: _b64(nonceB64), mac: cg.Mac(_b64(macB64))),
        secretKey: kek,
      );
      return base64Encode(decrypted);
    } catch (_) {
      return null;
    }
  }

  /// AES-256-GCM encrypt [plainText]. Returns base64 nonce/data/mac.
  static Future<(String nonce, String data, String mac)> encryptText(
    String convKeyB64,
    String plainText,
  ) async {
    final box = await _aes.encrypt(
      utf8.encode(plainText),
      secretKey: cg.SecretKeyData(_b64(convKeyB64)),
      nonce: _aes.newNonce(),
    );
    return (base64Encode(box.nonce), base64Encode(box.cipherText), base64Encode(box.mac.bytes));
  }

  static Future<String?> decryptText(String convKeyB64, String nonceB64, String dataB64, String macB64) async {
    try {
      final box = cg.SecretBox(
        _b64(dataB64),
        nonce: _b64(nonceB64),
        mac: cg.Mac(_b64(macB64)),
      );
      final clear = await _aes.decrypt(box, secretKey: cg.SecretKeyData(_b64(convKeyB64)));
      return utf8.decode(clear);
    } catch (_) {
      return null;
    }
  }

  /// AES-256-GCM encrypt arbitrary bytes (a photo). Returns base64 nonce/data/mac.
  static Future<(String nonce, String data, String mac)> encryptBytes(
    String convKeyB64,
    List<int> bytes,
  ) async {
    final box = await _aes.encrypt(
      bytes,
      secretKey: cg.SecretKeyData(_b64(convKeyB64)),
      nonce: _aes.newNonce(),
    );
    return (base64Encode(box.nonce), base64Encode(box.cipherText), base64Encode(box.mac.bytes));
  }

  static Future<List<int>?> decryptBytes(
    String convKeyB64,
    String nonceB64,
    String dataB64,
    String macB64,
  ) async {
    try {
      final box = cg.SecretBox(
        _b64(dataB64),
        nonce: _b64(nonceB64),
        mac: cg.Mac(_b64(macB64)),
      );
      return await _aes.decrypt(box, secretKey: cg.SecretKeyData(_b64(convKeyB64)));
    } catch (_) {
      return null;
    }
  }

  /// Locally persists the conversation key (inside the device vault only; it
  /// never reaches the network or Firestore). From then on this device can
  /// decrypt the conversation even if its RSA-unwrap path is revoked.
  static Future<void> stashConversationKey(String conversationId, String convKeyB64) async {
    _localKeyCache[conversationId] = _b64(convKeyB64);
    await SecureStore.writeConversationKey(conversationId, convKeyB64);
  }

  /// Recovers the conversation key on this device: preferred path is the local
  /// vault (customer that created the chat); fallback is an ECDH sealed box
  /// addressed to this device (team devices). Returns base64 conversation key.
  static Future<String?> unwrapConversationKey(
    String conversationId, {
    String ephPubB64 = '',
    String sealedB64 = '',
    String nonceB64 = '',
    String macB64 = '',
  }) async {
    if (_localKeyCache.containsKey(conversationId)) {
      return base64Encode(_localKeyCache[conversationId]!);
    }
    try {
      final stashed = await SecureStore.readConversationKey(conversationId);
      if (stashed != null && stashed.isNotEmpty) {
        // The vault copy is itself the base64 conversation key.
        return stashed;
      }
    } catch (_) {}
    if (ephPubB64.isNotEmpty && sealedB64.isNotEmpty) {
      return openConversationKey(
        conversationId: conversationId,
        ephPubB64: ephPubB64,
        sealedB64: sealedB64,
        nonceB64: nonceB64,
        macB64: macB64,
      );
    }
    return null;
  }

  /// Removes a conversation key from the local vault (on chat close/logout).
  static Future<void> forgetConversationKey(String conversationId) async {
    _localKeyCache.remove(conversationId);
    await SecureStore.deleteConversationKey(conversationId);
  }

  static int get cryptoVersion => _cryptoVersion;
}