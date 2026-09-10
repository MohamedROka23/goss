import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../../services/backend_manager.dart';
import '../../widgets/widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GossColors.navy,
        title: Text(en ? 'Settings' : '\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (BackendManager.firebaseAvailable)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GossColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_done, color: GossColors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        en
                            ? 'Connected to Gosst cloud database.'
                            : '\u0645\u062a\u0635\u0644 \u0628\u0642\u0627\u0639\u062f\u0629 \u0628\u064a\u0627\u0646\u0627\u062a \u062c\u0648\u0633\u062a \u0627\u0644\u0633\u062d\u0627\u0628\u064a\u0629.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    en ? 'Appearance' : '\u0627\u0644\u0645\u0638\u0647\u0631',
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.headingColor, fontSize: 16),
                  ),
                  RadioGroup<ThemeMode>(
                    groupValue: app.themeMode,
                    onChanged: (v) => app.setDarkMode(v ?? ThemeMode.light),
                    child: Column(
                      children: [
                        RadioListTile<ThemeMode>(
                          title: Text(en ? 'Light' : '\u0641\u0627\u062a\u062d'),
                          value: ThemeMode.light,
                        ),
                        RadioListTile<ThemeMode>(
                          title: Text(en ? 'Dark' : '\u062f\u0627\u0643\u0646'),
                          value: ThemeMode.dark,
                        ),
                        RadioListTile<ThemeMode>(
                          title: Text(en ? 'System default' : '\u062a\u0628\u0639 \u0627\u0644\u0646\u0638\u0627\u0645'),
                          subtitle: Text(en
                              ? 'Follow your device theme automatically.'
                              : '\u0627\u062a\u0628\u0627\u0639 \u0645\u0638\u0647\u0631 \u0627\u0644\u062c\u0647\u0627\u0632 \u062a\u0644\u0642\u0627\u0626\u064a\u0627\u064b.'),
                          value: ThemeMode.system,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    en ? 'Language' : '\u0627\u0644\u0644\u063a\u0629',
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.headingColor, fontSize: 16),
                  ),
                  RadioGroup<String>(
                    groupValue: app.langSetting,
                    onChanged: (v) => app.setLanguage(v ?? 'en'),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('English'),
                          value: 'en',
                        ),
                        RadioListTile<String>(
                          title: const Text('\u0627\u0644\u0639\u0631\u0628\u064a\u0629'),
                          value: 'ar',
                        ),
                        RadioListTile<String>(
                          title: Text(en ? 'System default' : '\u062a\u0628\u0639 \u0627\u0644\u0646\u0638\u0627\u0645'),
                          subtitle: Text(en
                              ? 'Follow your device language automatically.'
                              : '\u0627\u062a\u0628\u0627\u0639 \u0644\u063a\u0629 \u0627\u0644\u062c\u0647\u0627\u0632 \u062a\u0644\u0642\u0627\u0626\u064a\u0627\u064b.'),
                          value: 'system',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    en ? 'App' : '\u0627\u0644\u062a\u0637\u0628\u064a\u0642',
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.headingColor, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      Icon(Icons.info_outline, color: GossColors.blue),
                      SizedBox(width: 10),
                      Flexible(child: VersionBadge()),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    en ? 'GOSST — Global Outsourcing Services & Trading.' : 'GOSST — الشركة العالمية لخدمات التعهيد والتجارة.',
                    style: TextStyle(color: context.mutedColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}