import 'dart:io' show Platform, exit;

import 'package:freerasp/freerasp.dart';
import 'package:flutter/foundation.dart';

import 'app_security.dart';

/// Runtime Self-Protection (RASP) — freeRASP/Talsec.
///
/// Watches the live environment for root/privileged access, hooking (Frida),
/// debuggers, app-integrity tampering, emulators, unofficial stores and more.
/// Policy:
///  * release build + critical threat  -> hard stop (fail closed);
///  * release build + informational threat (emulator, dev-mode, VPN,
///    signing mismatch, sideload) -> warn + continue;
///  * debug / tests -> never blocked.
///
/// IMPORTANT (store release): Google Play re-signs delivered builds with its
/// own key (Play App Signing). freeRASP's `killOnBypass` would kill the app
/// WITHOUT invoking callbacks, so integrity/signing differences from the store
/// cert would brick every real install. We therefore: keep `killOnBypass:
/// false`, keep hard-stop only for genuine attack signals (root/hooks/debug),
/// and treat signing-cert mismatches and non-store installs as informational.
/// Reactivation after obtaining the Play app-signing SHA-256 is documented on
/// [_signingHashes].
/// Disable entirely with `--dart-define=RASP_MODE=off` if a vendor build
/// needs it (not recommended in production).
class RaspGuard {
  RaspGuard._();

  /// Fill with the security mailbox that should receive freeRASP reports.
  static const String _watcherMail = 'info@gossts.com';

  /// Release signing cert SHA-256 (Base64) — the attestation anchor.
  ///
  /// When the app ships through Google Play, Play App Signing re-signs the
  /// delivered APK with Google's own key, so ANY hard-coded upload-key hash
  /// mismatches on store installs. Until the Play app-signing cert hash is
  /// added here, integrity mismatches are logged (never fatal) so the store
  /// build cannot kill itself. To re-arm the hard check:
  ///  1. Play Console → Release setup → App signing → copy the app signing
  ///     certificate SHA-256, base64-encode it, and add it to this list.
  ///  2. Flip [killOnIntegrityMismatch] to true.
  static const List<String> _signingHashes = [
    'p1ST4V5eamPnzBhncKryCQpZjZEZqKVRBJ3yO7yukOI=', // local upload keystore
  ];

  /// Whether a signing-cert mismatch should hard-stop the process. Kept false
  /// because Play App Signing re-signs store builds (see [_signingHashes]).
  /// All other critical threats (root, hooks, debugger) stay fatal.
  static const bool killOnIntegrityMismatch = false;

  /// true → freeRASP itself kills the process on bypass *without* firing the
  /// callbacks. With Play App Signing this would brick store installs, so we
  /// keep SDK auto-kill OFF and control termination ourselves in [_critical].
  static const bool _sdkAutoKill = false;

  static bool _started = false;

  static bool get _enabled {
    if (AppSecurity.isRunningUnderTest) return false;
    if (kIsWeb) return false;
    return const String.fromEnvironment('RASP_MODE') != 'off';
  }

  static Future<void> start() async {
    if (_started || !_enabled || !Platform.isAndroid) return;
    _started = true;
    try {
      await Talsec.instance.attachListener(
        ThreatCallback(
          // Genuine attack signals: act immediately.
          onPrivilegedAccess: _critical,
          onHooks: _critical,
          onDebug: _critical,
          // Signing-cert differs (Play App Signing, legitimate sideloads, or a
          // repackaged APK). Non-fatal so store builds stay usable; re-arm via
          // [killOnIntegrityMismatch] once the Play hash is added.
          onAppIntegrity: killOnIntegrityMismatch ? _critical : _informational,
          // Manual/enterprise installs and device binding changes are NOT
          // attacks on their own; blocking them would lock out real users.
          onUnofficialStore: _informational,
          onDeviceBinding: _informational,
          onObfuscationIssues: _informational,
          onSimulator: _informational,
          onDevMode: _informational,
          onSystemVPN: _informational,
          onADBEnabled: _informational,
          onSecureHardwareNotAvailable: _informational,
        ),
      );
      await Talsec.instance.start(
        TalsecConfig(
          watcherMail: _watcherMail,
          isProd: AppSecurity.isReleaseBuild,
          killOnBypass: _sdkAutoKill,
          androidConfig: AndroidConfig(
            packageName: 'com.gosst.goss',
            signingCertHashes: _signingHashes,
          ),
        ),
      );
    } catch (_) {
      // RASP must never brick the app when the platform host is unavailable.
    }
  }

  static void _critical() {
    if (!AppSecurity.isReleaseBuild) return;
    exit(0);
  }

  static void _informational() {
    // Keep the session running; the signal is only surfaced to the security
    // watcher mailbox, never displayed or fatal.
  }
}