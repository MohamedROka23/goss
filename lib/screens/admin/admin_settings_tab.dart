import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../providers/admin_provider.dart';
import '../../providers/app_provider.dart';
import '../../services/fcm_service.dart';
import 'quick_sign_in_setup_sheet.dart';

/// Admin account settings tab that merges the account-protection features into
/// one place: quick lock (قفل سريع), quick sign-in (الدخول السريع) with
/// fingerprint/passcode and sign out (تسجيل الخروج).
class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  late bool _quickLockEnabled = context.read<AppProvider>().quickLockEnabled;
  late bool _bio = context.read<AppProvider>().quickLockBio;
  bool _bioAvailable = false;
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  String? _error;
  bool _signedOut = false;

  bool _qsBioSupported = false;
  bool _qsEnrolled = false;

  @override
  void initState() {
    super.initState();
    _checkBio();
    _bootQuickSignIn();
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkBio() async {
    var supported = false;
    try {
      supported = await LocalAuthentication().canCheckBiometrics;
    } catch (_) {}
    if (!mounted) return;
    setState(() => _bioAvailable = supported);
  }

  Future<void> _saveQuickLock() async {
    final app = context.read<AppProvider>();
    final en = !app.isArabic;
    setState(() {
      _saving = true;
      _error = null;
    });
    if (!_quickLockEnabled) {
      await app.disableQuickLock();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _pinCtrl.clear();
        _confirmCtrl.clear();
      });
      return;
    }
    final pin = _pinCtrl.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = en ? 'Enter a 4-digit PIN.' : 'أدخل رقماً سرياً من 4 أرقام.';
      });
      _pinCtrl.clear();
      return;
    }
    if (pin != _confirmCtrl.text.trim()) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = en ? 'PINs do not match.' : 'الرقمان غير متطابقين.';
      });
      _confirmCtrl.clear();
      return;
    }
    await app.enableQuickLock(bio: _bio, pin: pin);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _pinCtrl.clear();
      _confirmCtrl.clear();
    });
  }

  Future<void> _bootQuickSignIn() async {
    final app = context.read<AppProvider>();
    var bio = false;
    try {
      bio = await LocalAuthentication().canCheckBiometrics;
    } catch (_) {}
    final enrolled = await app.quickSignInArmed();
    if (!mounted) return;
    setState(() {
      _qsBioSupported = bio;
      _qsEnrolled = enrolled;
    });
  }

  Future<void> _enableQuickSignIn() async {
    final app = context.read<AppProvider>();
    final email = await app.rememberedEmail();
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => QuickSignInSetupSheet(
        initialEmail: email ?? app.adminEmail,
        bioSupported: _qsBioSupported,
        initialBio: _qsBioSupported,
      ),
    );
    if (!mounted) return;
    setState(() => _qsEnrolled = (_qsEnrolled || result == true));
  }

  Future<void> _manageQuickSignIn() async {
    final app = context.read<AppProvider>();
    final email = await app.rememberedEmail();
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => QuickSignInSetupSheet(
        initialEmail: email ?? app.adminEmail,
        preverifiedPassword: null,
        bioSupported: _qsBioSupported,
        initialBio: app.quickSignInBio,
      ),
    );
    if (!mounted) return;
    if (result == true) {
      setState(() => _qsEnrolled = true);
    }
  }

  Future<void> _disableQuickSignIn() async {
    final app = context.read<AppProvider>();
    final en = !app.isArabic;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(en ? 'Disable quick sign-in?' : 'تعطيل الدخول السريع؟'),
        content: Text(
          en
              ? 'The stored email and password will be deleted from this device.'
              : 'سيُحذف الأميل والباسورد المخزّنان من هذا الجهاز.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(en ? 'Cancel' : 'إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: GossColors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(en ? 'Disable' : 'تعطيل'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await app.disarmQuickSignIn();
    if (!mounted) return;
    setState(() => _qsEnrolled = false);
  }

  Future<void> _signOut() async {
    if (_signedOut) return;
    _signedOut = true;
    final context = this.context;
    final app = context.read<AppProvider>();
    app.logout();
    context.read<AdminProvider>().reset();
    FcmService.instance.forgetLoggedInAdmin();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(icon: Icons.lock_outline, title: en ? 'Account lock' : 'قفل الحساب'),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  en
                      ? 'Locks the admin panel with a 4-digit PIN (and optional fingerprint) whenever the app is closed or backgrounded.'
                      : 'يقفل لوحة الإدارة برقم سري من 4 أرقام (وبصمة اختياري) كلما أغلقت التطبيق أو خفّضته للخلفية.',
                  style: const TextStyle(fontSize: 13),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(en ? 'Enable account lock' : 'تفعيل قفل الحساب'),
                  value: _quickLockEnabled,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() {
                            _quickLockEnabled = v;
                            _error = null;
                          }),
                ),
                if (_quickLockEnabled) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(en ? 'Fingerprint / face unlock' : 'الفتح بالبصمة / الوش'),
                    subtitle: _bioAvailable
                        ? null
                        : Text(en ? 'Not available on this device' : 'غير متاح على هذا الجهاز'),
                    value: _bio && _bioAvailable,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() {
                              _bio = v;
                              _error = null;
                            }),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _pinCtrl,
                    obscureText: true,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: en ? 'New 4-digit PIN' : 'رقم سري جديد (4 أرقام)',
                      prefixIcon: const Icon(Icons.key, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmCtrl,
                    obscureText: true,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: en ? 'Confirm PIN' : 'تأكيد الرقم السري',
                      prefixIcon: const Icon(Icons.key, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: GossColors.red, fontSize: 13)),
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: GossColors.red),
                    onPressed: _saving ? null : _saveQuickLock,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(_saving ? (en ? 'Saving...' : 'حفظ...') : (en ? 'Save' : 'حفظ')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _SectionHeader(icon: Icons.fingerprint, title: en ? 'Quick sign-in' : 'الدخول السريع'),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  en
                      ? 'Sign back in from the admin login screen with a fingerprint or a 4-digit passcode, without retyping the password. Credentials are stored encrypted in the device keystore/keychain.'
                      : 'ادخل من شاشة دخول الأدمن ببصمة أو باسكود من 4 أرقام دون كتابة كلمة المرور. البيانات مشفّرة في مخزن الجهاز الآمن (Keystore/Keychain).',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (_qsEnrolled) ...[
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 18, color: GossColors.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          app.quickSignInBio
                              ? (en ? 'Enabled — fingerprint or passcode' : 'مفعّل — بصمة أو باسكود')
                              : (en ? 'Enabled — passcode' : 'مفعّل — باسكود'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(en ? 'Change' : 'تغيير'),
                          onPressed: _manageQuickSignIn,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: GossColors.red),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(en ? 'Disable' : 'تعطيل'),
                          onPressed: _disableQuickSignIn,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.fingerprint),
                    label: Text(en ? 'Enable quick sign-in' : 'تفعيل الدخول السريع'),
                    onPressed: _enableQuickSignIn,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _SectionHeader(icon: Icons.logout, title: en ? 'Session' : 'الجلسة'),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              en
                  ? 'Signing out closes your admin session on this device. Quick lock data is cleared.'
                  : 'تسجيل الخروج يُنهي جلسة الأدمن على هذا الجهاز ويُمسح إعداد قفل الحساب.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: GossColors.red),
          onPressed: _signedOut ? null : _signOut,
          icon: const Icon(Icons.logout),
          label: Text(en ? 'Sign out' : 'تسجيل الخروج'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: GossColors.navy),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}