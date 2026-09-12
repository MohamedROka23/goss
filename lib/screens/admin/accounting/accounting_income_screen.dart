import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/app_provider.dart';
import '../../../services/accounting.dart';
import '../../../widgets/widgets.dart';

/// Period income statement computed from orders + expenses.
class AccountingIncomeScreen extends StatefulWidget {
  const AccountingIncomeScreen({super.key});

  @override
  State<AccountingIncomeScreen> createState() => _AccountingIncomeScreenState();
}

class _AccountingIncomeScreenState extends State<AccountingIncomeScreen> {
  DateTime _displayMonth = DateTime.now();
  bool _allTime = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final admin = context.watch<AdminProvider>();
    final en = !app.isArabic;

    final (from, to) = _window();
    final costByProduct = {for (final p in app.products) p.id: p.costPrice};
    final st = buildIncomeStatement(
      requests: admin.requests,
      expenses: admin.expenses,
      costByProduct: costByProduct,
      from: from,
      to: to,
    );

    final periodLabel = _allTime
        ? (en ? 'All time' : 'كل الفترات')
        : DateFormat(en ? 'MMMM yyyy' : 'yyyy-MM').format(_displayMonth);

    final headers = [
      en ? 'Item' : 'البند',
      en ? 'Amount (EGP)' : 'المبلغ (ج.م)',
    ];
    final rows = <List<String>>[
      [en ? 'Sales revenue' : 'إيرادات المبيعات', st.revenue.toStringAsFixed(2)],
      [en ? 'Cost of goods sold' : 'تكلفة المبيعات', st.cogs.toStringAsFixed(2)],
      [en ? 'Gross profit' : 'الربح الإجمالي', st.grossProfit.toStringAsFixed(2)],
      for (final b in st.expenseBreakdown)
        [b.labelEn, b.amount.toStringAsFixed(2)],
      [en ? 'Total expenses' : 'إجمالي المصاريف', st.totalExpenses.toStringAsFixed(2)],
      [en ? 'Net profit' : 'صافي الربح', st.netProfit.toStringAsFixed(2)],
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(en ? 'Income statement' : 'قائمة الدخل'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── period selector ────────────────────────────────────────────
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
                      periodLabel,
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

          // ── headline numbers ───────────────────────────────────────────
          Card(
            color: GossColors.navy,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row(en ? 'Sales revenue' : 'إيرادات المبيعات', st.revenue, Colors.white, en: en),
                  _row(en ? 'Cost of goods sold' : 'تكلفة المبيعات', st.cogs, Colors.white70, en: en),
                  const Divider(color: Colors.white38),
                  _row(en ? 'Gross profit' : 'الربح الإجمالي', st.grossProfit,
                      st.grossProfit >= 0 ? GossColors.green : GossColors.red, en: en),
                  _row(en ? 'Total expenses' : 'إجمالي المصاريف', st.totalExpenses, Colors.white70, en: en),
                  const Divider(color: Colors.white38),
                  _row(en ? 'Net profit' : 'صافي الربح', st.netProfit,
                      st.netProfit >= 0 ? GossColors.green : GossColors.red, en: en, bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── expense breakdown ──────────────────────────────────────────
          if (st.expenseBreakdown.isNotEmpty) ...[
            Text(en ? 'Expense breakdown' : 'تفصيل المصاريف',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.headingColor)),
            const SizedBox(height: 8),
            ...st.expenseBreakdown.map((b) => Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(b.labelEn, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Text('${en ? 'EGP' : 'ج.م'} ${b.amount.toStringAsFixed(2)}',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: GossColors.red)),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 12),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ExportButtons(
                title: 'GOSST ${en ? 'Income' : 'قائمة الدخل'} $periodLabel',
                headers: headers,
                rows: rows,
              ),
            ],
          ),
        ],
      ),
    );
  }

  (DateTime?, DateTime?) _window() {
    if (_allTime) return (null, null);
    final first = DateTime(_displayMonth.year, _displayMonth.month, 1);
    return (first, DateTime(first.year, first.month + 1, 0));
  }

  Widget _row(String label, double value, Color color, {required bool en, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          ),
          Text('${en ? 'EGP' : 'ج.م'} ${value.toStringAsFixed(2)}',
              textDirection: TextDirection.ltr,
              style: TextStyle(color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 17 : 14)),
        ],
      ),
    );
  }
}