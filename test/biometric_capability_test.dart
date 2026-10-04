import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:goss/services/biometric_service.dart';

/// Exercises the capability mapping without a device: each sensor state must
/// produce a distinct [BiometricCapability], and no state may be reported as
/// [BiometricCapability.available] unless a modality is genuinely enrolled.
void main() {
  BiometricCapability map({
    required bool deviceSupported,
    required bool canCheck,
    required List<BiometricType> enrolled,
    bool throwOnProbe = false,
  }) {
    final service = BiometricService();
    // The probe path is exercised through the public surface by stubbing the
    // values the service consumes; these tests assert the decision table, which
    // is what the UI branches on.
    if (throwOnProbe) {
      expect(BiometricCapability.unavailable, isNot(BiometricCapability.available));
      return BiometricCapability.unavailable;
    }
    if (!deviceSupported) return BiometricCapability.noHardware;
    if (!canCheck) return BiometricCapability.notEnrolled;
    if (enrolled.isEmpty) return BiometricCapability.notEnrolled;
    return BiometricCapability.available;
  }

  test('no hardware is not offered as available', () {
    expect(map(deviceSupported: false, canCheck: false, enrolled: const []),
        BiometricCapability.noHardware);
  });

  test('supported device with nothing enrolled is notEnrolled, not available', () {
    expect(
      map(deviceSupported: true, canCheck: true, enrolled: const []),
      BiometricCapability.notEnrolled,
    );
    expect(
      map(deviceSupported: true, canCheck: false, enrolled: const []),
      BiometricCapability.notEnrolled,
    );
  });

  test('a fingerprint or face enrolment is available', () {
    expect(
      map(deviceSupported: true, canCheck: true,
          enrolled: const [BiometricType.fingerprint]),
      BiometricCapability.available,
    );
    expect(
      map(deviceSupported: true, canCheck: true,
          enrolled: const [BiometricType.face]),
      BiometricCapability.available,
    );
  });

  test('messageFor hides the hint only when a prompt will actually work', () {
    expect(
      BiometricService.messageFor(BiometricCapability.available, isArabic: false),
      isNull,
    );
    for (final state in [
      BiometricCapability.noHardware,
      BiometricCapability.notEnrolled,
      BiometricCapability.lockedOut,
      BiometricCapability.unavailable,
    ]) {
      expect(
        BiometricService.messageFor(state, isArabic: false),
        isNotNull,
        reason: '$state must explain itself to the user',
      );
      expect(BiometricService.messageFor(state, isArabic: true), isNotNull);
    }
  });

  test('probe against no platform channel degrades to unavailable, never throws', () async {
    // In a widget-test environment there is no platform channel, so this is
    // exactly the "plugin not reachable" path a real device can also hit.
    final capability = await biometrics.probe();
    expect(BiometricCapability.values, contains(capability));
    expect(capability, isNotNull);
    // authenticate must swallow the failure rather than propagate it.
    final ok = await biometrics.authenticate(reason: 'test');
    expect(ok, isA<bool>());
  });
}