import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import 'customer/customer_shell.dart';
import 'admin/admin_shell.dart';

/// Entry screen where the user chooses to continue as a customer
/// or to sign in as an administrator.
class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [GossColors.navy, GossColors.navy2],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final body = _buildBody(context, en, compact: constraints.maxHeight < 620);
              return constraints.maxHeight < 620
                  ? SingleChildScrollView(child: body)
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: body,
                    );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool en, {required bool compact}) {
    final app = context.read<AppProvider>();
    final hero = Image.asset('assets/logo.png', width: compact ? 72 : 92, height: compact ? 72 : 92);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (compact) const SizedBox(height: 8) else const Spacer(flex: 1),
        hero,
        SizedBox(height: compact ? 16 : 40),
        Text(
          en ? 'How do you want to continue?' : '\u0643\u064a\u0641 \u062a\u0631\u064a\u062f \u0627\u0644\u062f\u062e\u0648\u0644\u061f',
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        if (compact) const SizedBox(height: 24) else const Spacer(flex: 1),
        _roleCard(
          context,
          icon: Icons.storefront_outlined,
          iconColor: GossColors.blue,
          title: en ? 'Continue as Customer' : '\u0627\u0644\u062f\u062e\u0648\u0644 \u0643\u0639\u0645\u064a\u0644',
          subtitle: en
              ? 'Browse services and request price quotes.'
              : '\u062a\u0635\u0641\u062d \u0627\u0644\u062e\u062f\u0645\u0627\u062a \u0648\u0637\u0644\u0628 \u0639\u0631\u0648\u0636 \u0627\u0644\u0623\u0633\u0639\u0627\u0631.',
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const CustomerShell()),
            );
          },
        ),
        const SizedBox(height: 16),
        _roleCard(
          context,
          icon: Icons.admin_panel_settings_outlined,
          iconColor: GossColors.red,
          title: en ? 'Admin Login' : '\u062a\u0633\u062c\u064a\u0644 \u062f\u062e\u0648\u0644 \u0627\u0644\u0625\u062f\u0627\u0631\u0629',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminShell()),
            );
          },
        ),
        if (compact) const SizedBox(height: 20) else const Spacer(flex: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: app.toggleLanguage,
              icon: const Icon(Icons.translate, color: Colors.white70),
              label: Text(
                en ? '\u0627\u0644\u0639\u0631\u0628\u064a\u0629' : 'English',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: en ? 'Toggle dark mode' : '\u062a\u0628\u062f\u064a\u0644 \u0627\u0644\u0648\u0636\u0639 \u0627\u0644\u062f\u0627\u0643\u0646',
              icon: Icon(
                app.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: Colors.white70,
              ),
              onPressed: app.toggleDarkMode,
            ),
          ],
        ),
        if (compact) const SizedBox(height: 8) else const Spacer(flex: 1),
      ],
    );
  }

  Widget _roleCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 6,
      color: context.isDarkMode ? GossColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: context.headingColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 13, color: context.mutedColor),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left
                    : Icons.chevron_right,
                color: GossColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}