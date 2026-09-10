import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../../widgets/widgets.dart';
import '../../app/service_data.dart';
import 'service_detail_screen.dart';

class LogisticsScreen extends StatelessWidget {
  const LogisticsScreen({super.key});

  final List<Map<String, Object>> _items = logisticsServices;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;

    return SingleChildScrollView(
      child: Column(
        children: [
          PageHero(
            title: en ? 'Logistics & Shipping Operations' : 'قطاع العمليات اللوجستية والشحن',
            subtitle: en
                ? 'End-to-end supply chain mastery powered by our strategic Alexandria operations hub.'
                : 'إتقان شامل لسلاسل الإمداد، مدعوم بمركز عملياتنا الاستراتيجي في الإسكندرية.',
            isArabic: !en,
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                ..._items.asMap().entries.map(
                  (entry) {
                    final item = entry.value;
                    final i = entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ServiceDetailScreen(index: i),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: GossColors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        item['num']! as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: GossColors.red,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        (en ? item['e']! : item['a']!) as String,
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.headingColor),
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
                                const SizedBox(height: 10),
                                Text(
                                  (en ? item['de']! : item['da']!) as String,
                                  style: TextStyle(color: context.mutedColor, height: 1.6),
                                ),
                                const SizedBox(height: 12),
                                ...((en ? item['b_e']! : item['b_a']!) as List<String>).map(
                                  (b) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.check_circle, size: 18, color: GossColors.green),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(b, style: TextStyle(color: context.mutedColor, height: 1.4)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}