import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../../widgets/widgets.dart';

class ContactScreen extends StatelessWidget {
  final bool showBack;
  const ContactScreen({super.key, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;

    final content = SingleChildScrollView(
      child: Column(
        children: [
          PageHero(
            title: en ? 'Contact Us' : '\u062a\u0648\u0627\u0635\u0644 \u0645\u0639\u0646\u0627',
            subtitle: en
                ? 'Reach our experts for customized logistics and supply solutions.'
                : 'تواصل مع خبرائنا للحصول على حلول لوجستية وتوريدات مخصصة.',
            isArabic: !en,
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(
                  title: en ? 'Contact Information' : 'معلومات الاتصال',
                  isArabic: !en,
                ),
                const SizedBox(height: 12),
                _contactCard(
                  context,
                  icon: Icons.location_on,
                  title: en ? 'Main Headquarters' : 'المركز الرئيسي',
                  value: en
                      ? 'Alexandria, Egypt - Main Operations Center'
                      : 'الإسكندرية، مصر - المركز الرئيسي للعمليات',
                ),
                const SizedBox(height: 12),
                _contactCard(
                  context,
                  icon: Icons.phone,
                  iconColor: GossColors.blue,
                  title: en ? 'Phone Number' : 'رقم الهاتف',
                  value: '+20 10 11428818',
                  onTap: () => _call(context, '+201011428818'),
                ),
                const SizedBox(height: 12),
                _contactCard(
                  context,
                  icon: Icons.chat,
                  iconColor: GossColors.green,
                  title: en ? 'WhatsApp' : '\u0648\u0627\u062a\u0633\u0627\u0628',
                  value: '+20 10 11428818',
                  onTap: () => _whatsApp(context, '201011428818'),
                ),
                const SizedBox(height: 12),
                _contactCard(
                  context,
                  icon: Icons.email,
                  title: en ? 'Email Address' : 'البريد الإلكتروني',
                  value: 'Info@gossts.com',
                  onTap: () => _email(context, 'Info@gossts.com'),
                ),
                const SizedBox(height: 24),
                SectionTitle(
                  title: en ? 'Send us a message' : '\u0623\u0631\u0633\u0644 \u0644\u0646\u0627 \u0631\u0633\u0627\u0644\u0629',
                  isArabic: !en,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GossButton(
                        label: en ? 'Call' : '\u0627\u062a\u0635\u0627\u0644',
                        color: GossColors.blue,
                        icon: Icons.phone,
                        onPressed: () => _call(context, '+201011428818'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GossButton(
                        label: en ? 'WhatsApp' : '\u0648\u0627\u062a\u0633\u0627\u0628',
                        color: GossColors.green,
                        icon: Icons.chat,
                        onPressed: () => _whatsApp(context, '201011428818'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: GossButton(
                    label: en ? 'Send an email' : '\u0625\u0631\u0633\u0627\u0644 \u0628\u0631\u064a\u062f \u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a',
                    color: GossColors.red,
                    icon: Icons.email,
                    onPressed: () => _email(context, 'Info@gossts.com'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!showBack) return content;
    return Scaffold(
      appBar: AppBar(
        title: Text(en ? 'Contact Us' : '\u062a\u0648\u0627\u0635\u0644 \u0645\u0639\u0646\u0627'),
        leading: IconButton(
          icon: Icon(
            Directionality.of(context) == TextDirection.rtl ? Icons.arrow_forward : Icons.arrow_back,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: content,
    );
  }

  Future<void> _launchFirst(BuildContext context, List<Uri> uris, String fallback) async {
    final messenger = ScaffoldMessenger.of(context);
    for (final uri in uris) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {
        // Try the next fallback.
      }
    }
    messenger.showSnackBar(SnackBar(content: Text(fallback)));
  }

  Future<void> _call(BuildContext context, String phone) async {
    final en = context.read<AppProvider>().isArabic == false;
    final formatted = phone.replaceAllMapped(
      RegExp(r'(\+?20)(\d{2})(\d{4})(\d{4})'),
      (m) => '${m[1]} ${m[2]} ${m[3]} ${m[4]}',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(en ? 'Call Gosst' : 'الاتصال بجوست'),
        content: Text(
          formatted,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: phone));
              if (context.mounted) Navigator.pop(context, false);
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(en ? 'Cancel' : 'إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.phone, size: 16),
            label: Text(en ? 'Call' : 'اتصال'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _launchFirst(context, [Uri.parse('tel:$phone')], en ? 'No phone app found.' : 'لا يوجد تطبيق اتصال.');
    }
  }

  Future<void> _whatsApp(BuildContext context, String number) async {
    final en = context.read<AppProvider>().isArabic == false;
    final message = Uri.encodeComponent(en
        ? 'Hello Gosst, I would like to inquire about your services'
        : 'مرحباً جوست، أرغب في الاستفسار عن خدماتكم');
    final deepUri = Uri.parse('whatsapp://send?phone=$number&text=$message');
    final webUri = Uri.parse('https://wa.me/$number?text=$message');
    await _launchFirst(
      context,
      [deepUri, webUri],
      en ? 'WhatsApp is not available on this device.' : 'الواتساب غير متاح على هذا الجهاز.',
    );
  }

  Future<void> _email(BuildContext context, String address) async {
    final en = context.read<AppProvider>().isArabic == false;
    await _launchFirst(
      context,
      [Uri.parse('mailto:$address')],
      en ? 'No email app found.' : 'لا يوجد تطبيق بريد إلكتروني.',
    );
  }

  Widget _contactCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: (iconColor ?? GossColors.red).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor ?? GossColors.red, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 13, color: context.mutedColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.headingColor),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
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