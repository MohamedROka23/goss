import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/admin_provider.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class AdminExpensesTab extends StatefulWidget {
  const AdminExpensesTab({super.key});

  @override
  State<AdminExpensesTab> createState() => _AdminExpensesTabState();
}

class _AdminExpensesTabState extends State<AdminExpensesTab> {
  final _category = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _search = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _category.dispose();
    _description.dispose();
    _amount.dispose();
    _search.dispose();
    super.dispose();
  }

  List<Expense> _filtered(List<Expense> all) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((e) {
      return e.category.toLowerCase().contains(q) ||
          e.description.toLowerCase().contains(q) ||
          _fmt(e.date).toLowerCase().contains(q) ||
          e.amount.toStringAsFixed(2).contains(q);
    }).toList();
  }

  String _fmt(String date) {
    try {
      final d = DateTime.parse(date).toLocal();
      return DateFormat('yyyy-MM-dd').format(d);
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final admin = context.watch<AdminProvider>();
    final en = !app.isArabic;
    final filtered = _filtered(admin.expenses);
    final filteredTotal = filtered.fold(0.0, (n, e) => n + e.amount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(en ? 'Expenses' : '\u0627\u0644\u0645\u0635\u0627\u0631\u064a\u0641',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.headingColor)),
        const SizedBox(height: 8),
        Text(
          en ? 'Record any money spent on the business (transport, fuel, salaries, etc.)'
              : '\u0633\u062c\u0644 \u0623\u064a \u0645\u0628\u0644\u063a \u0635\u0631\u0641 \u0639\u0644\u0649 \u0627\u0644\u0634\u063a\u0644 (\u0646\u0642\u0644\u060c \u0648\u0642\u0648\u062f\u060c \u0631\u0648\u0627\u062a\u0628\u060c \u0625\u0644\u062e).',
          style: TextStyle(color: context.mutedColor),
        ),

        // ── Add expense form ────────────────────────────────────────────
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(en ? 'Add expense' : '\u0625\u0636\u0627\u0641\u0629 \u0645\u0635\u0631\u0648\u0641',
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.headingColor)),
                const SizedBox(height: 12),

                // Date picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: en ? 'Date' : '\u0627\u0644\u062a\u0627\u0631\u064a\u062e',
                      prefixIcon: const Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(child: TextField(controller: _category, decoration: InputDecoration(hintText: en ? 'Category' : '\u0627\u0644\u0641\u0626\u0629'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(hintText: en ? 'EGP' : '\u062c.\u0645'))),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(controller: _description, decoration: InputDecoration(hintText: en ? 'Description' : '\u0627\u0644\u0648\u0635\u0641')),
                const SizedBox(height: 12),
                GossButton(
                  label: en ? 'Add expense' : '\u0625\u0636\u0627\u0641\u0629 \u0627\u0644\u0645\u0635\u0631\u0648\u0641',
                  color: GossColors.red,
                  onPressed: () async {
                    if (app.token == null) return;
                    final amount = double.tryParse(_amount.text) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(en
                            ? 'Enter a valid amount greater than zero.'
                            : '\u0623\u062f\u062e\u0644 \u0645\u0628\u0644\u063a\u064b\u0627 \u0635\u062d\u064a\u062d\u064b\u0627 \u0623\u0643\u0628\u0631 \u0645\u0646 \u0635\u0641\u0631.'),
                        backgroundColor: GossColors.red,
                      ));
                      return;
                    }
                    try {
                      await admin.saveExpense(app.token!, {
                        'category': _category.text.isEmpty ? (en ? 'General' : '\u0639\u0627\u0645') : _category.text,
                        'description': _description.text,
                        'amount': amount,
                        'date': _selectedDate.toIso8601String(),
                      });
                      _category.clear();
                      _description.clear();
                      _amount.clear();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(en ? 'Expense recorded.' : '\u062a\u0645 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u0645\u0635\u0631\u0648\u0641.'),
                          backgroundColor: GossColors.green,
                        ));
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(en
                              ? 'Unable to record the expense. Check your connection.'
                              : '\u062a\u0639\u0630\u0631 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u0645\u0635\u0631\u0648\u0641. \u062a\u062d\u0642\u0642 \u0645\u0646 \u0627\u0644\u0627\u062a\u0635\u0627\u0644.'),
                          backgroundColor: GossColors.red,
                        ));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),

        // ── Summary cards ───────────────────────────────────────────────
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _summaryCard(
              label: en ? 'All expenses' : '\u0643\u0644 \u0627\u0644\u0645\u0635\u0627\u0631\u064a\u0641',
              total: admin.totalExpenses,
              color: GossColors.navy,
              en: en,
            )),
            const SizedBox(width: 8),
            Expanded(child: _summaryCard(
              label: en ? 'Filtered total' : '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0645\u0635\u0641\u0649',
              total: filteredTotal,
              color: GossColors.blue,
              en: en,
            )),
          ],
        ),

        // ── Search + export row ─────────────────────────────────────────
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: en ? 'Search expenses...' : '\u0628\u062d\u062b \u0641\u064a \u0627\u0644\u0645\u0635\u0627\u0631\u064a\u0641...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ExportButtons(
              title: en ? 'Expenses' : '\u0627\u0644\u0645\u0635\u0627\u0631\u064a\u0641',
              headers: _headers(en),
              rows: filtered.map((e) => _row(e)).toList(),
            ),
          ],
        ),

        // ── Expense list ────────────────────────────────────────────────
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(en ? 'No expenses found' : '\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0635\u0627\u0631\u064a\u0641',
                  style: TextStyle(color: context.mutedColor)),
            ),
          ),
        ...filtered.map((e) => _expenseRow(app, admin, en, e)),
      ],
    );
  }

  List<String> _headers(bool en) => [
    en ? 'Date' : '\u0627\u0644\u062a\u0627\u0631\u064a\u062e',
    en ? 'Category' : '\u0627\u0644\u0641\u0626\u0629',
    en ? 'Description' : '\u0627\u0644\u0648\u0635\u0641',
    en ? 'Amount' : '\u0627\u0644\u0645\u0628\u0644\u063a',
  ];

  List<String> _row(Expense e) => [_fmt(e.date), e.category, e.description, e.amount.toStringAsFixed(2)];

  Widget _summaryCard({required String label, required double total, required Color color, required bool en}) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 6),
            Text('${en ? 'EGP' : '\u062c.\u0645'} ${total.toStringAsFixed(2)}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
      ),
    );
  }

Future<void> _editExpense(AppProvider app, AdminProvider admin, bool en, Expense e) async {
    final messenger = ScaffoldMessenger.of(context);
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ExpenseEditDialog(expense: e, en: en),
    );
    if (data == null || !mounted) return;
    try {
      await admin.updateExpense(app.token!, e.id, data);
      messenger.showSnackBar(SnackBar(
        content: Text(en ? 'Expense updated.' : '\u062a\u0645 \u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0645\u0635\u0631\u0648\u0641.'),
        backgroundColor: GossColors.green,
      ));
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text(en
            ? 'Unable to update the expense. Check your connection.'
            : '\u062a\u0639\u0630\u0631 \u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0645\u0635\u0631\u0648\u0641. \u062a\u062d\u0642\u0642 \u0645\u0646 \u0627\u0644\u0627\u062a\u0635\u0627\u0644.'),
        backgroundColor: GossColors.red,
      ));
    }
  }

  Future<void> _deleteExpense(AppProvider app, AdminProvider admin, bool en, Expense e) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(en ? 'Delete expense' : '\u062d\u0630\u0641 \u0627\u0644\u0645\u0635\u0631\u0648\u0641'),
        content: Text(en
            ? 'Delete expense "${e.category.isEmpty ? 'General' : e.category}" — ${en ? 'EGP' : '\u062c.\u0645'} ${e.amount.toStringAsFixed(2)}?'
            : '\u062d\u0630\u0641 \u0627\u0644\u0645\u0635\u0631\u0648\u0641 "${e.category.isEmpty ? '\u0639\u0627\u0645' : e.category}" — ${en ? 'EGP' : '\u062c.\u0645'} ${e.amount.toStringAsFixed(2)}\u061f'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(en ? 'Cancel' : '\u0625\u0644\u063a\u0627\u0621'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: GossColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(en ? 'Delete' : '\u062d\u0630\u0641'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await admin.deleteExpense(app.token!, e.id);
      messenger.showSnackBar(SnackBar(
        content: Text(en ? 'Expense deleted.' : '\u062a\u0645 \u062d\u0630\u0641 \u0627\u0644\u0645\u0635\u0631\u0648\u0641.'),
        backgroundColor: GossColors.green,
      ));
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text(en
            ? 'Unable to delete the expense. Check your connection.'
            : '\u062a\u0639\u0630\u0631 \u062d\u0630\u0641 \u0627\u0644\u0645\u0635\u0631\u0648\u0641. \u062a\u062d\u0642\u0642 \u0645\u0646 \u0627\u0644\u0627\u062a\u0635\u0627\u0644.'),
        backgroundColor: GossColors.red,
      ));
    }
  }

  Widget _expenseRow(AppProvider app, AdminProvider admin, bool en, Expense e) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: GossColors.red.withValues(alpha: 0.12),
              child: Text(
                e.category.isNotEmpty ? e.category[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.w700, color: GossColors.red),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${e.category.isEmpty ? (en ? 'General' : '\u0639\u0627\u0645') : e.category}  \u2022  ${_fmt(e.date)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${en ? 'EGP' : '\u062c.\u0645'} ${e.amount.toStringAsFixed(2)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: GossColors.red, fontSize: 15)),
                  Text(e.description.isEmpty ? '-' : e.description,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: context.mutedColor)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: en ? 'Edit expense' : '\u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0645\u0635\u0631\u0648\u0641',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  onPressed: () => _editExpense(app, admin, en, e),
                ),
                IconButton(
                  tooltip: en ? 'Delete expense' : '\u062d\u0630\u0641 \u0627\u0644\u0645\u0635\u0631\u0648\u0641',
                  icon: const Icon(Icons.delete_outline, size: 18, color: GossColors.red),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  onPressed: () => _deleteExpense(app, admin, en, e),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseEditDialog extends StatefulWidget {
  final Expense expense;
  final bool en;
  const _ExpenseEditDialog({required this.expense, required this.en});

  @override
  State<_ExpenseEditDialog> createState() => _ExpenseEditDialogState();
}

class _ExpenseEditDialogState extends State<_ExpenseEditDialog> {
  late final TextEditingController _category;
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late DateTime _selectedDate;

  bool get _en => widget.en;

  @override
  void initState() {
    super.initState();
    _category = TextEditingController(text: widget.expense.category);
    _amount = TextEditingController(
      text: widget.expense.amount.toStringAsFixed(2),
    );
    _description = TextEditingController(text: widget.expense.description);
    _selectedDate = DateTime.tryParse(widget.expense.date)?.toLocal() ?? DateTime.now();
  }

  @override
  void dispose() {
    _category.dispose();
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_en ? 'Edit expense' : '\u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0645\u0635\u0631\u0648\u0641'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: _en ? 'Date' : '\u0627\u0644\u062a\u0627\u0631\u064a\u062e',
                    prefixIcon: const Icon(Icons.calendar_today, size: 18),
                    isDense: true,
                  ),
                  child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _category,
                decoration: InputDecoration(
                  labelText: _en ? 'Category' : '\u0627\u0644\u0641\u0626\u0629',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _en ? 'Amount (EGP)' : '\u0627\u0644\u0645\u0628\u0644\u063a (\u062c.\u0645)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: _en ? 'Description' : '\u0627\u0644\u0648\u0635\u0641',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_en ? 'Cancel' : '\u0625\u0644\u063a\u0627\u0621'),
        ),
        FilledButton(
          onPressed: () {
            final amount = double.tryParse(_amount.text) ?? 0;
            Navigator.pop(context, <String, dynamic>{
              'date': _selectedDate.toIso8601String(),
              'category': _category.text.trim().isEmpty
                  ? (_en ? 'General' : '\u0639\u0627\u0645')
                  : _category.text.trim(),
              'description': _description.text,
              'amount': amount,
            });
          },
          child: Text(_en ? 'Save' : '\u062d\u0641\u0638'),
        ),
      ],
    );
  }
}