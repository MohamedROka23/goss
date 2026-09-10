import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().markNotificationsSeen();
    });
  }

  String _timeAgo(String? iso, bool en, BuildContext context) {
    final t = DateTime.tryParse(iso ?? '');
    if (t == null) return '';
    final now = DateTime.now();
    final diff = now.difference(t.toLocal());
    if (diff.inMinutes < 1) return en ? 'Just now' : 'الآن';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return en ? '$m min ago' : 'منذ $m دقيقة';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return en ? '$h hour${h == 1 ? '' : 's'} ago' : 'منذ $h ساعة';
    }
    final d = diff.inDays;
    return en ? '$d day${d == 1 ? '' : 's'} ago' : 'منذ $d يوم';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;

    final list = app.notifications.where((n) => n.type == 'price_update').toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GossColors.navy,
        title: Text(en ? 'Price updates' : 'تنبيهات عروض الأسعار'),
      ),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  en ? 'No quote updates yet.\nYou will be notified here when Gosst updates a price.' : 'لا توجد تحديثات أسعار بعد.\nسيصلك تنبيه هنا عند قيام جوست بتعديل أي سعر.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedColor, fontSize: 14, height: 1.6),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final n = list[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: GossColors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.price_change, color: GossColors.red),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                en ? n.productNameEn : n.productNameAr,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                en
                                    ? 'Price changed from EGP ${n.oldPrice.toStringAsFixed(2)} to EGP ${n.newPrice.toStringAsFixed(2)}'
                                    : 'تم تعديل السعر من ${n.oldPrice.toStringAsFixed(2)} ج.م إلى ${n.newPrice.toStringAsFixed(2)} ج.م',
                                textDirection: TextDirection.ltr,
                                style: TextStyle(color: context.mutedColor, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${n.unit}  •  ${_timeAgo(n.createdAt, en, context)}',
                                style: TextStyle(color: context.mutedColor, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}