import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../models/models.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/app_provider.dart';
import '../../../services/accounting.dart';
import '../../../widgets/widgets.dart';
import '../admin_expenses_tab.dart';
import '../admin_profit_tab.dart';
import '../admin_purchases_tab.dart';
import 'accounting_income_screen.dart';
import 'accounting_journal_screen.dart';
import 'accounting_ledger_screen.dart';
import 'accounting_receivables_screen.dart';
import 'accounting_report_screen.dart';

/// Hub tab for the integrated accounting module. Summarises the financial
/// position and links to the full statements.
class AdminAccountingTab extends StatelessWidget {
  const AdminAccountingTab({super.key, this.onBack});

  /// Optional callback to return to the dashboard home (used to show a back
  /// arrow on the accounting hub).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final admin = context.watch<AdminProvider>();
    final en = !app.isArabic;

    final costByProduct = {for (final p in app.products) p.id: p.costPrice};
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthIncome = buildIncomeStatement(
      requests: admin.requests,
      expenses: admin.expenses,
      costByProduct: costByProduct,
      from: monthStart,
      to: now,
    );
    final receivables = buildReceivables(
      requests: admin.requests,
      payments: admin.payments,
    );
    var openAR = 0.0;
    for (final r in receivables) {
      if (r.balance > 0) openAR += r.balance;
    }

    final label = DateFormat(en ? 'MMM yyyy' : 'yyyy-MM').format(now);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            if (onBack != null) ...[
              IconButton(
                tooltip: en ? 'Back' : 'رجوع',
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                en ? 'Accounting' : 'المحاسبة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.headingColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          en
              ? 'Automatic statements from orders, purchases, expenses and payments.'
              : 'قوائم مالية تلقائية من الطلبات والمشتريات والمصاريف والمدفوعات.',
          style: TextStyle(color: context.mutedColor),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(child: _chip(
              label: en ? 'Net profit ($label)' : 'صافي الربح ($label)',
              value: monthIncome.netProfit,
              color: monthIncome.netProfit >= 0 ? GossColors.green : GossColors.red,
              en: en,
            )),
            const SizedBox(width: 8),
            Expanded(child: _chip(
              label: en ? 'Outstanding' : 'ذمم مفتوحة',
              value: openAR,
              color: GossColors.navy,
              en: en,
            )),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _chip(
              label: en ? 'Collected' : 'مدفوعات محصلة',
              value: admin.totalPaymentsReceived,
              color: GossColors.blue,
              en: en,
            )),
            const SizedBox(width: 8),
            Expanded(child: _chip(
              label: en ? 'Month expenses' : 'مصاريف الشهر',
              value: monthIncome.totalExpenses,
              color: GossColors.red,
              en: en,
            )),
          ],
        ),

        const SizedBox(height: 16),
        _navCard(
          context,
          en: en,
          icon: Icons.insert_chart_outlined,
          color: GossColors.green,
          title: en ? 'Income statement' : 'قائمة الدخل',
          subtitle: en
              ? 'Revenue, COGS, gross & net profit by period.'
              : 'الإيرادات وتكلفة المبيعات والربح الإجمالي والصافي حسب الفترة.',
          onTap: () => _push(context, const AccountingIncomeScreen()),
        ),
        _navCard(
          context,
          en: en,
          icon: Icons.receipt_long_outlined,
          color: GossColors.blue,
          title: en ? 'Receivables & payments' : 'الذمم والمدفوعات',
          subtitle: en
              ? 'Invoices per order, customer balances and recording payments.'
              : 'فواتير كل طلب وأرصدة العملاء وتسجيل السداد.',
          onTap: () => _push(context, const AccountingReceivablesScreen()),
        ),
        _navCard(
          context,
          en: en,
          icon: Icons.menu_book_outlined,
          color: GossColors.navy,
          title: en ? 'Journal & trial balance' : 'دفتر اليومية والميزان',
          subtitle: en
              ? 'Double-entry postings and the trial balance.'
              : 'القيود بقيد مزدوج وميزان المراجعة.',
          onTap: () => _push(context, const AccountingJournalScreen()),
        ),
        _navCard(
          context,
          en: en,
          icon: Icons.account_tree_outlined,
          color: Color(0xFF7B61FF),
          title: en ? 'General ledger' : 'دفتر الأستاذ العام',
          subtitle: en
              ? 'Per-account movements with opening & closing balances.'
              : 'حركة كل حساب مع أرصدة الفتح والختام.',
          onTap: () => _push(context, const AccountingLedgerScreen()),
        ),
_navCard(
          context,
          en: en,
          icon: Icons.description_outlined,
          color: GossColors.red,
          title: en ? 'Monthly report' : '\u0627\u0644\u062a\u0642\u0631\u064a\u0631 \u0627\u0644\u0634\u0647\u0631\u064a',
          subtitle: en
              ? 'Full PDF / Excel report for a chosen month.'
              : '\u062a\u0642\u0631\u064a\u0631 \u0634\u0627\u0645\u0644 PDF / Excel \u0644\u0634\u0647\u0631 \u0645\u062d\u062f\u062f.',
          onTap: () => _push(context, const AccountingReportScreen()),
        ),

        const SizedBox(height: 16),
        Text(
          en ? 'Daily operations' : '\u0639\u0645\u0644\u064a\u0627\u062a \u0627\u0644\u064a\u0648\u0645',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.mutedColor),
        ),
        const SizedBox(height: 8),
        _navCard(
          context,
          en: en,
          icon: Icons.shopping_cart_outlined,
          color: const Color(0xFF00897B),
          title: en ? 'Purchasing' : '\u0627\u0644\u0645\u0634\u062a\u0631\u064a\u0627\u062a',
          subtitle: en
              ? 'Record purchase invoices with quantities, costs and VAT.'
              : '\u062a\u0633\u062c\u064a\u0644 \u0641\u0648\u0627\u062a\u064a\u0631 \u0627\u0644\u0634\u0631\u0627\u0621 \u0628\u0627\u0644\u0643\u0645\u064a\u0627\u062a \u0648\u0627\u0644\u062a\u0643\u0644\u0641\u0629 \u0648\u0627\u0644\u0636\u0631\u064a\u0628\u0629.',
          onTap: () => _push(
            context,
            _ModulePage(
              en: en,
              title: en ? 'Purchasing' : '\u0627\u0644\u0645\u0634\u062a\u0631\u064a\u0627\u062a',
              child: const AdminPurchasesTab(),
            ),
          ),
        ),
        _navCard(
          context,
          en: en,
          icon: Icons.payments_outlined,
          color: const Color(0xFFEF6C00),
          title: en ? 'Expenses' : '\u0627\u0644\u0645\u0635\u0627\u0631\u064a\u0641',
          subtitle: en
              ? 'Track and categorise day-to-day business expenses.'
              : '\u0645\u062a\u0627\u0628\u0639\u0629 \u0648\u062a\u0635\u0646\u064a\u0641 \u0645\u0635\u0627\u0631\u064a\u0641 \u0627\u0644\u0639\u0645\u0644 \u0627\u0644\u064a\u0648\u0645\u064a\u0629.',
          onTap: () => _push(
            context,
            _ModulePage(
              en: en,
              title: en ? 'Expenses' : '\u0627\u0644\u0645\u0635\u0627\u0631\u064a\u0641',
              child: const AdminExpensesTab(),
            ),
          ),
        ),
        if (app.can(AdminPerms.profit))
          _navCard(
          context,
          en: en,
          icon: Icons.trending_up,
          color: GossColors.green,
          title: en ? 'Profit analysis' : '\u062a\u062d\u0644\u064a\u0644 \u0627\u0644\u0631\u0628\u062d',
          subtitle: en
              ? 'Manual calculator: pick products & quantities to compute margin.'
              : 'حاسبة يدوية: اختر المنتجات والكميات لحساب الهامش.',
          onTap: () => _push(
            context,
            _ModulePage(
              en: en,
              title: en ? 'Profit analysis' : '\u062a\u062d\u0644\u064a\u0644 \u0627\u0644\u0631\u0628\u062d',
              child: const AdminProfitTab(),
            ),
          ),
        ),

        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ExportButtons(
              title: 'GOSST ${en ? 'Accounting snapshot $label' : 'ملخص المحاسبة $label'}',
              headers: [en ? 'Item' : 'البند', en ? 'Amount (EGP)' : 'المبلغ (ج.م)'],
              rows: [
                [en ? 'Net profit ($label)' : 'صافي الربح ($label)', monthIncome.netProfit.toStringAsFixed(2)],
                [en ? 'Outstanding receivables' : 'ذمم مفتوحة', openAR.toStringAsFixed(2)],
                [en ? 'Collected payments' : 'مدفوعات محصلة', admin.totalPaymentsReceived.toStringAsFixed(2)],
                [en ? 'Month expenses' : 'مصاريف الشهر', monthIncome.totalExpenses.toStringAsFixed(2)],
              ],
            ),
          ],
        ),
      ],
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _chip({required String label, required double value, required Color color, required bool en}) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 6),
            Text('${en ? 'EGP' : 'ج.م'} ${value.toStringAsFixed(2)}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
      ),
    );
  }

  Widget _navCard(
    BuildContext context, {
    required bool en,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: context.mutedColor)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.mutedColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps a dashboard management tab in a standalone page (AppBar + back) so the
/// accounting hub can open it as a full screen.
class _ModulePage extends StatelessWidget {
  const _ModulePage({required this.en, required this.title, required this.child});

  final bool en;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.sectionColor,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          tooltip: en ? 'Back' : 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}