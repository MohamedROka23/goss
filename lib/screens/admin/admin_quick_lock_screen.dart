import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../app/responsive.dart';
import '../../services/biometric_service.dart';
import '../../providers/app_provider.dart';

/// Quick-lock unlock screen (قفل سريع): shown before the admin dashboard when a
/// quick lock is enabled and the app was backgrounded or cold-started on a
/// saved session. Unlocks with a biometric prompt and/or the saved 4-digit PIN;
/// the admin can always fall back to signing out to the password login. Five
/// wrong PIN attempts trigger a short cooldown so the PIN cannot be brute-forced
/// from the lock screen.
class AdminQuickLockScreen extends StatefulWidget {
  const AdminQuickLockScreen({super.key});

  @override
  State<AdminQuickLockScreen> createState() => _AdminQuickLockScreenState();
}

class _AdminQuickLockScreenState extends State<AdminQuickLockScreen> {
  static const _lockoutAfterFails = 5;
  static const _lockoutDuration = Duration(seconds: 30);

  final _pinCtrl = TextEditingController();
  bool _busy = false;
  bool _pinError = false;
  int _failCount = 0;
  DateTime? _lockedUntil;
  Timer? _clock;

  bool get _locked => _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  int get _lockedSeconds =>
      _locked ? _lockedUntil!.difference(DateTime.now()).inSeconds + 1 : 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = context.read<AppProvider>();
      if (app.quickLockBio) _unlockBio(app);
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _unlockBio(AppProvider app) async {
    if (_busy) return;
    setState(() => _busy = true);
    // Probe first so a device whose sensor has nothing enrolled does not get a
    // prompt that is guaranteed to fail. Never throws: every failure leaves the
    // 4-digit PIN and the sign-out fallback reachable.
    final capability = await app.refreshBiometrics();
    if (!mounted) return;
    if (capability != BiometricCapability.available) {
      if (kDebugMode) {
        debugPrint('biometric unlock unavailable: ${biometrics.lastDiagnostic}');
      }
      setState(() => _busy = false);
      return;
    }
    final ok = await app.authenticateBiometric(isArabic: app.isArabic);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) await app.unmarkQuickLocked();
  }

  Future<void> _unlockPin(AppProvider app) async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty || _busy || _locked) return;
    setState(() {
      _busy = true;
      _pinError = false;
    });
    if (app.verifyQuickLockPin(pin)) {
      _clock?.cancel();
      _clock = null;
      _failCount = 0;
      _lockedUntil = null;
      await app.unmarkQuickLocked();
      if (mounted) setState(() => _busy = false);
    } else {
      _failCount += 1;
      _pinCtrl.clear();
      if (_failCount >= _lockoutAfterFails) {
        _lockedUntil = DateTime.now().add(_lockoutDuration);
        _failCount = 0;
        _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          if (_lockedUntil != null && !_locked) {
            _clock?.cancel();
            _clock = null;
          }
          setState(() {});
        });
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _pinError = true;
        });
      }
    }
  }

  Future<void> _signOut(AppProvider app) async {
    app.logout();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;

    return Scaffold(
      backgroundColor: GossColors.navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24 * context.goss.density),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset('assets/logo.png', width: 72, height: 72),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    en ? 'Quick lock' : 'القفل السريع',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    en
                        ? 'Unlock to open the admin panel.'
                        : 'افتح القفل لدخول لوحة الإدارة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                  ),
                  const SizedBox(height: 28),
                  if (app.quickLockBio && app.biometricHardwarePresent) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _busy
                            ? null
                            : () => _unlockBio(app),
                        icon: const Icon(Icons.fingerprint, size: 26),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(en ? 'Unlock with biometrics' : 'فتح بالبصمة / الوش'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ] else if (app.quickLockBio) ...[
                    // Sensor present but unusable: explain it rather than
                    // showing a button that cannot succeed. The PIN and
                    // sign-out paths below stay available either way.
                    const SizedBox(height: 8),
                    Text(
                      BiometricService.messageFor(
                            app.biometricCapability,
                            isArabic: !en,
                          ) ??
                          (en
                              ? 'Biometrics are not available on this device.'
                              : 'البصمة غير متوفرة على هذا الجهاز.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _pinCtrl,
                    obscureText: true,
                    maxLength: 4,
                    enabled: !_locked,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, letterSpacing: 18, fontSize: 22),
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: en ? '4-digit PIN' : 'الرقم السري (4 أرقام)',
                      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                      hintText: '••••',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                      prefixIcon: const Icon(Icons.key, color: Colors.white54),
                      errorText: _locked
                          ? (en
                              ? 'Too many attempts. Retry in $_lockedSeconds s'
                              : 'محاولات كثيرة. أعد المحاولة خلال $_lockedSeconds ثانية')
                          : (_pinError ? (en ? 'Wrong PIN' : 'الرقم السري غير صحيح') : null),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white38),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    onSubmitted: (_) => _unlockPin(app),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_busy || _locked) ? null : () => _unlockPin(app),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(en ? 'Unlock' : 'فتح'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _busy ? null : () => _signOut(app),
                    child: Text(
                      en ? 'Sign out and use the password instead' : 'الخروج واستخدام كلمة المرور',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}