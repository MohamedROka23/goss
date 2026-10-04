import 'package:flutter/material.dart';

import '../../app/icons.dart';
import '../../app/responsive.dart';
import '../../app/spacing.dart';
import '../../app/theme.dart';
import '../../providers/app_provider.dart';

/// Change-password dialog.
///
/// Extracted from the admin shell so the dashboard's own header can present the
/// action directly. Behaviour is unchanged: it validates locally, then delegates
/// to [AppProvider.changeAdminPassword].
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({
    super.key,
    required this.app,
    required this.isEnglish,
  });

  final AppProvider app;
  final bool isEnglish;

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  late final emailCtrl = TextEditingController(text: widget.app.adminEmail);
  final oldCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  String? error;

  bool get en => widget.isEnglish;

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
        error = en
            ? 'New password must be at least 6 characters.'
            : 'كلمة المرور الجديدة يجب ألا تقل عن 6 أحرف.';
      });
      return;
    }
    if (newCtrl.text != confirmCtrl.text) {
      setState(() {
        error = en ? 'Passwords do not match.' : 'كلمتا المرور غير متطابقتين.';
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
          content: Text(
            en
                ? 'Password changed successfully.'
                : 'تم تغيير كلمة المرور بنجاح.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(en ? 'Change password' : 'تغيير كلمة المرور'),
      // The four stacked fields overflow a 320-wide phone dialog, so the
      // content scrolls and the dialog width follows the device.
      insetPadding: EdgeInsets.symmetric(
        horizontal: Insets.md * context.goss.density,
        vertical: Insets.xl,
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: en ? 'Email address' : 'البريد الإلكتروني',
                  prefixIcon: const Icon(AppIcons.mail, size: IconSize.action),
                ),
              ),
              const SizedBox(height: Insets.sm),
              TextField(
                controller: oldCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: en ? 'Current password' : 'كلمة المرور الحالية',
                  prefixIcon: const Icon(AppIcons.lock, size: IconSize.action),
                ),
              ),
              const SizedBox(height: Insets.sm),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: en ? 'New password' : 'كلمة المرور الجديدة',
                  prefixIcon: const Icon(AppIcons.lock, size: IconSize.action),
                ),
              ),
              const SizedBox(height: Insets.sm),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: en
                      ? 'Confirm new password'
                      : 'تأكيد كلمة المرور الجديدة',
                  prefixIcon: const Icon(
                    AppIcons.shield,
                    size: IconSize.action,
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: Insets.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      AppIcons.error,
                      size: IconSize.inline,
                      color: context.dangerColor,
                    ),
                    const SizedBox(width: Insets.xs),
                    Expanded(
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: context.dangerColor,
                          fontSize: TypeScale.caption,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(en ? 'Cancel' : 'إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: Text(en ? 'Save' : 'حفظ')),
      ],
    );
  }
}

/// Opens the change-password dialog.
Future<void> showChangePasswordDialog(
  BuildContext context, {
  required AppProvider app,
  required bool isEnglish,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ChangePasswordDialog(app: app, isEnglish: isEnglish),
  );
}
