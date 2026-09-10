import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/admin_provider.dart';
import '../../app/theme.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().markRequestsSeen();
      context.read<AppProvider>().markNotificationsSeen();
    });
  }

  String _timeAgo(String? iso, bool en) {
    final t = DateTime.tryParse(iso ?? '');
    if (t == null) return '';
    final diff = DateTime.now().difference(t.toLocal());
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
    final admin = context.watch<AdminProvider>();
    final en = !app.isArabic;

    // New requests (status == 'new', newest first)
    final newRequests = admin.requests
        .where((r) => r.status == 'new')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Price updates sent (broadcast to all customers)
    final priceUpdates = app.notifications
        .where((n) => n.type == 'price_update')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GossColors.navy,
        title: Text(en ? 'Notifications' : 'التنبيهات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            en ? 'New Requests' : 'طلبات جديدة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.headingColor),
          ),
          if (newRequests.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                en ? 'No new requests.' : 'لا توجد طلبات جديدة.',
                style: TextStyle(color: context.mutedColor),
              ),
            ),
          ...newRequests.map((r) => Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: GossColors.blue.withValues(alpha: 0.12),
                    child: const Icon(Icons.person, color: GossColors.blue, size: 20),
                  ),
                  title: Text(
                    '${r.name} \u00b7 ${r.company.isEmpty ? (en ? 'No company' : 'بدون شركة') : r.company}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        en ? '${r.items.length} items' : '${r.items.length} ${r.items.length == 1 ? '\u0639\u0646\u0635\u0631' : '\u0639\u0646\u0627\u0635\u0631'}',
                        style: TextStyle(color: context.mutedColor, fontSize: 13),
                      ),
                      Text(_timeAgo(r.createdAt, en), style: TextStyle(color: context.mutedColor, fontSize: 12)),
                    ],
                  ),
                  isThreeLine: true,
                ),
              )),
          const SizedBox(height: 18),
          Text(
            en ? 'Price Updates Sent' : 'تحديثات الأسعار المُرسلة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.headingColor),
          ),
          if (priceUpdates.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                en ? 'No price updates sent yet.' : 'لم تُرسل تحديثات أسعار بعد.',
                style: TextStyle(color: context.mutedColor),
              ),
            ),
          ...priceUpdates.take(50).map((n) => Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: GossColors.red.withValues(alpha: 0.12),
                    child: const Icon(Icons.price_change, color: GossColors.red, size: 20),
                  ),
                  title: Text(
                    en ? n.productNameEn : n.productNameAr,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        en
                            ? 'EGP ${n.oldPrice.toStringAsFixed(2)} \u2192 EGP ${n.newPrice.toStringAsFixed(2)}'
                            : '${n.oldPrice.toStringAsFixed(2)} ج.م \u2192 ${n.newPrice.toStringAsFixed(2)} ج.م',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(color: context.mutedColor, fontSize: 13),
                      ),
                      Text(_timeAgo(n.createdAt, en), style: TextStyle(color: context.mutedColor, fontSize: 12)),
                    ],
                  ),
                  isThreeLine: true,
                ),
              )),
        ],
      ),
    );
  }
}