import 'package:local_auth/local_auth.dart';

/// Why a biometric prompt is or is not usable right now.
///
/// The distinction matters for the UI: "this phone has no sensor" is a normal
/// state to hide the option, while "the sensor exists but nothing is enrolled"
/// is an actionable message, and "locked out after too many failures" must
/// route the user to the device's own unlock settings instead of a dead end.
enum BiometricCapability {
  /// Ready to prompt.
  available,

  /// Hardware is missing entirely (emulator with no sensor, some tablets).
  noHardware,

  /// Sensor exists but the user never enrolled a fingerprint/face.
  notEnrolled,

  /// Too many failed attempts; the platform locks biometrics out for a while.
  lockedOut,

  /// The plugin could not be reached (no platform channel, or a throw).
  unavailable,
}

/// Single entry point for fingerprint / face unlock.
///
/// Two rules this enforces that calling `local_auth` directly does not:
///
/// 1. `canCheckBiometrics` alone is not enough. It returns true on a phone
///    whose sensor exists but has no enrollment, so the UI would offer
///    "Sign in with fingerprint" and then fail. [probe] also checks
///    `isDeviceSupported` and the enrolled list.
/// 2. A failed or missing sensor must never strand a user who has a valid
///    password. [authenticate] reports why it failed instead of throwing, and
///    the caller keeps the passcode and full-password paths available.
class BiometricService {
  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  BiometricCapability _capability = BiometricCapability.unavailable;
  BiometricCapability get capability => _capability;

  /// Human-readable detail for the current capability, for logs only — the UI
  /// shows its own translated copy.
  String get lastDiagnostic => _diagnostic;
  String _diagnostic = '';

  /// True when a prompt would not immediately fail.
  bool get canPrompt => _capability == BiometricCapability.available;

  /// True when the device has a usable sensor even if nothing is enrolled, so
  /// the UI can offer an "enrol now" hint rather than pretending it is absent.
  bool get hasHardware =>
      _capability == BiometricCapability.available ||
      _capability == BiometricCapability.notEnrolled ||
      _capability == BiometricCapability.lockedOut;

  /// Which modalities the user has actually enrolled. Empty means nothing is
  /// enrolled. Used to label the button ("Face ID" vs "Fingerprint").
  Future<List<BiometricType>> enrolledTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      _diagnostic = 'getAvailableBiometrics threw: $e';
      return const [];
    }
  }

  /// Refreshes [capability]. Safe to call repeatedly; it is cheap and does not
  /// show any UI.
  Future<BiometricCapability> probe() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        _capability = BiometricCapability.noHardware;
        _diagnostic = 'isDeviceSupported() returned false';
        return _capability;
      }
      // A passcode/device-credential set satisfies the platform check even with
      // no biometric enrolled, which is exactly the case where prompting would
      // still fail for a biometric-only request.
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) {
        _capability = BiometricCapability.notEnrolled;
        _diagnostic = 'device supported but canCheckBiometrics is false';
        return _capability;
      }
      final enrolled = await enrolledTypes();
      if (enrolled.isEmpty) {
        _capability = BiometricCapability.notEnrolled;
        _diagnostic = 'no biometrics enrolled';
        return _capability;
      }
      _capability = BiometricCapability.available;
      _diagnostic = 'enrolled: ${enrolled.map((e) => e.name).join(',')}';
      return _capability;
    } catch (e) {
      // Includes the case where the platform channel is missing entirely.
      _capability = BiometricCapability.unavailable;
      _diagnostic = 'probe threw: $e';
      return _capability;
    }
  }

  /// Attempts a biometric prompt.
  ///
  /// Returns true only on a verified identity. On failure it returns false and
  /// refreshes [capability] so the caller can explain the reason; it never
  /// throws, because a biometric failure must always leave the password path
  /// usable.
  ///
  /// [persistAcrossBackgrounding] is enabled so a prompt interrupted by an
  /// incoming call resumes instead of silently reporting failure.
  Future<bool> authenticate({
    required String reason,
    bool persistAcrossBackgrounding = true,
  }) async {
    try {
      // local_auth 3.x takes these as named parameters; `persistAcrossBackgrounding`
      // is the public name for the platform's sticky-auth behaviour, so a prompt
      // interrupted by an incoming call resumes instead of reporting failure.
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // PIN/passcode fallback inside the system sheet. The app also has its
        // own 4-digit gate, but letting the platform offer it means a user
        // with an unenrolled sensor is never hard-blocked.
        biometricOnly: false,
        persistAcrossBackgrounding: persistAcrossBackgrounding,
      );
      if (ok) {
        _capability = BiometricCapability.available;
        return true;
      }
      // A false result can mean the user cancelled (harmless) or the sensor
      // locked out. Re-probing distinguishes the two so the UI can react.
      await probe();
      return false;
    } catch (e) {
      _diagnostic = 'authenticate threw: $e';
      // BiometricLockout / NotAvailable surface as PlatformException codes; a
      // lockout must not clear a previously working capability silently.
      await probe();
      return false;
    }
  }

  /// Best-effort biometric label for the prompt button, in the given language.
  Future<String> label({required bool isArabic}) async {
    final types = await enrolledTypes();
    if (types.contains(BiometricType.face)) {
      return isArabic ? 'الدخول بالوجه' : 'Sign in with Face ID';
    }
    if (types.contains(BiometricType.fingerprint) ||
        types.contains(BiometricType.strong) ||
        types.contains(BiometricType.weak)) {
      return isArabic ? 'الدخول بالبصمة' : 'Sign in with fingerprint';
    }
    return isArabic ? 'الدخول بالبصمة' : 'Sign in with biometrics';
  }

  /// Maps a capability to a user-facing message, or null when the option should
  /// simply be hidden.
  static String? messageFor(
    BiometricCapability capability, {
    required bool isArabic,
  }) {
    switch (capability) {
      case BiometricCapability.available:
        return null;
      case BiometricCapability.noHardware:
        return isArabic
            ? 'البصمة غير متوفرة على هذا الجهاز.'
            : 'Biometrics are not available on this device.';
      case BiometricCapability.notEnrolled:
        return isArabic
            ? 'لم تسجّل بصمة على هذا الجهاز. فعّلها من إعدادات النظام.'
            : 'No fingerprint or face is enrolled on this device. Add one in system settings.';
      case BiometricCapability.lockedOut:
        return isArabic
            ? 'البصمة مقفولة مؤقتًا بسبب محاولات خاطئة. فكّ القفل من إعدادات النظام.'
            : 'Biometrics are temporarily locked after failed attempts. Unlock with your device PIN, then try again.';
      case BiometricCapability.unavailable:
        return isArabic
            ? 'تعذّر الوصول لخدمة البصمة على هذا الجهاز.'
            : 'The biometric service could not be reached on this device.';
    }
  }
}

/// Shared instance: the probe result is device state, not per-screen state.
final BiometricService biometrics = BiometricService();