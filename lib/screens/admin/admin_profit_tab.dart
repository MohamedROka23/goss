import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/admin_provider.dart';
import '../../app/theme.dart';
import '../../widgets/widgets.dart';
import 'accounting/admin_accounting_tab.dart';

class AdminProfitTab extends StatefulWidget {
  const AdminProfitTab({super.key});

  @override
  State<AdminProfitTab> createState() => _AdminProfitTabState();
}

class _AdminProfitTabState extends State<AdminProfitTab> {
  final Map<String, int> _qtys = {};
  double _extraExpenses = 0;
  final _extraCtrl = TextEditingController();

  @override
  void dispose() {
    _extraCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final admin = context.watch<AdminProvider>();
    final en = !app.isArabic;

    var sellTotal = 0.0;    var costTotal = 0.0;
    for (final p in app.products) {
      final qty = _qtys[p.id] ?? 0;
      if (qty > 0) {
        sellTotal += p.price * qty;
        costTotal += p.costPrice * qty;
      }
    }
    final profit = sellTotal - costTotal - _extraExpenses;
    final profitMargin = sellTotal > 0 ? (profit / sellTotal) * 100 : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    en ? 'Profit Calculator' : '\u062d\u0627\u0633\u0628\u0629 \u0627\u0644\u0631\u0628\u062d',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.headingColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    en ? 'Select products and quantities to calculate profit for one or more invoices.'
                        : '\u0627\u062e\u062a\u0631 \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a \u0648\u0627\u0644\u0643\u0645\u064a\u0627\u062a \u0644\u062d\u0633\u0627\u0628 \u0627\u0644\u0631\u0628\u062d \u0644\u0641\u0627\u062a\u0648\u0631\u0629 \u0623\u0648 \u0623\u0643\u062b\u0631.',
                    style: TextStyle(color: context.mutedColor),
                  ),
                ],
              ),
            ),
            ExportButtons(
              title: en ? 'Profit' : '\u0627\u0644\u0631\u0628\u062d',
              headers: [en ? 'Product' : '\u0627\u0644\u0645\u0646\u062a\u062c', en ? 'Qty' : '\u0627\u0644\u0643\u0645\u064a\u0629', en ? 'Price' : '\u0627\u0644\u0633\u0639\u0631', en ? 'Cost' : '\u0627\u0644\u062a\u0643\u0644\u0641\u0629', en ? 'Sell Total' : '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0628\u064a\u0639', en ? 'Cost Total' : '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u062a\u0643\u0644\u0641\u0629'],
              rows: _exportRows(app, en, sellTotal, costTotal, profit),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GossButton(
          label: en ? 'Open accounting reports' : 'افتح تقارير المحاسبة',
          color: GossColors.navy,
          icon: Icons.account_balance_outlined,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                body: SafeArea(
                  child: AdminAccountingTab(
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(en ? 'Additional expenses (optional)' : '\u0645\u0635\u0627\u0631\u064a\u0641 \u0625\u0636\u0627\u0641\u064a\u0629 (\u0627\u062e\u062a\u064a\u0627\u0631\u064a)',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: _extraCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => setState(() => _extraExpenses = double.tryParse(v) ?? 0),
                  decoration: InputDecoration(hintText: en ? 'EGP' : '\u062c.\u0645'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...app.products.map((p) {
          return Card(
            child: ListTile(
              title: Text(en ? p.nameEn : p.nameAr),
              subtitle: Text(
                '${en ? 'Sell' : '\u0627\u0644\u0628\u064a\u0639'}: ${en ? 'EGP' : '\u062c.\u0645'} ${p.price.toStringAsFixed(2)}\n'
                '${en ? 'Cost' : '\u0627\u0644\u062a\u0643\u0644\u0641\u0629'}: ${en ? 'EGP' : '\u062c.\u0645'} ${p.costPrice.toStringAsFixed(2)} | ${en ? 'Margin' : '\u0627\u0644\u0647\u0627\u0645\u0634'}: ${p.price > 0 ? ((p.price - p.costPrice) / p.price * 100).toStringAsFixed(1) : '0'}%',
                textDirection: TextDirection.ltr,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      final q = (_qtys[p.id] ?? 0) - 1;
                      setState(() => _qtys[p.id] = q < 0 ? 0 : q);
                    },
                  ),
                  SizedBox(
                    width: 30,
                    child: Text('${_qtys[p.id] ?? 0}', textAlign: TextAlign.center),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _qtys[p.id] = (_qtys[p.id] ?? 0) + 1),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        Card(
          color: GossColors.navy,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statRow(en ? 'Total selling' : '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0628\u064a\u0639', sellTotal, Colors.white, en: en),
                _statRow(en ? 'Total cost' : '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u062a\u0643\u0644\u0641\u0629', costTotal, Colors.white70, en: en),
                _statRow(en ? 'Extra expenses' : '\u0645\u0635\u0627\u0631\u064a\u0641 \u0625\u0636\u0627\u0641\u064a\u0629', _extraExpenses, Colors.white70, en: en),
                const Divider(color: Colors.white38),
                _statRow(en ? 'Net profit' : '\u0635\u0627\u0641\u064a \u0627\u0644\u0631\u0628\u062d', profit, profit >= 0 ? GossColors.green : GossColors.red, en: en, bold: true),
                _statRow(en ? 'Profit margin' : '\u0646\u0633\u0628\u0629 \u0627\u0644\u0631\u0628\u062d', 0, Colors.white, en: en, string: '${profitMargin.toStringAsFixed(1)}%'),
                _statRow(en ? 'Total purchase spend' : '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0634\u0631\u0627\u0621', admin.totalPurchases, Colors.white70, en: en),
                _statRow(en ? 'Total recorded expenses' : '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0645\u0635\u0627\u0631\u064a\u0641', admin.totalExpenses, Colors.white70, en: en),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<List<String>> _exportRows(AppProvider app, bool en, double sellTotal, double costTotal, double profit) {
    final rows = <List<String>>[];
    for (final p in app.products) {
      final qty = _qtys[p.id] ?? 0;
      if (qty > 0) {
        rows.add([
          en ? p.nameEn : p.nameAr,
          '$qty',
          p.price.toStringAsFixed(2),
          p.costPrice.toStringAsFixed(2),
          (p.price * qty).toStringAsFixed(2),
          (p.costPrice * qty).toStringAsFixed(2),
        ]);
      }
    }
    if (_extraExpenses > 0) {
      rows.add([en ? 'Extra expenses' : '\u0645\u0635\u0627\u0631\u064a\u0641 \u0625\u0636\u0627\u0641\u064a\u0629', '', '', '', '', _extraExpenses.toStringAsFixed(2)]);
    }
    rows.add([en ? 'Net profit' : '\u0635\u0627\u0641\u064a \u0627\u0644\u0631\u0628\u062d', '', '', '', '', profit.toStringAsFixed(2)]);
    return rows;
  }

  Widget _statRow(String label, double value, Color color, {bool en = true, bool bold = false, String? string}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              string ?? '${en ? 'EGP' : '\u062c.\u0645'} ${value.toStringAsFixed(2)}',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: color,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                fontSize: bold ? 18 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
