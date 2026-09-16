import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/admin_provider.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

/// Tracking orders: shows every request with the full stage timeline so the
/// admin/delegate can follow the exact journey the customer sees.
class AdminTrackingTab extends StatefulWidget {
  const AdminTrackingTab({super.key});

  @override
  State<AdminTrackingTab> createState() => _AdminTrackingTabState();
}

class _AdminTrackingTabState extends State<AdminTrackingTab> {
  DateTime? _filterDate;
  bool _showArchive = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _dateStr(String date) {
    try {
      return DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(date).toLocal());
    } catch (_) {
      return date;
    }
  }

  String _dayStr(String date) {
    try {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(date).toLocal());
    } catch (_) {
      return date;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _filterDate = d);
  }

  int _stageStep(String status) {
    final idx = RequestStatus.stages.indexOf(status);
    if (idx >= 0) return idx;
    if (status == RequestStatus.rejected) {
      return RequestStatus.stages.indexOf(RequestStatus.delivering);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final admin = context.watch<AdminProvider>();
    final en = !app.isArabic;
    final requests = admin.requests;
    final baseList = _showArchive
        ? requests.where((r) => r.archived || RequestStatus.isDone(r.status)).toList()
        : requests.where((r) => !r.archived && !RequestStatus.isDone(r.status)).toList();
    final filterStr = _filterDate == null ? null : DateFormat('yyyy-MM-dd').format(_filterDate!);
    final query = _search.text.trim().toLowerCase();
    final filtered = baseList.where((r) {
      final dateOk = filterStr == null || _dayStr(r.createdAt) == filterStr;
      final searchOk = query.isEmpty ||
          r.name.toLowerCase().contains(query) ||
          r.company.toLowerCase().contains(query) ||
          r.phone.toLowerCase().contains(query) ||
          r.orderLabel.toLowerCase().contains(query) ||
          r.id.toLowerCase().contains(query);
      return dateOk && searchOk;
    }).toList();

    return RefreshIndicator(
      onRefresh: () => admin.loadRequests(app.token!),
      child: requests.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 100),
                    const Icon(Icons.route_outlined, size: 64, color: GossColors.navy2),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        en
                            ? 'No orders to track yet. New requests will appear here with their live stages.'
                            : 'لا توجد طلبات للتتبع بعد. ستظهر الطلبات الجديدة هنا مع مراحلها لحظة بلحظة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.mutedColor),
                      ),
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
Text(
                      en
                          ? 'Follow every order stage in real time.'
                          : '\u062a\u0627\u0628\u0639 \u0645\u0631\u0627\u062d\u0644 \u0643\u0644 \u0637\u0644\u0628 \u0644\u062d\u0638\u0629 \u0628\u0644\u062d\u0638\u0629.',
                      style: TextStyle(color: context.mutedColor, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(en ? 'Active' : '\u0646\u0634\u0637\u0629'),
                          icon: const Icon(Icons.route_outlined, size: 18),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(en ? 'Archive (delivered)' : '\u0623\u0631\u0634\u064a\u0641 (\u0627\u0644\u0645\u0633\u0644\u0645)'),
                          icon: const Icon(Icons.archive_outlined, size: 18),
                        ),
                      ],
                      selected: {_showArchive},
                      onSelectionChanged: (s) => setState(() => _showArchive = s.first),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: en ? 'Search by customer name, company or order number...' : '\u0627\u0628\u062d\u062b \u0628\u0627\u0633\u0645 \u0627\u0644\u0639\u0645\u064a\u0644 \u0623\u0648 \u0627\u0644\u0634\u0631\u0643\u0629 \u0623\u0648 \u0631\u0642\u0645 \u0627\u0644\u0637\u0644\u0628...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              filterStr ?? (en ? 'Search by date' : 'بحث بالتاريخ'),
                            ),
                          ),
                        ),
                        if (filterStr != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: en ? 'Clear date filter' : 'مسح فلتر التاريخ',
                            onPressed: () => setState(() => _filterDate = null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            _search.text.trim().isNotEmpty
                                ? (en ? 'No orders match your search.' : '\u0644\u0627 \u062a\u0648\u062c\u062f \u0637\u0644\u0628\u0627\u062a \u062a\u0637\u0627\u0628\u0642 \u0628\u062d\u062b\u0643.')
                                : (filterStr != null
                                    ? (en ? 'No orders on this date.' : '\u0644\u0627 \u062a\u0648\u062c\u062f \u0637\u0644\u0628\u0627\u062a \u0641\u064a \u0647\u0630\u0627 \u0627\u0644\u062a\u0627\u0631\u064a\u062e.')
                                    : (en ? 'No orders to show.' : '\u0644\u0627 \u062a\u0648\u062c\u062f \u0637\u0644\u0628\u0627\u062a.')),
                            style: TextStyle(color: context.mutedColor),
                          ),
                        ),
                      ),
                    ...filtered.map((r) => _trackingCard(context, en, r)),
                  ],
                ),
    );
  }

  Widget _trackingCard(BuildContext context, bool en, CustomerRequest r) {
    final step = _stageStep(r.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.name} \u00b7 ${r.company.isEmpty ? (en ? 'No company' : '\u0628\u062f\u0648\u0646 \u0634\u0631\u0643\u0629') : r.company}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: context.bodyColor),
                      ),
                      Text(
                        '${en ? 'Order' : '\u0637\u0644\u0628'} ${r.orderLabel} \u00b7 ${_dateStr(r.createdAt)}',
                        style: TextStyle(color: context.mutedColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                RequestStatusChip(status: r.status, isArabic: !en),
              ],
            ),
            const Divider(height: 20),
            Text(
              en ? 'Order journey' : '\u062e\u0637 \u0633\u064a\u0631 \u0627\u0644\u0637\u0644\u0628',
              style: TextStyle(fontWeight: FontWeight.w700, color: context.headingColor, fontSize: 13),
            ),
            const SizedBox(height: 12),
            RequestStatusTimeline(step: step),
            const SizedBox(height: 8),
            Center(
              child: Text(
                requestStatusLabel(r.status, ar: !en),
                style: TextStyle(color: requestStatusColor(r.status), fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
            if (r.status == RequestStatus.rejected) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: GossColors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cancel_outlined, size: 18, color: GossColors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        en
                            ? 'The customer rejected this delivery. Follow up with them to resolve it.'
                            : 'قام العميل برفض هذا التسليم. تواصل معه لحل الأمر.',
                        style: TextStyle(fontSize: 12.5, color: context.bodyColor, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (r.phone.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '${en ? 'Phone' : '\u0647\u0627\u062a\u0641'}: ${r.phone}',
                style: TextStyle(fontSize: 13, color: context.bodyColor),
              ),
            ],
            if (r.items.isNotEmpty) ...[
              const Divider(height: 22),
              Text(
                en ? 'Items' : '\u0627\u0644\u0623\u0635\u0646\u0627\u0641',
                style: TextStyle(fontWeight: FontWeight.w700, color: context.headingColor, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ...r.items.map((i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${en ? i.nameEn : i.nameAr} \u00d7 ${i.qty} ${i.unit} \u2014 ${en ? 'EGP' : '\u062c.\u0645'} ${(i.price * i.qty).toStringAsFixed(2)}',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(fontSize: 13, color: context.bodyColor),
                ),
              )),
            ],
            if (r.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.notes, style: TextStyle(color: context.mutedColor)),
            ],
          ],
        ),
      ),
    );
  }
}