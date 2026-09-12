import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/backend_manager.dart';

/// Forgot-password recovery sheet: step 1 requests a one-time recovery code
/// that is sent to the registered admin email; step 2 (HTTP backend only)
/// exchanges the code for a new password. In Firebase mode the reset link
/// arrives from Firebase itself so the sheet closes at step 1.
class ForgotPasswordSheet extends StatefulWidget {
  final AppProvider app;
  final bool en;
  const ForgotPasswordSheet({super.key, required this.app, required this.en});

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _step2 = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.app.adminEmail;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = widget.en ? 'Enter a valid email.' : 'أدخل بريداً صحيحاً.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final backend = await BackendManager.resolve();
    final ok = await backend.requestPasswordReset(email);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _loading = false;
        _error = widget.en
            ? 'Could not start recovery — try again shortly.'
            : 'تعذر إرسال الاستعادة — حاول بعد قليل.';
      });
      return;
    }
    if (backend.isFirebase) {
      setState(() {
        _loading = false;
        _info = widget.en
            ? 'Check the recovery e-mail we sent and follow its link to reset your password.'
            : 'افحص بريدك الإلكتروني واتبع الرابط المرسل لإعادة تعيين كلمة المرور.';
      });
      return;
    }
    setState(() {
      _loading = false;
      _step2 = true;
    });
  }

  Future<void> _resetPassword() async {
    final en = widget.en;
    final code = _codeCtrl.text.trim();
    final newPass = _newPassCtrl.text;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (code.length < 6) {
      setState(() {
        _loading = false;
        _error = en ? 'Enter the recovery code from the e-mail.' : 'أدخل كود الاستعادة المرسل لبريدك.';
      });
      return;
    }
    if (newPass.length < 8) {
      setState(() {
        _loading = false;
        _error = en ? 'New password must be at least 8 characters.' : 'كلمة المرور الجديدة 8 أحرف على الأقل.';
      });
      return;
    }
    if (newPass != _confirmCtrl.text) {
      setState(() {
        _loading = false;
        _error = en ? 'Passwords do not match.' : 'كلمتا المرور غير متطابقتين.';
      });
      return;
    }
    final backend = await BackendManager.resolve();
    final ok = await backend.resetPassword(_emailCtrl.text.trim(), code, newPass);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _loading = false;
        _error = en
            ? 'Recovery code is invalid or expired. Request a new one.'
            : 'كود الاستعادة غير صحيح أو منتهي الصلاحية. اطلب واحداً جديداً.';
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final en = widget.en;
    return AlertDialog(
      title: Text(en ? 'Reset password' : 'استعادة كلمة المرور'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_step2) ...[
              Text(
                en
                    ? 'Enter the registered admin email. We will send a recovery message there.'
                    : 'أدخل بريد الأدمن المسجّل وسنرسل إليه رسالة استعادة.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _sendCode(),
                decoration: InputDecoration(
                  hintText: en ? 'Registered admin email' : 'بريد الأدمن المسجّل',
                  prefixIcon: const Icon(Icons.mail_outline, color: GossColors.muted),
                ),
              ),
            ] else ...[
              Text(
                en
                    ? 'A recovery code was sent. Enter it with a new password.'
                    : 'أُرسل كود الاستعادة. أدخله مع كلمة مرور جديدة.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: en ? 'Recovery code' : 'كود الاستعادة',
                  prefixIcon: const Icon(Icons.vpn_key_outlined, color: GossColors.muted),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _newPassCtrl,
                obscureText: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: en ? 'New password (min 8 characters)' : 'كلمة مرور جديدة (8 أحرف على الأقل)',
                  prefixIcon: const Icon(Icons.lock_outline, color: GossColors.muted),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirmCtrl,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _resetPassword(),
                decoration: InputDecoration(
                  hintText: en ? 'Confirm new password' : 'تأكيد كلمة المرور الجديدة',
                  prefixIcon: const Icon(Icons.lock_outline, color: GossColors.muted),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: GossColors.red, fontSize: 13)),
            ],
            if (_info != null) ...[
              const SizedBox(height: 10),
              Text(_info!, style: const TextStyle(color: GossColors.green, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(en ? 'Close' : 'إغلاق'),
        ),
        if (_info == null)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: GossColors.red),
            onPressed: _loading ? null : (_step2 ? _resetPassword : _sendCode),
            child: Text(
              _loading
                  ? (en ? 'Sending...' : 'جاري الإرسال...')
                  : (_step2
                      ? (en ? 'Reset password' : 'إعادة التعيين')
                      : (en ? 'Send code' : 'إرسال الكود')),
            ),
          ),
      ],
    );
  }
}