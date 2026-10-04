import 'package:flutter_test/flutter_test.dart';
import 'package:goss/providers/app_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppProvider> _freshApp() async {
  final app = AppProvider();
  // Let the async _loadFromStorage() that the constructor kicks off read (and
  // settle on) the persisted values before the test mutates the same state.
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('is disabled and unlocked by default', () async {
    final app = await _freshApp();
    expect(app.quickLockEnabled, isFalse);
    expect(app.quickLocked, isFalse);
    expect(app.quickLockBio, isFalse);
  });

  test('enableQuickLock keeps the PIN verifier out of plain prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final app = await _freshApp();
    await app.enableQuickLock(bio: false, pin: '1234');

    expect(app.quickLockEnabled, isTrue);
    expect(app.quickLockBio, isFalse);
    expect(app.quickLockPinHash, isNotEmpty);
    expect(app.quickLockPinHash, isNot('1234'));

    // The verifier lives only in the secure store. Mirroring it into
    // SharedPreferences exposed it to anything that can read an app backup.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('goss-quicklock-pin'), isNull);
    expect(prefs.getString('goss-quicklock-pin'), isNot(app.quickLockPinHash));

    expect(app.verifyQuickLockPin('1234'), isTrue);
    expect(app.verifyQuickLockPin('0000'), isFalse);
    expect(app.verifyQuickLockPin(''), isFalse);
  });

  test('enableQuickLock wipes a PIN hash a previous build left in prefs', () async {
    SharedPreferences.setMockInitialValues({'goss-quicklock-pin': 'legacy-hash'});
    final app = await _freshApp();
    await app.enableQuickLock(bio: false, pin: '5678');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('goss-quicklock-pin'), isNull);
  });

  test('markQuickLocked persists the locked flag and gate is exposed', () async {
    final app = await _freshApp();
    await app.enableQuickLock(bio: true, pin: '4321');
    expect(app.quickLocked, isFalse);

    await app.markQuickLocked();
    expect(app.quickLocked, isTrue);

    await app.unmarkQuickLocked();
    expect(app.quickLocked, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('goss-quicklock-locked'), isFalse);
  });

  test('markQuickLocked is a no-op while quick lock is disabled', () async {
    final app = await _freshApp();
    await app.markQuickLocked();
    expect(app.quickLocked, isFalse);
  });

  test('a cold start on a saved locked session restores the lock state', () async {
    SharedPreferences.setMockInitialValues({
      'goss-token': 'stale-token',
      'goss-quicklock': true,
      'goss-quicklock-bio': true,
      'goss-quicklock-pin': 'deadbeef',
      'goss-quicklock-locked': true,
    });
    final app = await _freshApp();
    expect(app.quickLockEnabled, isTrue);
    expect(app.quickLocked, isTrue);
    expect(app.quickLockBio, isTrue);
  });

  test('disableQuickLock clears everything', () async {
    final app = await _freshApp();
    await app.enableQuickLock(bio: true, pin: '1111');
    await app.disableQuickLock();

    expect(app.quickLockEnabled, isFalse);
    expect(app.quickLockBio, isFalse);
    expect(app.quickLockPinHash, isEmpty);
    expect(app.quickLocked, isFalse);
    expect(app.verifyQuickLockPin('1111'), isFalse);
  });
}