import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/app_provider.dart';
import '../../../services/accounting.dart';
import '../../../widgets/widgets.dart';

/// General ledger: every account, its movements and running + closing balances
/// for a chosen period, with opening balances carried from earlier postings.
class AccountingLedgerScreen extends StatefulWidget {
  const AccountingLedgerScreen({super.key});

  @override
  State<AccountingLedgerScreen> createState() => _AccountingLedgerScreenState();
}

class _AccountingLedgerScreenState extends State<AccountingLedgerScreen> {
  DateTime _displayMonth = DateTime.now();
  bool _allTime = false;

  (DateTime?, DateTime?) _window() {
    if (_allTime) return (null, null);
    final first = DateTime(_displayMonth.year, _displayMonth.month, 1);
    return (first, DateTime(first.year, first.month + 1, 0));
  }

  String get _periodLabel {
    final en = !context.watch<AppProvider>().isArabic;
    if (_allTime) return en ? 'All time' : 'كل الفترات';
    return DateFormat(en ? 'MMMM yyyy' : 'yyyy-MM').format(_displayMonth);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final admin = context.watch<AdminProvider>();
    final en = !app.isArabic;

    final (from, to) = _window();
    final ledger = buildGeneralLedger(admin.journal, from: from, to: to);

    var periodDebit = 0.0;
    var periodCredit = 0.0;
    for (final a in ledger) {
      periodDebit += a.totalDebit;
      periodCredit += a.totalCredit;
    }

    final headers = [
      en ? 'Account' : 'الحساب',
      en ? 'Date' : 'التاريخ',
      en ? 'Memo' : 'البيان',
      en ? 'Debit' : 'مدين',
      en ? 'Credit' : 'دائن',
      en ? 'Balance' : 'الرصيد',
    ];
    final rows = [
      for (final a in ledger) ...[
        [a.account.label(ar: !en), en ? 'Opening' : 'رصيد افتتاحي', '', '', '', a.displayedOpening.toStringAsFixed(2)],
        for (final m in a.movements)
          [
            a.account.label(ar: !en),
            DateFormat('yyyy-MM-dd').format(m.date),
            m.memo,
            m.debit > 0 ? m.debit.toStringAsFixed(2) : '',
            m.credit > 0 ? m.credit.toStringAsFixed(2) : '',
            a.display(m.runningBalance).toStringAsFixed(2),
          ],
        [a.account.label(ar: !en), en ? 'Closing' : 'رصيد ختامي', '', '', '', a.displayedClosing.toStringAsFixed(2)],
      ],
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(en ? 'General ledger' : 'دفتر الأستاذ العام'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── period selector ─────────────────────────────────────────────
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _allTime
                    ? null
                    : () => setState(() {
                          _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1, 1);
                        }),
              ),
              Expanded(
                child: Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _allTime = !_allTime),
                    icon: Icon(_allTime ? Icons.unfold_less : Icons.unfold_more, size: 18),
                    label: Text(
                      _periodLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _allTime
                    ? null
                    : () => setState(() {
                          _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 1);
                        }),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── totals card ─────────────────────────────────────────────────
          Row(
            children: [
              Expanded(child: _chip(en ? 'Needs to be balanced' : 'الأرصدة يجب أن تتوازن',
                  periodDebit - periodCredit, GossColors.navy, en)),
              const SizedBox(width: 8),
              Expanded(child: _chip(en ? 'Accounts used' : 'الحسابات المستخدمة', ledger.length.toDouble(), GossColors.blue, en)),
            ],
          ),
          const SizedBox(height: 12),

          if (ledger.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(en ? 'No journal postings yet' : 'لا توجد قيود بعد',
                    style: TextStyle(color: context.mutedColor)),
              ),
            ),

          ...ledger.map((a) => _accountCard(en, a)),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(en ? 'Period totals' : 'إجماليات الفترة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.headingColor)),
              ),
              ExportButtons(title: 'GOSST ${en ? 'Ledger' : 'الأستاذ'} $_periodLabel', headers: headers, rows: rows),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            color: GossColors.navy,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(en ? 'Debit total' : 'إجمالي المدين',
                        style: const TextStyle(color: Colors.white70)),
                  ),
                  Text('${en ? 'EGP' : 'ج.م'} ${periodDebit.toStringAsFixed(2)}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 8,
          ),
          Card(
            color: GossColors.green,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(en ? 'Credit total' : 'إجمالي الدائن',
                        style: const TextStyle(color: Colors.white70)),
                  ),
                  Text('${en ? 'EGP' : 'ج.م'} ${periodCredit.toStringAsFixed(2)}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, double value, Color color, bool en) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ),
            Text('${en ? 'EGP' : 'ج.م'} ${value.toStringAsFixed(0)}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _accountCard(bool en, AccountLedger a) {
    final hasMovements = a.movements.isNotEmpty;
    final closingColor = a.displayedClosing < 0 ? GossColors.red : GossColors.green;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: hasMovements && a.movements.length <= 2,
        shape: const Border(),
        leading: const Icon(Icons.account_tree_outlined, color: GossColors.navy),
        title: Text(a.account.label(ar: !en),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${en ? 'Opening' : 'رصيد أول'} ${a.displayedOpening.toStringAsFixed(2)}  →  ${en ? 'closing' : 'رصيد آخر'} ${a.displayedClosing.toStringAsFixed(2)}',
          textDirection: TextDirection.ltr,
          style: TextStyle(fontSize: 12, color: closingColor, fontWeight: FontWeight.w600),
        ),
        children: [
          if (!hasMovements)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(en ? 'No movements this period' : 'لا حركة في هذه الفترة',
                    style: TextStyle(fontSize: 12, color: context.mutedColor)),
              ),
            ),
          if (hasMovements)
            ...a.movements.map((m) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 76,
                        child: Text(DateFormat('yyyy-MM-dd').format(m.date),
                            textDirection: TextDirection.ltr,
                            style: TextStyle(fontSize: 12, color: context.mutedColor)),
                      ),
                      Expanded(
                        child: Text(m.memo.isEmpty ? '—' : m.memo,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      SizedBox(
                        width: 72,
                        child: Text(m.debit > 0 ? '${en ? 'EGP' : 'ج.م'} ${m.debit.toStringAsFixed(2)}' : '',
                            textAlign: TextAlign.end, textDirection: TextDirection.ltr,
                            style: const TextStyle(fontSize: 12, color: GossColors.red, fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(
                        width: 72,
                        child: Text(m.credit > 0 ? '${en ? 'EGP' : 'ج.م'} ${m.credit.toStringAsFixed(2)}' : '',
                            textAlign: TextAlign.end, textDirection: TextDirection.ltr,
                            style: const TextStyle(fontSize: 12, color: GossColors.green, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                )),
          const Divider(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text(en ? 'Balance' : 'الرصيد', style: const TextStyle(fontSize: 12))),
                Text('${en ? 'EGP' : 'ج.م'} ${a.displayedClosing.toStringAsFixed(2)}',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(fontWeight: FontWeight.w800, color: closingColor, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}