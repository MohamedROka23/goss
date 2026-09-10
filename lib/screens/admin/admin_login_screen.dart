import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  int _mode = 0; // 0 = sign in, 1 = register
  String? _loginRole; // null = account default, AdminRole.admin / AdminRole.delegate
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _codeCtrl.dispose();
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
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text(en ? 'Sign in' : 'تسجيل الدخول')),
                    ButtonSegment(value: 1, label: Text(en ? 'Register' : 'تسجيل جديد')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) {
                    setState(() {
                      _mode = s.first;
                      _error = null;
                      _success = null;
                    });
                  },
                ),
                if (_mode == 0) ...[
                  const SizedBox(height: 16),
                  Text(
                    en ? 'Sign in as' : 'تسجيل الدخول كـ',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.mutedColor, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: AdminRole.admin,
                        label: Text(en ? 'Admin' : 'مسؤول'),
                        icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: AdminRole.delegate,
                        label: Text(en ? 'Delegate' : 'مندوب'),
                        icon: const Icon(Icons.support_agent_outlined, size: 18),
                      ),
                    ],
                    selected: {_loginRole ?? AdminRole.admin},
                    onSelectionChanged: (s) {
                      setState(() {
                        _loginRole = s.first;
                        _error = null;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 16),
                if (_mode == 1) ...[
                  TextField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: en ? 'Full name' : 'الاسم الكامل',
                      prefixIcon: const Icon(Icons.person_outline, color: GossColors.muted),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
                if (_mode == 1) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeCtrl,
                    obscureText: true,
                    onSubmitted: (_) => _submit(app, en),
                    decoration: InputDecoration(
                      hintText: en ? 'Admin registration code' : 'كود التسجيل الإداري',
                      prefixIcon: const Icon(Icons.key, color: GossColors.muted),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: GossButton(
                    label: en
                        ? (_mode == 0 ? 'Sign in' : 'Create account & sign in')
                        : (_mode == 0 ? 'دخول' : 'إنشاء حساب والدخول'),
                    icon: _mode == 0 ? Icons.login : Icons.person_add_alt,
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
                if (_success != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _success!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: GossColors.green, fontSize: 13),
                  ),
                ],
                if (_mode == 1) ...[
                  const SizedBox(height: 10),
                  Text(
                    en
                        ? 'The admin registration code is used to confirm new team members.'
                        : 'يُستخدم كود التسجيل الإداري لتأكيد أعضاء الفريق الجدد.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.mutedColor, fontSize: 12),
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
      _success = null;
    });
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _loading = false;
        _error = en ? 'Enter your email and password.' : 'أدخل البريد الإلكتروني وكلمة المرور.';
      });
      return;
    }
    if (_mode == 1) {
      final err = await app.registerAdmin(
        name: _nameCtrl.text.trim().isEmpty ? email : _nameCtrl.text.trim(),
        email: email,
        password: password,
        code: _codeCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (err.isNotEmpty) {
        setState(() => _error = err);
      } else {
        setState(() => _success = en ? 'Account created. Welcome!' : 'تم إنشاء الحساب. أهلاً بك!');
      }
      return;
    }
    final ok = await app.loginAdmin(email, password, role: _loginRole);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      setState(() {
        _error = app.error ?? (en ? 'Invalid email or password' : 'البريد الإلكتروني أو كلمة المرور غير صحيحة');
      });
    }
  }
}