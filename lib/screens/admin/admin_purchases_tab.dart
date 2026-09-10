import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/admin_provider.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class AdminPurchasesTab extends StatefulWidget {
  const AdminPurchasesTab({super.key});

  @override
  State<AdminPurchasesTab> createState() => _AdminPurchasesTabState();
}

class _AdminPurchasesTabState extends State<AdminPurchasesTab> {
  final _supplier = TextEditingController();
  final _qty = TextEditingController();
  final _costPrice = TextEditingController();
  String? _productId;
  bool _saving = false;

  @override
  void dispose() {
    _supplier.dispose();
    _qty.dispose();
    _costPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final admin = context.watch<AdminProvider>();
    final en = !app.isArabic;

    // auto-select first product if none
    if (_productId == null && app.products.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _productId = app.products.first.id);
      });
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                en ? 'Purchasing (Cost Price)' : '\u0627\u0644\u0634\u0631\u0627\u0621 (\u0633\u0639\u0631 \u0627\u0644\u062a\u0643\u0644\u0641\u0629)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.headingColor),
              ),
            ),
            ExportButtons(
              title: en ? 'Purchases' : '\u0627\u0644\u0645\u0634\u062a\u0631\u064a\u0627\u062a',
              headers: [en ? 'Date' : '\u0627\u0644\u062a\u0627\u0631\u064a\u062e', en ? 'Supplier' : '\u0627\u0644\u0645\u0648\u0631\u062f', en ? 'Product' : '\u0627\u0644\u0645\u0646\u062a\u062c', en ? 'Qty' : '\u0627\u0644\u0643\u0645\u064a\u0629', en ? 'Cost' : '\u0627\u0644\u062a\u0643\u0644\u0641\u0629', en ? 'Total' : '\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a'],
              rows: admin.purchases.map((p) {
                final name = _productName(app, en, p.productId);
                return [_fmtDate(p.date), p.supplier, name, '${p.qty}', p.costPrice.toStringAsFixed(2), p.total.toStringAsFixed(2)];
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          en ? 'Choose products linked to the price quotes and record your purchasing cost.' : '\u0627\u062e\u062a\u0631 \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a \u0627\u0644\u0645\u0631\u062a\u0628\u0637\u0629 \u0628\u0639\u0631\u0648\u0636 \u0627\u0644\u0623\u0633\u0639\u0627\u0631 \u0648\u0633\u062c\u0644 \u062a\u0643\u0644\u0641\u0629 \u0627\u0644\u0634\u0631\u0627\u0621.',
          style: TextStyle(color: context.mutedColor),
        ),
        const SizedBox(height: 16),
        _purchaseForm(context, app, admin, en),
        const SizedBox(height: 12),
        Text(en ? 'Purchase history' : '\u0633\u062c\u0644 \u0627\u0644\u0634\u0631\u0627\u0621',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.headingColor)),
        ...admin.purchases.map((p) => _purchaseRow(context, app, admin, en, p)),
      ],
    );
  }

  Widget _purchaseForm(BuildContext context, AppProvider app, AdminProvider admin, bool en) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(en ? 'Add purchase' : '\u0625\u0636\u0627\u0641\u0629 \u0634\u0631\u0627\u0621',
                style: TextStyle(fontWeight: FontWeight.w700, color: context.headingColor)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('purch-$_productId'),
              initialValue: _productId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: en ? 'Product' : '\u0627\u0644\u0645\u0646\u062a\u062c',
                isDense: true,
              ),
              items: app.products.map((p) => DropdownMenuItem(
                value: p.id,
                child: Text(
                  en ? p.nameEn : p.nameAr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )).toList(),
              onChanged: (v) => setState(() => _productId = v),
            ),
            const SizedBox(height: 8),
            TextField(controller: _supplier, decoration: InputDecoration(hintText: en ? 'Supplier' : '\u0627\u0644\u0645\u0648\u0631\u062f')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: _qty, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: en ? 'Quantity' : '\u0627\u0644\u0643\u0645\u064a\u0629'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _costPrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(hintText: en ? 'Cost price / unit' : '\u0633\u0639\u0631 \u0627\u0644\u062a\u0643\u0644\u0641\u0629 / \u0648\u062d\u062f\u0629'))),
              ],
            ),
            const SizedBox(height: 12),
            GossButton(
              label: en ? 'Record purchase' : '\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u0634\u0631\u0627\u0621',
              color: GossColors.navy,
              onPressed: () async {
                if (app.token == null || _productId == null || _saving) return;
                final qty = int.tryParse(_qty.text) ?? 0;
                final cost = double.tryParse(_costPrice.text) ?? 0;
                if (qty <= 0) return;
                setState(() => _saving = true);
                try {
                  await admin.savePurchase(app.token!, {
                    'supplier': _supplier.text,
                    'productId': _productId,
                    'qty': qty,
                    'costPrice': cost,
                    'total': cost * qty,
                  });
                  _supplier.clear();
                  _qty.clear();
                  _costPrice.clear();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(en
                          ? 'Unable to record the purchase. Check your connection.'
                          : 'تعذر تسجيل الشراء. تحقق من الاتصال.'),
                      duration: const Duration(seconds: 3),
                    ));
                  }
                } finally {
                  if (mounted) setState(() => _saving = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(String date) {
    try {
      final d = DateTime.parse(date).toLocal();
      return DateFormat('yyyy-MM-dd').format(d);
    } catch (_) {
      return date;
    }
  }

  String _productName(AppProvider app, bool en, String productId) {
    final product = app.products.where((x) => x.id == productId).toList();
    return product.isNotEmpty ? (en ? product.first.nameEn : product.first.nameAr) : productId;
  }

Future<void> _editPurchase(
    BuildContext context, AppProvider app, AdminProvider admin, bool en, Purchase p) async {
  final data = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _PurchaseEditDialog(purchase: p, products: app.products, en: en),
  );
  if (data == null || !mounted) return;
  try {
    await admin.updatePurchase(app.token!, p.id, data);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(en ? 'Purchase updated.' : '\u062a\u0645 \u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0634\u0631\u0627\u0621.'),
        backgroundColor: GossColors.green,
      ));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(en
            ? 'Unable to update the purchase. Check your connection.'
            : '\u062a\u0639\u0630\u0631 \u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0634\u0631\u0627\u0621. \u062a\u062d\u0642\u0642 \u0645\u0646 \u0627\u0644\u0627\u062a\u0635\u0627\u0644.'),
        backgroundColor: GossColors.red,
      ));
    }
  }
}

Widget _purchaseRow(BuildContext context, AppProvider app, AdminProvider admin, bool en, Purchase p) {
    final name = _productName(app, en, p.productId);
    return Card(
      child: ListTile(
        title: Text('$name \u00d7 ${p.qty}'),
        subtitle: Text(
          '${p.supplier.isEmpty ? '-' : p.supplier} | ${en ? 'EGP' : '\u062c.\u0645'} ${p.total.toStringAsFixed(2)}',
          textDirection: TextDirection.ltr,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: en ? 'Edit purchase' : '\u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0634\u0631\u0627\u0621',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _editPurchase(context, app, admin, en, p),
            ),
            IconButton(
              tooltip: en ? 'Delete purchase' : '\u062d\u0630\u0641 \u0627\u0644\u0634\u0631\u0627\u0621',
              icon: const Icon(Icons.delete, size: 18, color: GossColors.red),
              onPressed: () async {
                if (app.token == null) return;
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(en ? 'Delete purchase' : '\u062d\u0630\u0641 \u0627\u0644\u0634\u0631\u0627\u0621'),
                    content: Text(en
                        ? 'Delete this purchase record ($name \u00d7 ${p.qty})?'
                        : '\u062d\u0630\u0641 \u0647\u0630\u0627 \u0627\u0644\u0633\u062c\u0644 ($name \u00d7 ${p.qty})\u061f'),
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
                  await admin.deletePurchase(app.token!, p.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(en ? 'Purchase deleted.' : '\u062a\u0645 \u062d\u0630\u0641 \u0627\u0644\u0634\u0631\u0627\u0621.'),
                      backgroundColor: GossColors.green,
                    ));
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(en
                          ? 'Unable to delete the purchase. Check your connection.'
                          : '\u062a\u0639\u0630\u0631 \u062d\u0630\u0641 \u0627\u0644\u0634\u0631\u0627\u0621. \u062a\u062d\u0642\u0642 \u0645\u0646 \u0627\u0644\u0627\u062a\u0635\u0627\u0644.'),
                      backgroundColor: GossColors.red,
                    ));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseEditDialog extends StatefulWidget {
  final Purchase purchase;
  final List<Product> products;
  final bool en;
  const _PurchaseEditDialog({required this.purchase, required this.products, required this.en});

  @override
  State<_PurchaseEditDialog> createState() => _PurchaseEditDialogState();
}

class _PurchaseEditDialogState extends State<_PurchaseEditDialog> {
  late final TextEditingController _supplier;
  late final TextEditingController _qty;
  late final TextEditingController _costPrice;
  late String? _productId;

  bool get _en => widget.en;

  @override
  void initState() {
    super.initState();
    _supplier = TextEditingController(text: widget.purchase.supplier);
    _qty = TextEditingController(text: '${widget.purchase.qty}');
    _costPrice = TextEditingController(
      text: widget.purchase.costPrice.toStringAsFixed(2),
    );
    _productId = widget.purchase.productId;
  }

  @override
  void dispose() {
    _supplier.dispose();
    _qty.dispose();
    _costPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_en ? 'Edit purchase' : '\u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0634\u0631\u0627\u0621'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('purch-edit-$_productId'),
                initialValue: _productId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _en ? 'Product' : '\u0627\u0644\u0645\u0646\u062a\u062c',
                  isDense: true,
                ),
                items: widget.products.map((p) => DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    _en ? p.nameEn : p.nameAr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )).toList(),
                onChanged: (v) => setState(() => _productId = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _supplier,
                decoration: InputDecoration(
                  labelText: _en ? 'Supplier' : '\u0627\u0644\u0645\u0648\u0631\u062f',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _qty,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _en ? 'Quantity' : '\u0627\u0644\u0643\u0645\u064a\u0629',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _costPrice,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _en ? 'Cost price / unit' : '\u0633\u0639\u0631 \u0627\u0644\u062a\u0643\u0644\u0641\u0629 / \u0648\u062d\u062f\u0629',
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
            Navigator.pop(context, <String, dynamic>{
              'productId': _productId ?? '',
              'supplier': _supplier.text,
              'qty': int.tryParse(_qty.text) ?? 0,
              'costPrice': double.tryParse(_costPrice.text) ?? 0,
            });
          },
          child: Text(_en ? 'Save' : '\u062d\u0641\u0638'),
        ),
      ],
    );
  }
}
