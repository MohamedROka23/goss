import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/backend_manager.dart';

/// Dialog used to arm quick sign-in (الدخول السريع). When armed, the admin
/// login screen can sign back in with a device passcode or fingerprint.
///
/// Security: the stored credentials go to the platform keystore/keychain only,
/// the passcode is hashed locally, and arming is authorized either by the
/// credentials just used to log in ([preverifiedPassword]) or by re-entering
/// the current admin password (verified against the server).
class QuickSignInSetupSheet extends StatefulWidget {
  final String initialEmail;
  final String? preverifiedPassword;
  final bool initialBio;
  final bool bioSupported;
  const QuickSignInSetupSheet({
    super.key,
    required this.initialEmail,
    this.preverifiedPassword,
    required this.bioSupported,
    this.initialBio = false,
  });

  @override
  State<QuickSignInSetupSheet> createState() => _QuickSignInSetupSheetState();
}

class _QuickSignInSetupSheetState extends State<QuickSignInSetupSheet> {
  late final TextEditingController _emailCtrl = TextEditingController(text: widget.initialEmail);
  final _passwordCtrl = TextEditingController();
  final _passcodeCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  late bool _bio = widget.initialBio && widget.bioSupported;
  bool _saving = false;
  String? _error;

  bool get _needsPassword => widget.preverifiedPassword == null;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passcodeCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = context.read<AppProvider>();
    final en = !app.isArabic;
    setState(() {
      _saving = true;
      _error = null;
    });

    final passcode = _passcodeCtrl.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(passcode)) {
      _fail(en ? 'Enter a 4-digit passcode.' : 'أدخل باسكود من 4 أرقام.');
      return;
    }
    if (passcode != _confirmCtrl.text.trim()) {
      _fail(en ? 'Passcodes do not match.' : 'الباسكودان غير متطابقين.');
      return;
    }

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _fail(en ? 'Enter your admin email.' : 'أدخل بريد الأدمن.');
      return;
    }

    var password = widget.preverifiedPassword;
    if (_needsPassword) {
      final entered = _passwordCtrl.text;
      if (entered.isEmpty) {
        _fail(en ? 'Enter your current admin password.' : 'أدخل كلمة مرور الأدمن الحالية.');
        return;
      }
      final backend = await BackendManager.resolve();
      final ok = await backend.verifyAdminCredentials(email, entered);
      if (!mounted) return;
      if (!ok) {
        _fail(en ? 'Current password is incorrect.' : 'كلمة المرور الحالية غير صحيحة.');
        return;
      }
      password = entered;
    }

    final err = await app.armQuickSignIn(
      email: email,
      password: password!,
      passcode: passcode,
      bio: _bio && widget.bioSupported,
    );
    if (!mounted) return;
    if (err.isNotEmpty) {
      _fail(err);
      return;
    }
    Navigator.of(context).pop(true);
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;

    return AlertDialog(
      title: Text(en ? 'Quick sign-in' : 'الدخول السريع'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              en
                  ? 'Sign back in from the admin login screen with a 4-digit passcode or fingerprint. Credentials are stored encrypted in the device keystore/keychain.'
                  : 'ادخل من جديد من شاشة دخول الأدمن بباسكود من 4 أرقام أو بصمة. تُخزَّن بيانات الدخول مشفّرة في مخزن الجهاز الآمن (Keystore/Keychain).',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              enabled: widget.preverifiedPassword != null
                  ? false
                  : null,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: en ? 'Admin email' : 'بريد الأدمن',
                prefixIcon: const Icon(Icons.mail_outline, color: GossColors.muted),
              ),
            ),
            if (_needsPassword) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: en ? 'Current admin password' : 'كلمة مرور الأدمن الحالية',
                  prefixIcon: const Icon(Icons.lock_outline, color: GossColors.muted),
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _passcodeCtrl,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: en ? '4-digit passcode' : 'باسكود من 4 أرقام',
                prefixIcon: const Icon(Icons.key, size: 20, color: GossColors.muted),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: en ? 'Confirm passcode' : 'تأكيد الباسكود',
                prefixIcon: const Icon(Icons.key, size: 20, color: GossColors.muted),
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(en ? 'Fingerprint / face unlock' : 'الفتح بالبصمة / الوش'),
              subtitle: widget.bioSupported
                  ? null
                  : Text(en ? 'Not available on this device' : 'غير متاح على هذا الجهاز'),
              value: _bio && widget.bioSupported,
              onChanged: _saving
                  ? null
                  : (v) => setState(() {
                        _bio = v;
                        _error = null;
                      }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: GossColors.red, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(en ? 'Cancel' : 'إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: GossColors.red),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? (en ? 'Saving...' : 'حفظ...') : (en ? 'Enable' : 'تفعيل')),
        ),
      ],
    );
  }
}