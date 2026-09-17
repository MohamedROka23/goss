import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/admin_provider.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

String _fmtDate(String date) {
  try {
    final d = DateTime.parse(date).toLocal();
    return DateFormat('yyyy-MM-dd').format(d);
  } catch (_) {
    return date;
  }
}

class AdminRequestsTab extends StatefulWidget {
  const AdminRequestsTab({super.key});

  @override
  State<AdminRequestsTab> createState() => _AdminRequestsTabState();
}

class _AdminRequestsTabState extends State<AdminRequestsTab> {
  DateTime? _filterDate;
  String? _updatingId;
  bool _showArchive = false;
  final Set<String> _selected = {};

  bool _allSelected(List<CustomerRequest> list) =>
      list.isNotEmpty && list.every((r) => _selected.contains(r.id));

  void _toggleAll(List<CustomerRequest> list) {
    setState(() {
      if (_allSelected(list)) {
        _selected.removeAll(list.map((r) => r.id));
      } else {
        _selected.addAll(list.map((r) => r.id));
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final admin = context.watch<AdminProvider>();
    final en = !app.isArabic;
    final requests = admin.requests;
    final archivedRequests =
        requests.where((r) => r.archived || RequestStatus.isDone(r.status)).toList();
    final activeRequests =
        requests.where((r) => !r.archived && !RequestStatus.isDone(r.status)).toList();
    final base = _showArchive ? archivedRequests : activeRequests;
    final filterStr = _filterDate == null ? null : DateFormat('yyyy-MM-dd').format(_filterDate!);
    final filtered = filterStr == null
        ? base
        : base.where((r) => _fmtDate(r.createdAt) == filterStr).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                en ? 'Incoming requests' : '\u0637\u0644\u0628\u0627\u062a \u0627\u0644\u0639\u0645\u0644\u0627\u0621',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.headingColor),
              ),
            ),
            ExportButtons(
              title: en ? 'Requests' : '\u0627\u0644\u0637\u0644\u0628\u0627\u062a',
              headers: [
                en ? 'Date' : '\u0627\u0644\u062a\u0627\u0631\u064a\u062e',
                en ? 'Customer' : '\u0627\u0644\u0639\u0645\u064a\u0644',
                en ? 'Company' : '\u0627\u0644\u0634\u0631\u0643\u0629',
                en ? 'Phone' : '\u0627\u0644\u0647\u0627\u062a\u0641',
                en ? 'Origin' : '\u0645\u0646',
                en ? 'Destination' : '\u0627\u0644\u0648\u062c\u0647\u0629',
                en ? 'Items' : '\u0627\u0644\u0623\u0639\u0646\u0627\u0635',
                en ? 'Status' : '\u0627\u0644\u062d\u0627\u0644\u0629',
              ],
              rows: filtered.map((r) => [
                _fmtDate(r.createdAt),
                r.name,
                r.company,
                r.phone,
                r.origin,
                r.destination,
                r.items.map((i) => '${en ? i.nameEn : i.nameAr} x${i.qty}').join(', '),
                r.status,
              ]).toList(),
            ),
          ],
        ),
        if (requests.isNotEmpty) ...[
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
            onSelectionChanged: (s) => setState(() {
              _showArchive = s.first;
              _selected.clear();
            }),
          ),
          if (_showArchive) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _allSelected(filtered),
                  onChanged: (_) => _toggleAll(filtered),
                ),
                Text(en ? 'Select all' : 'تحديد الكل'),
                const Spacer(),
                if (_selected.isNotEmpty) ...[
                  Text('${_selected.length}'),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _bulkDelete(app, admin, en),
                    style: OutlinedButton.styleFrom(foregroundColor: GossColors.red),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(en ? 'Delete' : 'حذف'),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    filterStr ?? (en ? 'Search by date' : '\u0628\u062d\u062b \u0628\u0627\u0644\u062a\u0627\u0631\u064a\u062e'),
                  ),
                ),
              ),
              if (filterStr != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: en ? 'Clear date filter' : '\u0645\u0633\u062d \u0641\u0644\u062a\u0631 \u0627\u0644\u062a\u0627\u0631\u064a\u062e',
                  onPressed: () => setState(() => _filterDate = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ],
          ),
        ],
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              filterStr != null
                  ? (en ? 'No requests on this date.' : '\u0644\u0627 \u062a\u0648\u062c\u062f \u0637\u0644\u0628\u0627\u062a \u0641\u064a \u0647\u0630\u0627 \u0627\u0644\u062a\u0627\u0631\u064a\u062e.')
                  : (_showArchive
                      ? (en ? 'No archived requests.' : '\u0644\u0627 \u062a\u0648\u062c\u062f \u0637\u0644\u0628\u0627\u062a \u0641\u064a \u0627\u0644\u0623\u0631\u0634\u064a\u0641.')
                      : (en ? 'No requests yet.' : '\u0644\u0627 \u062a\u0648\u062c\u062f \u0637\u0644\u0628\u0627\u062a \u0628\u0639\u062f.')),
              style: TextStyle(color: context.mutedColor),
            ),
          ),
        ...filtered.map((r) => _requestCard(context, app, admin, en, r,
            showCheck: _showArchive,
            selected: _selected.contains(r.id),
            onToggle: () => setState(() {
              if (_selected.contains(r.id)) {
                _selected.remove(r.id);
              } else {
                _selected.add(r.id);
              }
            }))),
      ],
    );
  }

  Future<void> _bulkDelete(AppProvider app, AdminProvider admin, bool en) async {
    if (_selected.isEmpty) return;
    final ids = _selected.toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(en ? 'Delete requests' : 'حذف الطلبات'),
        content: Text(en
            ? 'Permanently delete ${ids.length} request(s) from the archive? This cannot be undone.'
            : 'حذف نهائي لـ ${ids.length} طلباً من الأرشيف؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(en ? 'Cancel' : 'إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: GossColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(en ? 'Delete' : 'حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await admin.deleteRequests(app.token!, ids);
    if (!mounted) return;
    setState(() => _selected.clear());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(en ? 'Requests deleted.' : 'تم حذف الطلبات.'),
      backgroundColor: GossColors.red,
    ));
  }

  Widget _requestCard(BuildContext context, AppProvider app, AdminProvider admin, bool en,
      CustomerRequest r, {required bool showCheck, required bool selected, required VoidCallback onToggle}) {
    final date = r.createdAt;
    DateTime? parsed;
    try {
      parsed = DateTime.parse(date);
    } catch (_) {}
    final dateStr = parsed != null ? DateFormat('yyyy-MM-dd HH:mm').format(parsed) : date;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showCheck)
                  Checkbox(value: selected, onChanged: (_) => onToggle()),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.name} \u00b7 ${r.company.isEmpty ? (en ? 'No company' : '\u0628\u062f\u0648\u0646 \u0634\u0631\u0643\u0629') : r.company}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, color: context.bodyColor),
                      ),
                      Text(
                        r.orderLabel,
                        style: TextStyle(
                          color: GossColors.navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      Text('${r.phone} ${r.email}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.mutedColor, fontSize: 13)),
                      Text(dateStr, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.mutedColor, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (RequestStatus.isFrozen(r.status))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: requestStatusColor(r.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      r.status == RequestStatus.confirmed ? Icons.lock_outline : Icons.cancel_outlined,
                      size: 17,
                      color: requestStatusColor(r.status),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            requestStatusLabel(r.status, ar: !en),
                            style: TextStyle(color: requestStatusColor(r.status), fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          Text(
                            en ? 'Sealed — cannot be changed.' : 'مغلق — لا يمكن تغييره.',
                            style: TextStyle(color: context.mutedColor, fontSize: 12, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FractionallySizedBox(
                      widthFactor: 0.55,
                      child: DropdownButton<String>(
                        value: requestStatusValues.contains(r.status) ? r.status : RequestStatus.fresh,
                        isExpanded: true,
                        onChanged: (v) {
                          if (v != null && app.token != null) {
                            setState(() => _updatingId = r.id);
                            admin.updateRequestStatus(app.token!, r.id, v).whenComplete(() {
                              if (mounted) setState(() => _updatingId = null);
                            });
                          }
                        },
                        items: requestStatusValues
                            .where((s) => !RequestStatus.isFrozen(s))
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    requestStatusLabel(s, ar: !en),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: requestStatusColor(s), fontWeight: FontWeight.w700),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                  if (_updatingId == r.id) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            const Divider(height: 16),
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
            if (r.origin.isNotEmpty || r.destination.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: GossColors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 16, color: GossColors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        en
                            ? '${r.origin.isEmpty ? 'Origin unspecified' : r.origin} → ${r.destination.isEmpty ? 'Destination unspecified' : r.destination}'
                            : 'من ${r.origin.isEmpty ? 'غير محددة' : r.origin} إلى ${r.destination.isEmpty ? 'غير محددة' : r.destination}',
                        style: TextStyle(fontSize: 12.5, color: context.bodyColor, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (r.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.notes, style: TextStyle(color: context.mutedColor)),
            ],
            if (r.status == RequestStatus.rejected) ...[
              const SizedBox(height: 10),
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
                            ? 'The customer rejected this delivery. The order is now sealed — contact the customer directly to resolve it.'
                            : 'قام العميل برفض هذا التسليم. تم إغلاق هذا الطلب نهائياً — تواصل مع العميل مباشرة لحل الأمر.',
                        style: TextStyle(fontSize: 12.5, color: context.bodyColor, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (r.status == RequestStatus.fresh) ...[
              const SizedBox(height: 10),
              GossButton(
                label: en ? 'Accept order' : '\u0642\u0628\u0648\u0644 \u0627\u0644\u0637\u0644\u0628',
                color: GossColors.green,
                icon: Icons.check_circle_outline,
                onPressed: r.status == RequestStatus.fresh && app.token != null
                    ? () => admin.updateRequestStatus(app.token!, r.id, RequestStatus.accepted)
                    : null,
              ),
            ],
            if (r.status == RequestStatus.confirmed) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.verified, color: GossColors.green, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      en ? 'Delivery confirmed by customer' : '\u062a\u0645 \u062a\u0623\u0643\u064a\u062f \u0627\u0644\u062a\u0633\u0644\u064a\u0645 \u0645\u0646 \u0627\u0644\u0639\u0645\u064a\u0644',
                      style: const TextStyle(color: GossColors.green, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}