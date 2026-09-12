import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted credential vault for quick sign-in (الدخول السريع).
///
/// The email/password pair lives ONLY in the platform keystore/keychain
/// (Android Keystore + EncryptedSharedPreferences / iOS Keychain), never in
/// the plain SharedPreferences archive. The passcode is kept as a salted
/// SHA-256 hash, so the vault never holds a reversible local PIN. Every read
/// here is best-effort: a platform/plugin failure degrades to "not enrolled"
/// instead of crashing the app.
class SecureStore {
  SecureStore._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// True under `flutter test`: the platform keystore has no host there, so the
  /// plugin call never answers (and would leave a pending timer behind). Bypass
  /// the vault in tests and behave as "nothing enrolled" - callers already
  /// fall back to the SharedPreferences legacy copies.
  static final bool _inTest = Platform.environment['FLUTTER_TEST'] == 'true';

  static const _kEmail = 'goss-quick-signin-email';
  static const _kPassword = 'goss-quick-signin-pass';
  static const _kPasscode = 'goss-quick-signin-passcode';
  static const _kToken = 'goss-auth-token';
  static const _kQuickLockPin = 'goss-quicklock-pin';
  static const _kChatPriv = 'goss-chat-key-private';
  static const _kChatPub = 'goss-chat-key-public';
  static const _kConvPrefix = 'goss-chat-conv';
  static const _kAdminEmail = 'goss-admin-email-vault';
  static const _kAdminRole = 'goss-admin-role-vault';
  static const _kAdminPerms = 'goss-admin-perms-vault';

  static String _hashPasscode(String value) =>
      sha256.convert(utf8.encode('goss-quick-signin:$value')).toString();

  /// Bounded read: a missing/slow platform plugin must never block app
  /// startup (e.g. under widget tests, where no plugin host exists the call
  /// would otherwise stay pending forever); the vault lookup is near
  /// instant on a real device, so 1.5s is a generous margin.
  static Future<String?> _read(String key) async {
    if (_inTest) return null;
    try {
      return await _storage.read(key: key).timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      return null;
    }
  }

  /// Auth session token. Lives in the vault (never plain SharedPreferences) so
  /// an extracted SharedPreferences archive cannot replay an admin session.
  static Future<String?> readToken() async {
    return _read(_kToken);
  }

  static Future<void> writeToken(String token) async {
    if (_inTest) return;
    try {
      await _storage.write(key: _kToken, value: token);
    } catch (_) {}
  }

  static Future<void> clearToken() async {
    if (_inTest) return;
    try {
      await _storage.delete(key: _kToken);
    } catch (_) {}
  }

  /// Admin session metadata (email/role/permissions). These gate the local UI,
  /// but are still stored in the vault so a plain SharedPreferences archive
  /// cannot reveal or replay them. Missing/legacy copies fall back transparently
  /// to the app-provider's migration path.
  static Future<String?> readAdminEmail() async => _read(_kAdminEmail);

  static Future<void> writeAdminEmail(String email) async {
    if (_inTest) return;
    try {
      await _storage.write(key: _kAdminEmail, value: email.trim());
    } catch (_) {}
  }

  static Future<String?> readAdminRole() async => _read(_kAdminRole);

  static Future<void> writeAdminRole(String role) async {
    if (_inTest) return;
    try {
      await _storage.write(key: _kAdminRole, value: role.trim());
    } catch (_) {}
  }

  static Future<List<String>?> readAdminPermissions() async {
    final raw = await _read(_kAdminPerms);
    if (raw == null || raw.isEmpty) return null;
    return raw.split(',').where((e) => e.isNotEmpty).toList();
  }

  static Future<void> writeAdminPermissions(List<String> perms) async {
    if (_inTest) return;
    try {
      await _storage.write(key: _kAdminPerms, value: perms.join(','));
    } catch (_) {}
  }

  static Future<void> clearAdminMetadata() async {
    if (_inTest) return;
    try {
      await _storage.delete(key: _kAdminEmail);
      await _storage.delete(key: _kAdminRole);
      await _storage.delete(key: _kAdminPerms);
    } catch (_) {}
  }

  /// Hashed quick-lock PIN. Even the hash never sits in plain SharedPreferences
  /// (only the secure keystore/keychain keeps it; the pref copy is migrated and
  /// wiped on first load).
  static Future<String?> readQuickLockPinHash() async {
    return _read(_kQuickLockPin);
  }

  static Future<void> writeQuickLockPinHash(String hash) async {
    if (_inTest) return;
    try {
      await _storage.write(key: _kQuickLockPin, value: hash);
    } catch (_) {}
  }

  static Future<void> clearQuickLockPinHash() async {
    if (_inTest) return;
    try {
      await _storage.delete(key: _kQuickLockPin);
    } catch (_) {}
  }

  /// Chat E2E device key (RSA private + public, base64). Kept in the keystore
  /// so the decryption key never touches plain storage or the network.
  static Future<void> writeChatKey({
    required String privateB64,
    required String publicB64,
  }) async {
    if (_inTest) return;
    try {
      await _storage.write(key: _kChatPriv, value: privateB64);
      await _storage.write(key: _kChatPub, value: publicB64);
    } catch (_) {}
  }

  static Future<String?> readChatPrivateKey() async {
    return _read(_kChatPriv);
  }

  static Future<String?> readChatPublicKey() async {
    return _read(_kChatPub);
  }

  /// Wrapped (RSA-OAEP to this device) per-conversation keys. Firestore never
  /// sees these; they only un-stash the conversation key on this device.
  static Future<void> writeConversationKey(String conversationId, String wrappedB64) async {
    if (_inTest) return;
    try {
      await _storage.write(key: '$_kConvPrefix-$conversationId', value: wrappedB64);
    } catch (_) {}
  }

  static Future<String?> readConversationKey(String conversationId) async {
    return _read('$_kConvPrefix-$conversationId');
  }

  static Future<void> deleteConversationKey(String conversationId) async {
    if (_inTest) return;
    try {
      await _storage.delete(key: '$_kConvPrefix-$conversationId');
    } catch (_) {}
  }

  static Future<bool> hasCredentials() async {
    final email = await _read(_kEmail);
    final password = await _read(_kPassword);
    final passcode = await _read(_kPasscode);
    return (email?.isNotEmpty ?? false) &&
        (password?.isNotEmpty ?? false) &&
        (passcode?.isNotEmpty ?? false);
  }

  static Future<String?> readEmail() async {
    return _read(_kEmail);
  }

  /// Returns the remembered password. Callers MUST gate this behind a
  /// successful local auth check (biometric or passcode) before using it.
  static Future<String?> readPassword() async {
    return _read(_kPassword);
  }

  static Future<bool> verifyPasscode(String passcode) async {
    final hash = await _read(_kPasscode);
    return hash != null && hash.isNotEmpty && _hashPasscode(passcode) == hash;
  }

  static Future<String?> storeCredentials({
    required String email,
    required String password,
    required String passcode,
  }) async {
    if (_inTest) return null;
    try {
      await _storage.write(key: _kEmail, value: email.trim());
      await _storage.write(key: _kPassword, value: password);
      await _storage.write(key: _kPasscode, value: _hashPasscode(passcode));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<void> clear() async {
    if (_inTest) return;
    try {
      await _storage.delete(key: _kEmail);
      await _storage.delete(key: _kPassword);
      await _storage.delete(key: _kPasscode);
    } catch (_) {}
  }
}