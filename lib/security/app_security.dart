import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Runtime security gates shared across the whole app (طبقة الحماية العامة).
///
/// The app does NOT trust any user-supplied string as-is: everything crossing
/// a log line, a URL, a document field or a chat message first passes through
/// [sanitizeText]. Long-lived sessions are validated with [isValidSessionToken]
/// and tokens are masked before logging via [redactToken]. Device posture
/// (debug/root/emulator) is read from the native host on demand through
/// [readDeviceChecks] and never used to gate a legitimate user - but release
/// builds that ship with the debuggable flag ON surface an immediate warning.
class AppSecurity {
  AppSecurity._();

  static const int maxTextLength = 4000;
  static const String _controlChars = '\u200B\u200C\u200D\u2060\uFEFF';

  static final MethodChannel _channel = const MethodChannel('goss/security');

  /// True when the binary is a release/production build.
  static bool get isReleaseBuild => kReleaseMode;

  /// True under `flutter test` (no native host available).
  static bool get isRunningUnderTest =>
      Platform.environment['FLUTTER_TEST'] == 'true';

  /// Strongest session token shape we accept: one non-blank opaque blob with
  /// no whitespace and at least 12 characters. Firebase ID tokens and the
  /// legacy opaque server tokens both satisfy it; placeholders never do.
  static bool isValidSessionToken(String? token, {bool allowTestTokens = false}) {
    if (token == null || token.isEmpty) return false;
    if (!allowTestTokens && token == 'test-token') return false;
    if (token.length < 12) return false;
    return RegExp(r'^\S+$').hasMatch(token);
  }

  /// Trim, strip zero-width/control characters and clamp the length so no
  /// value typed by a user can be used as an injection/overflow vector.
  static String sanitizeText(String? value, {int max = maxTextLength}) {
    if (value == null) return '';
    var out = value.replaceAll(RegExp('[\\u0000-\\u001F\\u007F\\u2000-\\u200A]'), ' ');
    for (final ch in _controlChars.split('')) {
      out = out.replaceAll(ch, '');
    }
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    return out.length <= max ? out : out.substring(0, max);
  }

  /// Normalise an admin/operator email for comparison and persisted storage.
  static String sanitizeEmail(String? value) =>
      sanitizeText(value, max: 254).toLowerCase();

  /// Mask a session token before it ever reaches a log/error line.
  static String redactToken(String? token) {
    if (token == null || token.isEmpty) return '<none>';
    if (token.length < 12) return '<redacted>';
    return '${token.substring(0, 4)}…${token.substring(token.length - 4)}';
  }

  /// Device posture reported by the native host (best-effort).
  static Future<DeviceSecurityReport> readDeviceChecks() async {
    if (isRunningUnderTest || kIsWeb) return const DeviceSecurityReport.unavailable();
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('deviceChecks');
      if (raw == null) return const DeviceSecurityReport.unavailable();
      return DeviceSecurityReport(
        debuggable: raw['debuggable'] == true,
        rooted: raw['rooted'] == true,
        emulator: raw['emulator'] == true,
        checked: true,
      );
    } catch (_) {
      return const DeviceSecurityReport.unavailable();
    }
  }

  /// Policy: in a release build a debuggable/testable APK is always a red
  /// flag worth surfacing loudly (someone repacked or sideloaded the binary).
  static String? releasePostureWarning(DeviceSecurityReport report) {
    if (!isReleaseBuild) return null;
    if (report.debuggable) {
      return 'release-build-with-debug-flag';
    }
    if (report.rooted) {
      return 'release-build-on-rooted-device';
    }
    return null;
  }
}

/// Immutable snapshot of the native security probe.
class DeviceSecurityReport {
  const DeviceSecurityReport({
    required this.debuggable,
    required this.rooted,
    required this.emulator,
    required this.checked,
  });

  const DeviceSecurityReport.unavailable()
      : debuggable = false,
        rooted = false,
        emulator = false,
        checked = false;

  final bool debuggable;
  final bool rooted;
  final bool emulator;
  final bool checked;

  bool get isClean => checked && !debuggable && !rooted;
}