import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../../widgets/widgets.dart';
import 'quick_sign_in_setup_sheet.dart';
import 'forgot_password_sheet.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  // Quick sign-in (الدخول السريع)
  bool _bioAvailable = false;
  bool _enrolled = false;
  bool _remember = false;
  final _qscCtrl = TextEditingController();
  int _qsAttempts = 0;
  bool _qsLockedOut = false;
  String? _qsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final app = context.read<AppProvider>();
    var bio = false;
    try {
      bio = await LocalAuthentication().canCheckBiometrics;
    } catch (_) {}
    final enrolled = await app.quickSignInArmed();
    var email = enrolled ? await app.rememberedEmail() : null;
    if (!mounted) return;
    setState(() {
      _bioAvailable = bio;
      _enrolled = enrolled;
      _remember = enrolled;
      if (email != null && email.trim().isNotEmpty) _emailCtrl.text = email.trim();
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _qscCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/logo.png', width: 72, height: 72),
                const SizedBox(height: 12),
                Text(
                  en ? 'Gosst Admin' : 'إدارة جوست',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.headingColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  en ? 'Welcome back, Gosst team.' : 'أهلاً بك في لوحة إدارة جوست.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedColor, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text(
                  en ? 'Sign in' : 'تسجيل الدخول',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedColor, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (_enrolled) ...[
                  _buildQuickSignInCard(app, en),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: en ? 'Email address' : 'البريد الإلكتروني',
                    prefixIcon: const Icon(Icons.mail_outline, color: GossColors.muted),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  onSubmitted: (_) => _submit(app, en),
                  decoration: InputDecoration(
                    hintText: en ? 'Password' : 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline, color: GossColors.muted),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: Text(
                    en ? 'Remember email & password for quick sign-in' : 'تذكّر الأميل والباسورد للدخول السريع',
                    style: const TextStyle(fontSize: 13),
                  ),
                  value: _remember,
                  onChanged: _loading ? null : (v) => setState(() => _remember = v ?? false),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 20,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 20),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _loading ? null : () => _openForgotPassword(app, en),
                      child: Text(
                        en ? 'Forgot password?' : 'نسيت كلمة المرور؟',
                        style: const TextStyle(fontSize: 13, color: GossColors.blue),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: GossButton(
                    label: en ? 'Sign in' : 'دخول',
                    icon: Icons.login,
                    onPressed: _loading ? null : () => _submit(app, en),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: GossColors.red, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(AppProvider app, bool en) async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _loading = false;
        _error = en ? 'Enter your email and password.' : 'أدخل البريد الإلكتروني وكلمة المرور.';
      });
      return;
    }
    final navigator = Navigator.of(context);
    final ok = await app.loginAdmin(email, password);
    if (!mounted) return;
    if (ok) {
      _qsAttempts = 0;
      _qsLockedOut = false;
      _qsError = null;
      if (_remember) {
        final armed = await _armAfterLogin(navigator, email.trim(), password);
        if (!mounted) return;
        _enrolled = armed || _enrolled;
      } else if (_enrolled) {
        await app.disarmQuickSignIn();
        _enrolled = false;
      }
      setState(() => _loading = false);
    } else {
      setState(() {
        _loading = false;
        _error = app.error ?? (en ? 'Invalid email or password' : 'البريد الإلكتروني أو كلمة المرور غير صحيحة');
      });
    }
  }

  Widget _buildQuickSignInCard(AppProvider app, bool en) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.sectionColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GossColors.blue.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint, color: GossColors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  en ? 'Quick sign-in' : 'الدخول السريع',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            en
                ? 'Unlock with your fingerprint or 4-digit passcode to sign in.'
                : 'افتح ببصمتك أو باسكود من 4 أرقام للدخول.',
            style: TextStyle(fontSize: 12, color: context.mutedColor),
          ),
          if (_bioAvailable && app.quickSignInBio && !_qsLockedOut) ...[
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.fingerprint),
              label: Text(en ? 'Sign in with fingerprint' : 'الدخول بالبصمة'),
              onPressed: _loading ? null : () => _quickSignInByBio(app, en),
            ),
          ],
          if (!_qsLockedOut) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _qscCtrl,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _quickSignInByPasscode(app, en),
              decoration: InputDecoration(
                hintText: en ? '4-digit passcode' : 'الباسكود (4 أرقام)',
                prefixIcon: const Icon(Icons.key, size: 20, color: GossColors.muted),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: GossColors.red),
              onPressed: _loading ? null : () => _quickSignInByPasscode(app, en),
              child: Text(en ? 'Sign in with passcode' : 'الدخول بالباسكود'),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              en
                  ? 'Too many wrong attempts — sign in with your full password.'
                  : 'محاولات خاطئة كثيرة — استخدم كلمة المرور الكاملة.',
              style: const TextStyle(color: GossColors.red, fontSize: 13),
            ),
          ],
          if (_qsError != null && !_qsLockedOut) ...[
            const SizedBox(height: 8),
            Text(_qsError!, style: const TextStyle(color: GossColors.red, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Future<void> _quickSignInByPasscode(AppProvider app, bool en) async {
    final passcode = _qscCtrl.text.trim();
    if (passcode.length != 4) {
      setState(() => _qsError = en ? 'Enter the 4-digit passcode.' : 'أدخل الباسكود من 4 أرقام.');
      return;
    }
    final ok = await app.verifyQuickSignInPasscode(passcode);
    if (!mounted) return;
    if (!ok) {
      _qsAttempts++;
      setState(() {
        _qscCtrl.clear();
        if (_qsAttempts >= 5) {
          _qsLockedOut = true;
          _qsError = null;
        } else {
          _qsError = en ? 'Wrong passcode.' : 'باسكود غير صحيح.';
        }
      });
      return;
    }
    await _performQuickSignIn(en);
  }

  Future<void> _quickSignInByBio(AppProvider app, bool en) async {
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: en ? 'Sign in to the admin panel' : 'الدخول إلى لوحة الأدمن',
        persistAcrossBackgrounding: true,
      );
      if (!mounted || !ok) return;
    } catch (_) {
      if (mounted) setState(() => _qsError = en ? 'Biometrics unavailable.' : 'البصمة غير متاحة.');
      return;
    }
    await _performQuickSignIn(en);
  }

  Future<void> _performQuickSignIn(bool en) async {
    final app = context.read<AppProvider>();
    setState(() {
      _loading = true;
      _qsError = null;
    });
    final email = await app.rememberedEmail();
    final password = await app.rememberedPassword();
    if (!mounted) return;
    if (email == null || password == null) {
      setState(() {
        _loading = false;
        _enrolled = false;
        _qsError = en ? 'Quick sign-in is no longer available. Use your password.' : 'الدخول السريع لم يعد متاحاً. استخدم كلمة المرور.';
      });
      return;
    }
    final ok = await app.loginAdmin(email, password);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (ok) {
        _qsAttempts = 0;
        _qsLockedOut = false;
        _qscCtrl.clear();
        _qsError = null;
      } else {
        _qsError = app.error ?? (en ? 'Quick sign-in failed. Use your password.' : 'فشل الدخول السريع. استخدم كلمة المرور.');
      }
    });
  }

  Future<bool> _armAfterLogin(NavigatorState navigator, String email, String password) async {
    final result = await showDialog<bool>(
      context: navigator.context,
      builder: (_) => QuickSignInSetupSheet(
        initialEmail: email,
        preverifiedPassword: password,
        bioSupported: _bioAvailable,
        initialBio: _bioAvailable,
      ),
    );
    return result ?? false;
  }

  Future<void> _openForgotPassword(AppProvider app, bool en) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ForgotPasswordSheet(app: app, en: en),
    );
  }
}