import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../models/models.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/app_provider.dart';
import '../../../services/accounting.dart';
import '../../../widgets/widgets.dart';

/// Double-entry journal (manual postings) + trial balance.
class AccountingJournalScreen extends StatefulWidget {
  const AccountingJournalScreen({super.key});

  @override
  State<AccountingJournalScreen> createState() => _AccountingJournalScreenState();
}

class _AccountingJournalScreenState extends State<AccountingJournalScreen> {
  String _fmt(String date) {
    try {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(date).toLocal());
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final admin = context.watch<AdminProvider>();
    final en = !app.isArabic;

    final trial = buildTrialBalance(admin.journal);
    var totalDebit = 0.0;
    var totalCredit = 0.0;
    for (final row in trial) {
      totalDebit += row.debit;
      totalCredit += row.credit;
    }

    final headers = [
      en ? 'Account' : 'الحساب',
      en ? 'Debit' : 'مدين',
      en ? 'Credit' : 'دائن',
    ];
    final rows = [
      ...trial.map((r) => [
            r.account.label(ar: !en),
            r.debit.toStringAsFixed(2),
            r.credit.toStringAsFixed(2),
          ]),
      [en ? 'TOTAL' : 'الإجمالي', totalDebit.toStringAsFixed(2), totalCredit.toStringAsFixed(2)],
    ];

    final journalHeaders = [
      en ? 'Date' : 'التاريخ',
      en ? 'Memo' : 'البيان',
      en ? 'Account' : 'الحساب',
      en ? 'Debit' : 'مدين',
      en ? 'Credit' : 'دائن',
    ];
    final journalRows = <List<String>>[
      for (final e in admin.journal) ...[
        for (final d in e.debits)
          [_fmt(e.date), e.memo, d.accountEn, d.amount.toStringAsFixed(2), ''],
        for (final c in e.credits)
          [_fmt(e.date), e.memo, c.accountEn, '', c.amount.toStringAsFixed(2)],
      ],
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(en ? 'Journal & trial balance' : 'دفتر اليومية والميزان'),
        actions: [
          IconButton(
            tooltip: en ? 'New posting' : 'قيد جديد',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _addEntry(app, admin, en),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(en ? 'Journal postings' : 'قيود اليومية',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.headingColor)),
              ),
              ExportButtons(
                title: 'GOSST ${en ? 'Journal' : 'دفتر اليومية'}',
                headers: journalHeaders,
                rows: journalRows,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (admin.journal.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(en ? 'No journal postings yet' : 'لا توجد قيود بعد',
                    style: TextStyle(color: context.mutedColor)),
              ),
            ),
          ...admin.journal.map((e) => _entryCard(app, admin, en, e)),

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(en ? 'Trial balance' : 'ميزان المراجعة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.headingColor)),
              ),
              ExportButtons(title: 'GOSST ${en ? 'Trial Balance' : 'ميزان المراجعة'}', headers: headers, rows: rows),
            ],
          ),
          const SizedBox(height: 8),
          if (trial.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(en ? 'No balanced postings' : 'لا توجد قيود موزونة',
                    style: TextStyle(color: context.mutedColor)),
              ),
            ),
          ...trial.map((r) => Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(r.account.label(ar: !en),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text(r.debit > 0 ? '${en ? 'EGP' : 'ج.م'} ${r.debit.toStringAsFixed(2)}' : '',
                            textAlign: TextAlign.end, textDirection: TextDirection.ltr),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(r.credit > 0 ? '${en ? 'EGP' : 'ج.م'} ${r.credit.toStringAsFixed(2)}' : '',
                            textAlign: TextAlign.end, textDirection: TextDirection.ltr),
                      ),
                    ],
                  ),
                ),
              )),
          if (trial.isNotEmpty) ...[
            Card(
              color: GossColors.navy,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Expanded(child: Text('TOTAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                    SizedBox(
                      width: 90,
                      child: Text('${en ? 'EGP' : 'ج.م'} ${totalDebit.toStringAsFixed(2)}',
                          textAlign: TextAlign.end, textDirection: TextDirection.ltr,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text('${en ? 'EGP' : 'ج.م'} ${totalCredit.toStringAsFixed(2)}',
                          textAlign: TextAlign.end, textDirection: TextDirection.ltr,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
            if ((totalDebit - totalCredit).abs() > 0.01)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(en ? 'The trial balance is NOT balanced.' : 'الميزان غير متوازن.',
                    style: const TextStyle(color: GossColors.red, fontWeight: FontWeight.w700)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _entryCard(AppProvider app, AdminProvider admin, bool en, JournalEntry e) {
    final balanced = e.isBalanced;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_fmt(e.date)}${e.memo.isEmpty ? '' : '  •  ${e.memo}'}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (!balanced)
                  Text(en ? 'Unbalanced!' : 'غير متوازن!',
                      style: const TextStyle(color: GossColors.red, fontSize: 12, fontWeight: FontWeight.w700)),
                IconButton(
                  tooltip: en ? 'Delete posting' : 'حذف القيد',
                  icon: const Icon(Icons.delete_outline, size: 18, color: GossColors.red),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deleteEntry(app, admin, en, e),
                ),
              ],
            ),
            for (final d in e.debits)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Text('${en ? 'Dr' : 'مدين'}  ', style: const TextStyle(color: GossColors.red, fontWeight: FontWeight.w700)),
                    Expanded(child: Text(d.accountEn, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${en ? 'EGP' : 'ج.م'} ${d.amount.toStringAsFixed(2)}',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: GossColors.red, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            for (final c in e.credits)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Text('${en ? 'Cr' : 'دائن'}  ', style: const TextStyle(color: GossColors.green, fontWeight: FontWeight.w700)),
                    Expanded(child: Text(c.accountEn, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${en ? 'EGP' : 'ج.م'} ${c.amount.toStringAsFixed(2)}',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: GossColors.green, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            const Divider(height: 14),
            Text('${en ? 'Total' : 'الإجمالي'}: ${en ? 'EGP' : 'ج.م'} ${e.totalDebit.toStringAsFixed(2)}',
                textDirection: TextDirection.ltr,
                style: TextStyle(fontSize: 12, color: context.mutedColor)),
          ],
        ),
      ),
    );
  }

  Future<void> _addEntry(AppProvider app, AdminProvider admin, bool en) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _JournalEntryDialog(en: en),
    );
    if (data == null || !mounted) return;
    try {
      await admin.saveJournalEntry(app.token!, data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(en ? 'Journal entry saved.' : 'تم حفظ القيد.'),
          backgroundColor: GossColors.green,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(en ? 'Unable to save the entry.' : 'تعذر حفظ القيد.'),
          backgroundColor: GossColors.red,
        ));
      }
    }
  }

  Future<void> _deleteEntry(AppProvider app, AdminProvider admin, bool en, JournalEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(en ? 'Delete posting' : 'حذف القيد'),
        content: Text(en ? 'Delete this journal entry?' : 'حذف هذا القيد؟'),
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
      await admin.deleteJournalEntry(app.token!, e.id);
    } catch (_) {}
  }
}

class _LineEditor {
  TextEditingController amount = TextEditingController();
  String accountCode = defaultChartOfAccounts.first.code;
}

class _JournalEntryDialog extends StatefulWidget {
  final bool en;
  const _JournalEntryDialog({required this.en});

  @override
  State<_JournalEntryDialog> createState() => _JournalEntryDialogState();
}

class _JournalEntryDialogState extends State<_JournalEntryDialog> {
  final List<_LineEditor> _debits = [_LineEditor(), _LineEditor()];
  final List<_LineEditor> _credits = [_LineEditor(), _LineEditor()];
  final _memo = TextEditingController();
  DateTime _date = DateTime.now();

  bool get _en => widget.en;

  @override
  void dispose() {
    for (final l in _debits) {
      l.amount.dispose();
    }
    for (final l in _credits) {
      l.amount.dispose();
    }
    _memo.dispose();
    super.dispose();
  }

  double _sideTotal(List<_LineEditor> lines) =>
      lines.fold(0.0, (n, l) => n + (double.tryParse(l.amount.text) ?? 0));

  @override
  Widget build(BuildContext context) {
    final debitTotal = _sideTotal(_debits);
    final creditTotal = _sideTotal(_credits);
    final balanced = debitTotal > 0 && (debitTotal - creditTotal).abs() < 0.01;

    return AlertDialog(
      title: Text(_en ? 'New journal entry' : 'قيد جديد'),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _memo,
              decoration: InputDecoration(labelText: _en ? 'Description' : 'البيان'),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 12),

            Text(_en ? 'Debit side' : 'الجهة المدينة',
                style: const TextStyle(fontWeight: FontWeight.w700, color: GossColors.red)),
            ..._debits.asMap().entries.map((e) => _lineRow(e.key, _debits, true)),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () => setState(() => _debits.add(_LineEditor())),
                icon: const Icon(Icons.add, size: 18),
                label: Text(_en ? 'Add debit line' : 'إضافة سطر مدين'),
              ),
            ),

            const SizedBox(height: 8),
            Text(_en ? 'Credit side' : 'الجهة الدائنة',
                style: const TextStyle(fontWeight: FontWeight.w700, color: GossColors.green)),
            ..._credits.asMap().entries.map((e) => _lineRow(e.key, _credits, false)),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () => setState(() => _credits.add(_LineEditor())),
                icon: const Icon(Icons.add, size: 18),
                label: Text(_en ? 'Add credit line' : 'إضافة سطر دائن'),
              ),
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(_en ? 'Debit total' : 'إجمالي المدين',
                    style: const TextStyle(color: GossColors.red, fontWeight: FontWeight.w700))),
                Text('${_en ? 'EGP' : 'ج.م'} ${debitTotal.toStringAsFixed(2)}',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(color: GossColors.red, fontWeight: FontWeight.w700)),
              ],
            ),
            Row(
              children: [
                Expanded(child: Text(_en ? 'Credit total' : 'إجمالي الدائن',
                    style: const TextStyle(color: GossColors.green, fontWeight: FontWeight.w700))),
                Text('${_en ? 'EGP' : 'ج.م'} ${creditTotal.toStringAsFixed(2)}',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(color: GossColors.green, fontWeight: FontWeight.w700)),
              ],
            ),
            if (!balanced)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_en
                    ? 'Debits must equal credits and be greater than zero.'
                    : 'يجب أن يتساوى المدين والدائن ويكونا أكبر من صفر.',
                    style: const TextStyle(color: GossColors.red, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(_en ? 'Cancel' : 'إلغاء')),
        FilledButton(
          onPressed: balanced
              ? () {
                  List<Map<String, dynamic>> lines(List<_LineEditor> list) => list
                      .where((l) => (double.tryParse(l.amount.text) ?? 0) > 0)
                      .map((l) {
                        final acc = accountByCode(l.accountCode);
                        return {
                          'accountCode': l.accountCode,
                          'accountEn': acc?.en ?? '',
                          'accountAr': acc?.ar ?? '',
                          'amount': double.tryParse(l.amount.text) ?? 0,
                        };
                      })
                      .toList();
                  Navigator.pop(context, {
                    'date': _date.toIso8601String(),
                    'memo': _memo.text.trim(),
                    'debits': lines(_debits),
                    'credits': lines(_credits),
                  });
                }
              : null,
          child: Text(_en ? 'Save' : 'حفظ'),
        ),
      ],
    );
  }

  Widget _lineRow(int index, List<_LineEditor> lines, bool isDebit) {
    final line = lines[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: line.accountCode,
              isDense: true,
              decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              items: defaultChartOfAccounts.map((a) => DropdownMenuItem(
                    value: a.code,
                    child: Text('${a.code} • ${a.label(ar: !_en)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  )).toList(),
              onChanged: (v) => setState(() => line.accountCode = v ?? line.accountCode),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: TextField(
              controller: line.amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _en ? 'EGP' : 'ج.م',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ),
          if (lines.length > 1)
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.grey),
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => lines.removeAt(index)),
            ),
        ],
      ),
    );
  }
}