import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../models/models.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/app_provider.dart';
import '../../../services/accounting.dart';
import '../../../widgets/widgets.dart';

/// Customer receivables: invoices per order, balances and payment recording.
class AccountingReceivablesScreen extends StatefulWidget {
  const AccountingReceivablesScreen({super.key});

  @override
  State<AccountingReceivablesScreen> createState() => _AccountingReceivablesScreenState();
}

class _AccountingReceivablesScreenState extends State<AccountingReceivablesScreen> {
  bool _showArchive = false;
  final Set<String> _selected = {};

  String _fmt(String date) {
    try {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(date).toLocal());
    } catch (_) {
      return date;
    }
  }

  List<Payment> _filteredPayments(List<Payment> all, List<Receivable> visible) {
    final ids = visible.map((r) => r.request.id).toSet();
    return all.where((p) => ids.contains(p.requestId)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final admin = context.watch<AdminProvider>();
    final en = !app.isArabic;

    final receivables = buildReceivables(
      requests: admin.requests,
      payments: admin.payments,
    );
    final activeReceivables = receivables.where((r) => r.balance > 0).toList();
    final archivedReceivables = receivables.where((r) => r.balance <= 0).toList();
    final visibleReceivables = _showArchive ? archivedReceivables : activeReceivables;
    final history = _filteredPayments(admin.payments, visibleReceivables);
    var totalInvoices = 0.0;
    var totalCollected = 0.0;
    var totalOutstanding = 0.0;
    for (final r in receivables) {
      totalInvoices += r.invoice;
      totalCollected += r.paid;
      if (r.balance > 0) totalOutstanding += r.balance;
    }

    final headers = [
      en ? 'Order' : 'الطلب',
      en ? 'Customer' : 'العميل',
      en ? 'Invoice' : 'الفاتورة',
      en ? 'Paid' : 'المدفوع',
      en ? 'Balance' : 'المتبقي',
    ];
    final rows = receivables.map((r) => [
          r.request.orderLabel,
          r.request.company.isEmpty ? r.request.name : r.request.company,
          r.invoice.toStringAsFixed(2),
          r.paid.toStringAsFixed(2),
          r.balance.toStringAsFixed(2),
        ]).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(en ? 'Receivables & payments' : 'الذمم والمدفوعات'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ExportButtons(
              title: 'GOSST ${en ? 'Receivables' : 'الذمم'}',
              headers: headers,
              rows: rows,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _chip(en ? 'Invoices' : 'الفواتير', totalInvoices, GossColors.navy, en)),
              const SizedBox(width: 8),
              Expanded(child: _chip(en ? 'Collected' : 'محصل', totalCollected, GossColors.green, en)),
              const SizedBox(width: 8),
              Expanded(child: _chip(en ? 'Balance' : 'المتبقي', totalOutstanding, GossColors.red, en)),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(en ? 'Outstanding' : 'نشطة'),
                icon: const Icon(Icons.list_alt, size: 18),
              ),
              ButtonSegment(
                value: true,
                label: Text(en ? 'Fully paid' : 'مدفوعة (أرشيف)'),
                icon: const Icon(Icons.archive_outlined, size: 18),
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
            _ArchiveToolbar(
              en: en,
              count: visibleReceivables.length,
              selectedCount: _selected.length,
              allSelected: visibleReceivables
                  .where((r) => !_selected.contains(r.request.id))
                  .isEmpty,
              onToggleAll: () {
                setState(() {
                  if (visibleReceivables
                      .where((r) => !_selected.contains(r.request.id))
                      .isEmpty) {
                    for (final r in visibleReceivables) {
                      _selected.remove(r.request.id);
                    }
                  } else {
                    for (final r in visibleReceivables) {
                      _selected.add(r.request.id);
                    }
                  }
                });
              },
              onDelete: () => _bulkDeleteArchived(app, admin, en),
            ),
          ],
          const SizedBox(height: 12),

          if (visibleReceivables.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  _showArchive
                      ? (en ? 'No fully paid invoices' : 'لا توجد فواتير مدفوعة بالكامل')
                      : (en ? 'No outstanding invoices' : 'لا توجد فواتير متأخرة'),
                  style: TextStyle(color: context.mutedColor),
                ),
              ),
            ),

          ...visibleReceivables.map((r) => _receivableCard(app, admin, en, r)),

          const SizedBox(height: 20),
          Text(en ? 'Payment history' : 'سجل المدفوعات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.headingColor)),
          const SizedBox(height: 8),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  _showArchive
                      ? (en ? 'No payments for fully paid invoices.' : 'لا توجد مدفوعات للفواتير المدفوعة.')
                      : (en ? 'No payments for outstanding invoices.' : 'لا توجد مدفوعات للفواتير المتأخرة.'),
                  style: TextStyle(color: context.mutedColor),
                ),
              ),
            )
          else
            ...history.map((p) => _paymentRow(app, admin, en, p)),
        ],
      ),
    );
  }

  Widget _chip(String label, double value, Color color, bool en) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 4),
            Text('${en ? 'EGP' : 'ج.م'} ${value.toStringAsFixed(0)}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _receivableCard(AppProvider app, AdminProvider admin, bool en, Receivable r) {
    final balance = r.balance;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => _openInvoice(app, admin, en, r),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (_showArchive)
                Checkbox(
                  value: _selected.contains(r.request.id),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected.add(r.request.id);
                    } else {
                      _selected.remove(r.request.id);
                    }
                  }),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.request.orderLabel}  •  ${r.request.company.isEmpty ? r.request.name : r.request.company}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('${en ? 'Invoice' : 'الفاتورة'}: ${r.invoice.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 12, color: context.mutedColor)),
                        const SizedBox(width: 10),
                        Text('${en ? 'Paid' : 'المدفوع'}: ${r.paid.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 12, color: context.mutedColor)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${en ? 'EGP' : 'ج.م'} ${balance.toStringAsFixed(2)}',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: balance > 0 ? GossColors.red : GossColors.green)),
                  if (balance > 0)
                    Text(en ? 'Outstanding' : 'متبقي',
                        style: const TextStyle(color: GossColors.red, fontSize: 11)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: en ? 'Move to archive' : 'نقل إلى الأرشيف',
                    icon: const Icon(Icons.archive_outlined, size: 18, color: GossColors.red),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _archiveReceivable(app, admin, en, r),
                  ),
                  IconButton(
                    tooltip: en ? 'Open invoice' : 'فتح الفاتورة',
                    icon: const Icon(Icons.chevron_right, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _archiveReceivable(AppProvider app, AdminProvider admin, bool en, Receivable r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(en ? 'Move to archive' : 'نقل إلى الأرشيف'),
        content: Text(en
            ? 'Archive ${r.request.orderLabel} for ${r.request.company.isEmpty ? r.request.name : r.request.company}? The order stays available under archive.'
            : 'أرشفة ${r.request.orderLabel} لـ ${r.request.company.isEmpty ? r.request.name : r.request.company}؟ سيبقى الطلب متاحاً داخل الأرشيف.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(en ? 'Cancel' : 'إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: GossColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(en ? 'Archive' : 'أرشفة'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await admin.archiveRequest(app.token!, r.request.id, archived: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(en ? 'Order moved to archive.' : 'تم نقل الطلب إلى الأرشيف.'),
          backgroundColor: GossColors.green,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(en ? 'Unable to archive the order.' : 'تعذر نقل الطلب إلى الأرشيف.'),
          backgroundColor: GossColors.red,
        ));
      }
    }
  }

  Future<void> _bulkDeleteArchived(AppProvider app, AdminProvider admin, bool en) async {
    if (_selected.isEmpty) return;
    final count = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(en ? 'Delete paid invoices' : 'حذف الفواتير المدفوعة'),
        content: Text(en
            ? 'Permanently delete $count fully paid invoice(s) and their payment records? This cannot be undone.'
            : 'حذف نهائي لـ $count فاتورة مدفوعة بالكامل مع سجلات سدادها؟ لا يمكن التراجع عن هذا الإجراء.'),
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
    try {
      for (final id in _selected) {
        for (final p in admin.payments.where((p) => p.requestId == id)) {
          await admin.deletePayment(app.token!, p.id);
        }
        await admin.deleteRequests(app.token!, [id]);
      }
      if (!mounted) return;
      setState(() => _selected.clear());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(en ? 'Invoices deleted.' : 'تم حذف الفواتير.'),
        backgroundColor: GossColors.red,
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(en ? 'Unable to delete the invoices.' : 'تعذر حذف الفواتير.'),
          backgroundColor: GossColors.red,
        ));
      }
    }
  }

  Future<void> _openInvoice(AppProvider app, AdminProvider admin, bool en, Receivable r) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _InvoiceSheet(
        receivable: r,
        en: en,
        payments: admin.payments,
        onRecord: () async => _recordPayment(app, admin, en, r),
        onDelete: (Payment p) => _deletePayment(app, admin, en, p, fromSheet: true),
        fmt: _fmt,
      ),
    );
  }

  Future<void> _recordPayment(AppProvider app, AdminProvider admin, bool en, Receivable r) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PaymentDialog(en: en, defaultAmount: r.balance),
    );
    if (data == null || !mounted) return;
    try {
      await admin.savePayment(app.token!, {
        ...data,
        'requestId': r.request.id,
        'customerId': r.request.customerId,
        'company': r.request.company,
        'name': r.request.name,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(en ? 'Payment recorded.' : 'تم تسجيل السداد.'),
          backgroundColor: GossColors.green,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(en ? 'Unable to record the payment.' : 'تعذر تسجيل السداد.'),
          backgroundColor: GossColors.red,
        ));
      }
    }
  }

  Future<void> _deletePayment(AppProvider app, AdminProvider admin, bool en, Payment p,
      {bool fromSheet = false}) async {
    if (!mounted) return;
    if (fromSheet) {
      Navigator.of(context).pop(); // close the sheet before showing the dialog
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(en ? 'Delete payment' : 'حذف السداد'),
        content: Text(en
            ? 'Delete the ${en ? 'EGP' : 'ج.م'} ${p.amount.toStringAsFixed(2)} payment?'
            : 'حذف السداد بمبلغ ${en ? 'EGP' : 'ج.م'} ${p.amount.toStringAsFixed(2)}؟'),
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
    try {
      await admin.deletePayment(app.token!, p.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(en ? 'Payment deleted.' : 'تم حذف السداد.'),
          backgroundColor: GossColors.green,
        ));
      }
    } catch (_) {}
  }

  Widget _paymentRow(AppProvider app, AdminProvider admin, bool en, Payment p) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0x1F1F8A4C),
              child: Icon(Icons.payments_outlined, size: 18, color: GossColors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p.company.isEmpty ? p.name : p.company}  •  ${_fmt(p.date)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(p.note.isEmpty ? '—' : p.note,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: context.mutedColor)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('${en ? 'EGP' : 'ج.م'} ${p.amount.toStringAsFixed(2)}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontWeight: FontWeight.w800, color: GossColors.green)),
            IconButton(
              tooltip: en ? 'Delete payment' : 'حذف السداد',
              icon: const Icon(Icons.delete_outline, size: 18, color: GossColors.red),
              visualDensity: VisualDensity.compact,
              onPressed: () => _deletePayment(app, admin, en, p),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceSheet extends StatelessWidget {
  final Receivable receivable;
  final bool en;
  final List<Payment> payments;
  final VoidCallback onRecord;
  final ValueChanged<Payment> onDelete;
  final String Function(String) fmt;

  const _InvoiceSheet({
    required this.receivable,
    required this.en,
    required this.payments,
    required this.onRecord,
    required this.onDelete,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final r = receivable;
    final request = r.request;
    final paid = r.paid;
    final balance = r.balance;
    final requestPayments = payments.where((p) => p.requestId == request.id).toList();

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${en ? 'Invoice' : 'فاتورة'} ${request.orderLabel}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(request.company.isEmpty ? request.name : request.company,
                style: TextStyle(color: context.mutedColor)),
            const SizedBox(height: 12),
            ...request.items.map((i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${en ? i.nameEn : i.nameAr} × ${i.qty} ${i.unit}',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Text('${en ? 'EGP' : 'ج.م'} ${(i.price * i.qty).toStringAsFixed(2)}',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
            const Divider(),
            _row(en ? 'Invoice total' : 'إجمالي الفاتورة', r.invoice, Colors.black),
            _row(en ? 'Paid' : 'المدفوع', paid, GossColors.green),
            _row(en ? 'Balance' : 'المتبقي', balance, balance > 0 ? GossColors.red : GossColors.green, bold: true),
            const SizedBox(height: 8),
            if (requestPayments.isNotEmpty) ...[
              Text(en ? 'Payments' : 'المدفوعات', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ...requestPayments.map((p) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${fmt(p.date)}${p.note.isEmpty ? '' : '  •  ${p.note}'}',
                        style: const TextStyle(fontSize: 13)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${en ? 'EGP' : 'ج.م'} ${p.amount.toStringAsFixed(2)}',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: GossColors.red),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onDelete(p),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: GossButton(
                label: balance > 0 ? (en ? 'Record payment' : 'تسجيل سداد') : (en ? 'Add payment' : 'إضافة سداد'),
                color: GossColors.green,
                icon: Icons.payments_outlined,
                onPressed: onRecord,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('${en ? 'EGP' : 'ج.م'} ${value.toStringAsFixed(2)}',
              textDirection: TextDirection.ltr,
              style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  final bool en;
  final double defaultAmount;
  const _PaymentDialog({required this.en, required this.defaultAmount});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final TextEditingController _amount =
      TextEditingController(text: widget.defaultAmount > 0 ? widget.defaultAmount.toStringAsFixed(2) : '');
  final _note = TextEditingController();
  String _method = 'cash';
  DateTime _date = DateTime.now();

  bool get _en => widget.en;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final methods = <String, String>{
      'cash': _en ? 'Cash' : 'نقدي',
      'bank': _en ? 'Bank transfer' : 'تحويل بنكي',
      'instapay': _en ? 'InstaPay' : 'إنستاباي',
      'cheque': _en ? 'Cheque' : 'شيك',
    };
    return AlertDialog(
      title: Text(_en ? 'Record payment' : 'تسجيل سداد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: InputDecoration(labelText: _en ? 'Method' : 'طريقة الدفع'),
              items: methods.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _method = v ?? 'cash'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: _en ? 'Amount (EGP)' : 'المبلغ (ج.م)'),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: _en ? 'Date' : 'التاريخ',
                  prefixIcon: const Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(DateFormat('yyyy-MM-dd').format(_date)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(controller: _note, decoration: InputDecoration(labelText: _en ? 'Note (optional)' : 'ملاحظة (اختياري)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(_en ? 'Cancel' : 'إلغاء')),
        FilledButton(
          onPressed: () {
            final amount = double.tryParse(_amount.text) ?? 0;
            if (amount <= 0) return;
            Navigator.pop(context, {
              'amount': amount,
              'method': _method,
              'note': _note.text.trim(),
              'date': _date.toIso8601String(),
            });
          },
          child: Text(_en ? 'Save' : 'حفظ'),
        ),
      ],
    );
  }
}

class _ArchiveToolbar extends StatelessWidget {
  final bool en;
  final int count;
  final int selectedCount;
  final bool allSelected;
  final VoidCallback onToggleAll;
  final VoidCallback onDelete;

  const _ArchiveToolbar({
    required this.en,
    required this.count,
    required this.selectedCount,
    required this.allSelected,
    required this.onToggleAll,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(value: allSelected, onChanged: (_) => onToggleAll()),
        Text(en ? 'Select all' : 'تحديد الكل'),
        const Spacer(),
        if (selectedCount > 0) ...[
          Text('$selectedCount'),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onDelete,
            style: OutlinedButton.styleFrom(foregroundColor: GossColors.red),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(en ? 'Delete' : 'حذف'),
          ),
        ],
      ],
    );
  }
}