import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../../providers/admin_provider.dart';
import 'admin_login_screen.dart';
import 'admin_dashboard.dart';
import 'admin_notifications_screen.dart';
import 'admin_quick_lock_screen.dart';

/// Admin area wrapped in a proper scaffold with a branded app bar. Also hosts
/// the life-cycle observer that engages the quick lock (قفل سريع) whenever the
/// app is backgrounded with a locked session configured.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && mounted) {
      context.read<AppProvider>().markQuickLocked();
    }
  }

  Future<void> _changePassword(BuildContext context, AppProvider app, bool en) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PasswordDialog(app: app, en: en),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GossColors.navy,
        titleSpacing: 0,
        title: Row(
          children: [
            Image.asset('assets/logo.png', width: 34, height: 34),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('GOSST',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Text(
                    en ? 'Admin Panel' : '\u0644\u0648\u062d\u0629 \u0627\u0644\u0625\u062f\u0627\u0631\u0629',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
actions: [
          if (app.isLoggedIn) ...[
            Builder(
              builder: (context) {
                final admin = context.watch<AdminProvider>();
                final unread = admin.unreadRequests;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: en ? 'Notifications' : 'التنبيهات',
                      icon: const Icon(Icons.notifications_none, color: Colors.white),
                      onPressed: () async {
                        await admin.markRequestsSeen();
                        if (!context.mounted) return;
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const AdminNotificationsScreen(),
                        ));
                      },
                    ),
                    if (unread > 0)
                      PositionedDirectional(
                        end: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: const BoxDecoration(color: GossColors.red, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          alignment: Alignment.center,
                          child: Text(
                            '$unread',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            IconButton(
              tooltip: en ? 'Change password' : 'تغيير كلمة المرور',
              icon: const Icon(Icons.lock),
              onPressed: () => _changePassword(context, app, en),
            ),
          ],
        ],
      ),
      body: !app.isLoggedIn
          ? const AdminLoginScreen()
          : (app.quickLockEnabled && app.quickLocked)
              ? const AdminQuickLockScreen()
              : const AdminDashboard(),
    );
  }
}


class _PasswordDialog extends StatefulWidget {
  final AppProvider app;
  final bool en;
  const _PasswordDialog({required this.app, required this.en});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  late final emailCtrl = TextEditingController(text: widget.app.adminEmail);
  final oldCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  String? error;

  @override
  void dispose() {
    emailCtrl.dispose();
    oldCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (newCtrl.text.length < 6) {
      setState(() {
        error = widget.en
            ? 'New password must be at least 6 characters.'
            : 'كلمة المرور الجديدة يجب ألا تقل عن 6 أحرف.';
      });
      return;
    }
    if (newCtrl.text != confirmCtrl.text) {
      setState(() {
        error = widget.en ? 'Passwords do not match.' : 'كلمتا المرور غير متطابقتين.';
      });
      return;
    }
    final err = await widget.app.changeAdminPassword(
      email: emailCtrl.text.trim(),
      oldPassword: oldCtrl.text,
      newPassword: newCtrl.text,
    );
    if (!mounted) return;
    if (err.isNotEmpty) {
      setState(() => error = err);
    } else {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(widget.en ? 'Password changed successfully.' : 'تم تغيير كلمة المرور بنجاح.'),
          backgroundColor: GossColors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.en ? 'Change password' : 'تغيير كلمة المرور'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: widget.en ? 'Email address' : 'البريد الإلكتروني',
                prefixIcon: const Icon(Icons.mail_outline, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: oldCtrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: widget.en ? 'Current password' : 'كلمة المرور الحالية',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: widget.en ? 'New password' : 'كلمة المرور الجديدة',
                prefixIcon: const Icon(Icons.password, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: widget.en ? 'Confirm new password' : 'تأكيد كلمة المرور الجديدة',
                prefixIcon: const Icon(Icons.password, size: 20),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: GossColors.red, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.en ? 'Cancel' : 'إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: GossColors.red),
          onPressed: _submit,
          child: Text(widget.en ? 'Save' : 'حفظ'),
        ),
      ],
    );
  }
}
