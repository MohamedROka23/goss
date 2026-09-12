import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/app_provider.dart';
import '../../../services/accounting.dart';
import '../../../widgets/widgets.dart';

/// Full consolidated report for a chosen month, exportable to PDF / Excel.
class AccountingReportScreen extends StatefulWidget {
  const AccountingReportScreen({super.key});

  @override
  State<AccountingReportScreen> createState() => _AccountingReportScreenState();
}

class _AccountingReportScreenState extends State<AccountingReportScreen> {
  DateTime _month = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final admin = context.watch<AdminProvider>();
    final en = !app.isArabic;

    final from = DateTime(_month.year, _month.month, 1);
    final to = DateTime(_month.year, _month.month + 1, 0);
    final costByProduct = {for (final p in app.products) p.id: p.costPrice};

    final income = buildIncomeStatement(
      requests: admin.requests,
      expenses: admin.expenses,
      costByProduct: costByProduct,
      from: from,
      to: to,
    );

    final monthPurchases = admin.purchases.where((p) => _inWindow(p.date, from, to)).toList();
    final monthPayments = admin.payments.where((p) => _inWindow(p.date, from, to)).toList();
    final receivables = buildReceivables(requests: admin.requests, payments: admin.payments);
    var collected = 0.0;
    for (final p in monthPayments) {
      collected += p.amount;
    }
    final outstanding = receivables.where((r) => r.balance > 0).take(8).toList();
    var totalPurchases = 0.0;
    for (final p in monthPurchases) {
      totalPurchases += p.total;
    }

    String productName(String id) {
      for (final p in app.products) {
        if (p.id == id) return en ? p.nameEn : p.nameAr;
      }
      return id;
    }

    final headers = [en ? 'Item' : 'البند', en ? 'Details' : 'التفاصيل', en ? 'Amount (EGP)' : 'المبلغ (ج.م)'];
    final rows = <List<String>>[
      [en ? 'INCOME STATEMENT' : 'قائمة الدخل', '', ''],
      [en ? 'Sales revenue' : 'إيرادات المبيعات', '', income.revenue.toStringAsFixed(2)],
      [en ? 'Cost of goods sold' : 'تكلفة المبيعات', '', income.cogs.toStringAsFixed(2)],
      [en ? 'Gross profit' : 'الربح الإجمالي', '', income.grossProfit.toStringAsFixed(2)],
      [en ? 'Expenses' : 'المصاريف', '', income.totalExpenses.toStringAsFixed(2)],
      [en ? 'Net profit' : 'صافي الربح', '', income.netProfit.toStringAsFixed(2)],
      for (final b in income.expenseBreakdown) ...[
        [en ? 'Expense category' : 'فئة المصروف', b.labelEn, b.amount.toStringAsFixed(2)],
      ],
      [en ? 'PURCHASES' : 'المشتريات', '', ''],
      for (final p in monthPurchases)
        [p.supplier, '${productName(p.productId)} × ${p.qty}', p.total.toStringAsFixed(2)],
      [en ? 'Total purchases' : 'إجمالي المشتريات', '', totalPurchases.toStringAsFixed(2)],
      [en ? 'PAYMENTS' : 'المدفوعات', '', ''],
      [en ? 'Collected this month' : 'المحصل هذا الشهر', '', collected.toStringAsFixed(2)],
      [en ? 'Payments count' : 'عدد عمليات السداد', '${monthPayments.length}', ''],
      [en ? 'OUTSTANDING RECEIVABLES' : 'الذمم المفتوحة', '', ''],
      for (final r in outstanding)
        [r.request.company.isEmpty ? r.request.name : r.request.company, r.request.orderLabel, r.balance.toStringAsFixed(2)],
    ];

    final monthLabel = DateFormat(en ? 'MMMM yyyy' : 'yyyy-MM').format(_month);

    return Scaffold(
      appBar: AppBar(
        title: Text(en ? 'Monthly report' : 'التقرير الشهري'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1, 1)),
              ),
              Expanded(
                child: Text(monthLabel,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1, 1)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Card(
            color: GossColors.navy,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row(en ? 'Sales revenue' : 'إيرادات المبيعات', income.revenue, Colors.white, en: en),
                  _row(en ? 'Total expenses' : 'إجمالي المصاريف', income.totalExpenses, Colors.white70, en: en),
                  _row(en ? 'Total purchases' : 'إجمالي المشتريات', totalPurchases, Colors.white70, en: en),
                  _row(en ? 'Collected payments' : 'السداد المحصل', collected, Colors.white70, en: en),
                  const Divider(color: Colors.white38),
                  _row(en ? 'Net profit' : 'صافي الربح', income.netProfit,
                      income.netProfit >= 0 ? GossColors.green : GossColors.red, en: en, bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          _section(en ? 'Expenses by category' : 'المصاريف حسب الفئة'),
          const SizedBox(height: 6),
          if (income.expenseBreakdown.isEmpty)
            _empty(en ? 'No expenses in this month' : 'لا توجد مصاريف في هذا الشهر'),
          ...income.expenseBreakdown.map((b) => _line(b.labelEn, b.amount, GossColors.red, en)),

          const SizedBox(height: 16),
          _section(en ? 'Purchases this month' : 'مشتريات الشهر'),
          const SizedBox(height: 6),
          if (monthPurchases.isEmpty)
            _empty(en ? 'No purchases in this month' : 'لا توجد مشتريات في هذا الشهر'),
          ...monthPurchases.map((p) => Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.supplier, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('${productName(p.productId)} × ${p.qty}',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: context.mutedColor)),
                          ],
                        ),
                      ),
                      Text('${en ? 'EGP' : 'ج.م'} ${p.total.toStringAsFixed(2)}',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              )),

          const SizedBox(height: 16),
          _section(en ? 'Top outstanding balances' : 'أعلى الأرصدة المفتوحة'),
          const SizedBox(height: 6),
          if (outstanding.isEmpty)
            _empty(en ? 'Nothing left outstanding — all paid' : 'لا توجد ذمم مفتوحة — تم سداد الكل'),
          ...outstanding.map((r) => Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${r.request.orderLabel}  •  ${r.request.company.isEmpty ? r.request.name : r.request.company}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text('${en ? 'EGP' : 'ج.م'} ${r.balance.toStringAsFixed(2)}',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: GossColors.red)),
                    ],
                  ),
                ),
              )),

          const SizedBox(height: 20),
          Center(
            child: ExportButtons(
              title: 'GOSST ${en ? 'Monthly Report' : 'التقرير الشهري'} $monthLabel',
              headers: headers,
              rows: rows,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.headingColor));
  }

  Widget _empty(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(msg, style: TextStyle(color: context.mutedColor)),
    );
  }

  Widget _line(String label, double value, Color color, bool en) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text('${en ? 'EGP' : 'ج.م'} ${value.toStringAsFixed(2)}',
                textDirection: TextDirection.ltr,
                style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
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

  bool _inWindow(String iso, DateTime from, DateTime to) {
    final d = DateTime.tryParse(iso);
    if (d == null) return false;
    final local = d.toLocal();
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return local.isAfter(start.subtract(const Duration(milliseconds: 1))) && !local.isAfter(end);
  }
}