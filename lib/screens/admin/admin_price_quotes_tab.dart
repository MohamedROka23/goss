import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/admin_provider.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class AdminPriceQuotesTab extends StatefulWidget {
  const AdminPriceQuotesTab({super.key});

  @override
  State<AdminPriceQuotesTab> createState() => _AdminPriceQuotesTabState();
}

class _AdminPriceQuotesTabState extends State<AdminPriceQuotesTab> {
  bool _showArchive = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final admin = context.watch<AdminProvider>();
    final en = !app.isArabic;

    // Only customer price quotes — never touches accounting data.
    final quotes = admin.requests.where((r) => r.type == 'quote').toList();
    final active = quotes.where((r) => !r.archived && !RequestStatus.isDone(r.status)).toList();
    final archived = quotes.where((r) => r.archived || RequestStatus.isDone(r.status)).toList();
    final list = _showArchive ? archived : active;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                en ? 'Customer price quotes' : '\u0639\u0631\u0648\u0636 \u0627\u0644\u0623\u0633\u0639\u0627\u0631',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.headingColor),
              ),
            ),
            ExportButtons(
              title: en ? 'Price quotes' : '\u0639\u0631\u0648\u0636 \u0627\u0644\u0623\u0633\u0639\u0627\u0631',
              headers: [
                en ? 'Quote No.' : '\u0631\u0642\u0645 \u0627\u0644\u0639\u0631\u0636',
                en ? 'Date' : '\u0627\u0644\u062a\u0627\u0631\u064a\u062e',
                en ? 'Customer' : '\u0627\u0644\u0639\u0645\u064a\u0644',
                en ? 'Company' : '\u0627\u0644\u0634\u0631\u0643\u0629',
                en ? 'Phone' : '\u0627\u0644\u0647\u0627\u062a\u0641',
                en ? 'Items' : '\u0627\u0644\u0623\u0635\u0646\u0627\u0641',
                en ? 'VAT' : '\u0627\u0644\u0636\u0631\u064a\u0628\u0629',
                en ? 'Total' : '\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a',
                en ? 'Status' : '\u0627\u0644\u062d\u0627\u0644\u0629',
              ],
              rows: list.map((r) {
                final sub = r.items.fold<double>(0, (n, i) => n + i.price * i.qty);
                final vat = r.vat ? sub * 0.14 : 0.0;
                return [
                  r.orderLabel,
                  r.createdAt,
                  r.name,
                  r.company,
                  r.phone,
                  r.items.map((i) => '${en ? i.nameEn : i.nameAr} x${i.qty}').join(', '),
                  (en ? 'EGP ' : '\u062c.\u0645 ') + vat.toStringAsFixed(2),
                  (en ? 'EGP ' : '\u062c.\u0645 ') + (sub + vat).toStringAsFixed(2),
                  r.status,
                ];
              }).toList(),
            ),
          ],
        ),
        if (quotes.isNotEmpty) ...[
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.inbox_outlined, size: 16),
                label: Text(en ? 'Active' : '\u0646\u0634\u0637\u0629'),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.archive_outlined, size: 16),
                label: Text(en ? 'Archive' : '\u0623\u0631\u0634\u064a\u0641'),
              ),
            ],
            selected: {_showArchive},
            onSelectionChanged: (s) => setState(() => _showArchive = s.first),
          ),
        ],
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _showArchive
                  ? (en ? 'No archived price quotes.' : '\u0644\u0627 \u062a\u0648\u062c\u062f \u0639\u0631\u0648\u0636 \u0641\u064a \u0627\u0644\u0623\u0631\u0634\u064a\u0641.')
                  : (en ? 'No price quotes yet.' : '\u0644\u0627 \u062a\u0648\u062c\u062f \u0639\u0631\u0648\u0636 \u0623\u0633\u0639\u0627\u0631 \u0628\u0639\u062f.'),
              style: TextStyle(color: context.mutedColor),
            ),
          ),
        ...list.map((r) => _quoteCard(context, admin, app, en, r)),
      ],
    );
  }

  Widget _quoteCard(BuildContext context, AdminProvider admin, AppProvider app, bool en, CustomerRequest r) {
    final sub = r.items.fold<double>(0, (n, i) => n + i.price * i.qty);
    final vat = r.vat ? sub * 0.14 : 0.0;
    final total = sub + vat;

    DateTime? parsed;
    try {
      parsed = DateTime.parse(r.createdAt).toLocal();
    } catch (_) {}
    final dateStr = parsed != null ? DateFormat('yyyy-MM-dd HH:mm').format(parsed) : r.createdAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.orderLabel,
                        style: const TextStyle(
                          color: GossColors.navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${r.name} \u00b7 ${r.company.isEmpty ? (en ? 'No company' : '\u0628\u062f\u0648\u0646 \u0634\u0631\u0643\u0629') : r.company}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, color: context.bodyColor),
                      ),
                      Text('${r.phone} ${r.email}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.mutedColor, fontSize: 13)),
                      Text(dateStr, style: TextStyle(color: context.mutedColor, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                RequestStatusChip(status: r.status, isArabic: !en),
              ],
            ),
            const Divider(height: 18),
            ...r.items.map<Widget>((i) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${en ? i.nameEn : i.nameAr} \u00d7 ${i.qty} ${i.unit} \u2014 ${en ? 'EGP' : '\u062c.\u0645'} ${(i.price * i.qty).toStringAsFixed(2)}',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(fontSize: 13, color: context.bodyColor),
                ),
              );
            }),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(en ? 'Subtotal' : '\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0641\u0631\u0639\u064a', style: TextStyle(color: context.mutedColor, fontSize: 12.5)),
                Text('${en ? 'EGP' : '\u062c.\u0645'} ${sub.toStringAsFixed(2)}', style: TextStyle(fontSize: 12.5, color: context.bodyColor)),
              ],
            ),
            if (r.vat) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(en ? 'VAT 14%' : '\u0627\u0644\u0636\u0631\u064a\u0628\u0629 14%', style: TextStyle(color: context.mutedColor, fontSize: 12.5)),
                  Text('${en ? 'EGP' : '\u062c.\u0645'} ${vat.toStringAsFixed(2)}', style: TextStyle(fontSize: 12.5, color: context.bodyColor)),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(en ? 'Total' : '\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a', style: const TextStyle(fontWeight: FontWeight.w800, color: GossColors.navy, fontSize: 14)),
                Text('${en ? 'EGP' : '\u062c.\u0645'} ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, color: GossColors.navy, fontSize: 14)),
              ],
            ),
            if (r.status == RequestStatus.fresh) ...[
              const SizedBox(height: 10),
              GossButton(
                label: en ? 'Accept quote' : '\u0642\u0628\u0648\u0644 \u0627\u0644\u0639\u0631\u0636',
                color: GossColors.green,
                icon: Icons.check_circle_outline,
                onPressed: app.token != null
                    ? () => admin.updateRequestStatus(app.token!, r.id, RequestStatus.accepted)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}