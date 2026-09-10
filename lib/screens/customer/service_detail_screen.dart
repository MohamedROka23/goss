import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../../app/service_data.dart';
import 'contact_screen.dart';

class ServiceDetailScreen extends StatelessWidget {
  final int index;
  const ServiceDetailScreen({super.key, required this.index});

  Map<String, Object> get _item => logisticsServices[index];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;
    final item = _item;

    return Scaffold(
      appBar: AppBar(
        title: Text(en ? item['e']! as String : item['a']! as String),
        leading: IconButton(
          icon: Icon(
            Directionality.of(context) == TextDirection.rtl ? Icons.arrow_forward : Icons.arrow_back,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(item['image']! as String, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          GossColors.navy.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Text(
                      en ? item['e']! as String : item['a']! as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    en ? item['de']! as String : item['da']! as String,
                    style: TextStyle(color: context.headingColor, fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 20),
                  ...((en ? item['b_e']! : item['b_a']!) as List<String>).map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle, size: 20, color: GossColors.green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              b,
                              style: TextStyle(color: context.headingColor, fontWeight: FontWeight.w600, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.sectionColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      en ? item['p_e']! as String : item['p_a']! as String,
                      style: TextStyle(color: context.mutedColor, height: 1.8, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: GossColors.red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          en ? 'Looking for a reliable logistics partner?' : 'هل تبحث عن شريك لوجستي موثوق؟',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: context.headingColor,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: GossColors.red),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ContactScreen(showBack: true)),
                              );
                            },
                            icon: const Icon(Icons.request_quote),
                            label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                en ? 'Request a Shipping Quote' : 'طلب عرض سعر شحن',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}