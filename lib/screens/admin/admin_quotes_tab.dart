import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../services/backend_manager.dart';
import '../../services/api_service.dart';
import '../../services/translation_service.dart';
import '../../widgets/widgets.dart';

class AdminQuotesTab extends StatefulWidget {
  const AdminQuotesTab({super.key});

  @override
  State<AdminQuotesTab> createState() => _AdminQuotesTabState();
}

class _AdminQuotesTabState extends State<AdminQuotesTab> {
  final _scroll = ScrollController();
  final _nameEn = TextEditingController();
  final _nameAr = TextEditingController();
  final _descEn = TextEditingController();
  final _descAr = TextEditingController();
  final _unit = TextEditingController();
  final _price = TextEditingController();
  final _costPrice = TextEditingController();
  String _category = '';
  String? _editId;
  String _unitChoice = 'كيلو';
  bool _saving = false;
  Timer? _nameTimer;
  Timer? _descTimer;
  String _nameEnFor = '';
  String _descEnFor = '';

  @override
  void dispose() {
    _nameTimer?.cancel();
    _descTimer?.cancel();
    _scroll.dispose();
    _nameEn.dispose();
    _nameAr.dispose();
    _descEn.dispose();
    _descAr.dispose();
    _unit.dispose();
    _price.dispose();
    _costPrice.dispose();
    super.dispose();
  }

  Future<void> _translateName() async {
    final ar = _nameAr.text.trim();
    final en = await TranslationService.arToEn(ar);
    if (!mounted || _nameAr.text.trim() != ar) return;
    _nameEn.text = en;
    _nameEnFor = ar;
    setState(() {});
  }

  Future<void> _translateDesc() async {
    final ar = _descAr.text.trim();
    final en = await TranslationService.arToEn(ar);
    if (!mounted || _descAr.text.trim() != ar) return;
    _descEn.text = en;
    _descEnFor = ar;
    setState(() {});
  }

  void _onNameChanged() {
    _nameTimer?.cancel();
    _nameTimer = Timer(const Duration(milliseconds: 800), _translateName);
    setState(() {});
  }

  void _onDescChanged() {
    _descTimer?.cancel();
    _descTimer = Timer(const Duration(milliseconds: 800), _translateDesc);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                en ? 'Price quotes (Selling Price)' : '\u0639\u0631\u0648\u0636 \u0627\u0644\u0623\u0633\u0639\u0627\u0631 (\u0633\u0639\u0631 \u0627\u0644\u0628\u064a\u0639)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.headingColor),
              ),
            ),
            ExportButtons(
              title: en ? 'Products' : '\u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a',
              headers: [en ? 'Name' : '\u0627\u0644\u0627\u0633\u0645', en ? 'Category' : '\u0627\u0644\u0641\u0626\u0629', en ? 'Unit' : '\u0627\u0644\u0648\u062d\u062f\u0629', en ? 'Price' : '\u0627\u0644\u0633\u0639\u0631', en ? 'Cost' : '\u0627\u0644\u062a\u0643\u0644\u0641\u0629', en ? 'Margin' : '\u0627\u0644\u0647\u0627\u0645\u0634'],
              rows: app.products.map((p) => [
                en ? p.nameEn : p.nameAr,
                p.category,
                p.unit,
                p.price.toStringAsFixed(2),
                p.costPrice.toStringAsFixed(2),
                '${p.price > 0 ? ((p.price - p.costPrice) / p.price * 100).toStringAsFixed(1) : "0"}%',
              ]).toList(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          en ? 'The selling price is what customers see when requesting products.' : '\u0633\u0639\u0631 \u0627\u0644\u0628\u064a\u0639 \u0647\u0648 \u0645\u0627 \u064a\u0631\u0627\u0647 \u0627\u0644\u0639\u0645\u0644\u0627\u0621 \u0639\u0646\u062f \u0637\u0644\u0628 \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a.',
          style: TextStyle(color: context.mutedColor),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => _addCategoryDialog(context, app, en),
            icon: const Icon(Icons.create_new_folder_outlined, size: 20),
            label: Text(en ? 'Add section' : '\u0625\u0636\u0627\u0641\u0629 \u0642\u0633\u0645'),
          ),
        ),
        const SizedBox(height: 8),
        _buildForm(context, app, en),
        const SizedBox(height: 16),
        ..._buildCategorySections(app, en),
      ],
    );
  }

  Future<void> _addCategoryDialog(BuildContext context, AppProvider app, bool en) async {
    final res = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _AddCategoryDialog(en: en),
    );
    if (res == null || !context.mounted) return;
    final (enName, arName) = res;
    if (enName.isEmpty || arName.isEmpty) return;
    final err = await app.addCategory(en: enName, ar: arName);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err.isEmpty
          ? (en ? 'Section added. Products under it appear in quotes and purchases.'
              : '\u062a\u0645 \u0625\u0636\u0627\u0641\u0629 \u0627\u0644\u0642\u0633\u0645. \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a \u062a\u062d\u062a\u0647 \u0633\u062a\u0638\u0647\u0631 \u0641\u064a \u0639\u0631\u0648\u0636 \u0627\u0644\u0623\u0633\u0639\u0627\u0631 \u0648\u0627\u0644\u0634\u0631\u0627\u0621.')
          : err),
      duration: const Duration(seconds: 3),
    ));
  }

  List<Widget> _buildCategorySections(AppProvider app, bool en) {
    final sections = <Widget>[];
    for (final cat in app.productCategories) {
      final id = cat.id;
      final products = app.products.where((p) => p.category == id).toList();
      sections.add(
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        en ? cat.en : cat.ar,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: context.headingColor),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        _category = id;
                        setState(() {});
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scroll.hasClients) {
                            _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
                          }
                        });
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(en ? 'Add' : 'إضافة'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (products.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    en ? 'No products in this category yet.' : 'لا توجد منتجات في هذا القسم بعد.',
                    style: TextStyle(color: context.mutedColor, fontSize: 13),
                  ),
                )
              else
                ...products.map((p) => _productRow(context, app, en, p)),
            ],
          ),
        ),
      );
      sections.add(const SizedBox(height: 16));
    }
    return sections;
  }

  Widget _buildForm(BuildContext context, AppProvider app, bool en) {
    final catIds = app.productCategories.map((c) => c.id).toList();
    final effectiveCat = catIds.contains(_category) ? _category : (catIds.isNotEmpty ? catIds.first : '');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editId == null ? (en ? 'Add quote' : '\u0625\u0636\u0627\u0641\u0629 \u0639\u0631\u0636') : (en ? 'Edit quote' : '\u062a\u0639\u062f\u064a\u0644 \u0639\u0631\u0636'),
              style: TextStyle(fontWeight: FontWeight.w700, color: context.headingColor),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameAr,
              onChanged: (_) => _onNameChanged(),
              decoration: InputDecoration(
                hintText: en ? 'Name (Arabic) *' : '\u0627\u0644\u0627\u0633\u0645 \u0628\u0627\u0644\u0639\u0631\u0628\u064a *',
              ),
            ),
            if (_nameEn.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'EN: ${_nameEn.text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: context.mutedColor, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _descAr,
              onChanged: (_) => _onDescChanged(),
              decoration: InputDecoration(
                hintText: en ? 'Description (Arabic)' : '\u0627\u0644\u0648\u0635\u0641 \u0628\u0627\u0644\u0639\u0631\u0628\u064a',
              ),
            ),
            if (_descEn.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'EN: ${_descEn.text}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: context.mutedColor, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('cat-$effectiveCat'),
              initialValue: effectiveCat.isEmpty ? null : effectiveCat,
              isExpanded: true,
              decoration: InputDecoration(labelText: en ? 'Category' : '\u0627\u0644\u0641\u0626\u0629'),
              items: [
                if (effectiveCat.isNotEmpty && !app.productCategories.any((c) => c.id == effectiveCat))
                  DropdownMenuItem(value: effectiveCat, child: Text(effectiveCat, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ...app.productCategories
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(en ? c.en : c.ar, maxLines: 1, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(controller: _unit, decoration: InputDecoration(hintText: en ? 'Unit' : '\u0627\u0644\u0648\u062d\u062f\u0629')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('unitpick-$_unitChoice'),
                    initialValue: _unitChoice,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: en ? 'Unit type' : '\u0646\u0648\u0639 \u0627\u0644\u0648\u062d\u062f\u0629'),
                    items: const ['\u0642\u0637\u0639\u0629', '\u0643\u064a\u0644\u0648', '\u0643\u0631\u062a\u0648\u0646']
                        .map((u) => DropdownMenuItem(value: u, child: Text(u, maxLines: 1, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _unitChoice = v ?? _unitChoice;
                      _unit.text = _unitChoice;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(hintText: en ? 'Selling Price (EGP)' : '\u0633\u0639\u0631 \u0627\u0644\u0628\u064a\u0639 (\u062c\u0646\u064a\u0647)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _costPrice,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(hintText: en ? 'Cost Price (EGP)' : '\u0633\u0639\u0631 \u0627\u0644\u062a\u0643\u0644\u0641\u0629 (\u062c\u0646\u064a\u0647)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                GossButton(
                  label: en ? 'Save quote' : '\u062d\u0641\u0638 \u0627\u0644\u0639\u0631\u0636',
                  color: GossColors.blue,
                  onPressed: _saving
                      ? null
                      : () async {
                          if (app.token == null || _nameAr.text.trim().isEmpty) return;
                          setState(() => _saving = true);
                          try {
                            if (_nameEnFor != _nameAr.text.trim()) {
                              _nameEn.text = await TranslationService.arToEn(_nameAr.text.trim());
                              _nameEnFor = _nameAr.text.trim();
                            }
                            if (_descEnFor != _descAr.text.trim()) {
                              _descEn.text = await TranslationService.arToEn(_descAr.text.trim());
                              _descEnFor = _descAr.text.trim();
                            }
                            double? oldPrice;
                            if (_editId != null) {
                              final cur = app.products.where((p) => p.id == _editId).toList();
                              if (cur.isNotEmpty) oldPrice = cur.first.price;
                            }
                            final newPrice = double.tryParse(_price.text) ?? 0;
                            final data = <String, dynamic>{
                              if (_editId != null) 'id': _editId,
                              'category': _category,
                              'unit': _unit.text.isEmpty ? 'unit' : _unit.text,
                              'price': newPrice,
                              'costPrice': double.tryParse(_costPrice.text) ?? 0,
                              'nameEn': _nameEn.text,
                              'nameAr': _nameAr.text,
                              'descEn': _descEn.text,
                              'descAr': _descAr.text,
                            };
                            final backend = await BackendManager.resolve();
                            final saved = await backend.saveProduct(app.token!, data);
                            await app.loadProducts();
                            if (oldPrice != null && oldPrice != newPrice) {
                              await app.sendPriceUpdate(product: saved, oldPrice: oldPrice);
                              ApiService.notifyPriceUpdate(
                                productNameEn: saved.nameEn,
                                productNameAr: saved.nameAr,
                                oldPrice: oldPrice,
                                newPrice: saved.price,
                                unit: saved.unit,
                              );
                            }
                            _clearForm();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(en ? 'Product saved.' : 'تم حفظ المنتج.'),
                                duration: const Duration(seconds: 2),
                              ));
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(en ? 'Unable to save. Check your connection.' : 'تعذر الحفظ. تحقق من الاتصال.'),
                                duration: const Duration(seconds: 3),
                              ));
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                ),
                const SizedBox(width: 8),
                if (_editId != null)
                  GossButton(
                    label: en ? 'Cancel' : '\u0625\u0644\u063a\u0627\u0621',
                    color: GossColors.navy,
                    isSmall: true,
                    onPressed: _clearForm,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _productRow(BuildContext context, AppProvider app, bool en, Product p) {
    return Card(
      child: ListTile(
        title: Text(en ? p.nameEn : p.nameAr),
        subtitle: Text(
          '${en ? 'EGP' : '\u062c.\u0645'} ${p.price.toStringAsFixed(2)} / ${p.unit}\n'
          '${en ? 'Cost' : '\u0627\u0644\u062a\u0643\u0644\u0641\u0629'}: ${en ? 'EGP' : '\u062c.\u0645'} ${p.costPrice.toStringAsFixed(2)}',
          textDirection: TextDirection.ltr,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () {
                _editId = p.id;
                _nameAr.text = p.nameAr;
                _nameEn.text = p.nameEn;
                _nameEnFor = p.nameAr;
                _descAr.text = p.descAr;
                _descEn.text = p.descEn;
                _descEnFor = p.descAr;
                _unit.text = p.unit;
                const unitMap = {'kg': '\u0643\u064a\u0644\u0648', 'piece': '\u0642\u0637\u0639\u0629', 'carton': '\u0643\u0631\u062a\u0648\u0646'};
                _unitChoice = unitMap[p.unit] ?? '\u0643\u064a\u0644\u0648';
                _price.text = p.price.toString();
                _costPrice.text = p.costPrice.toString();
                _category = p.category;
                setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: GossColors.red),
              onPressed: () async {
                if (app.token == null) return;
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(en ? 'Delete product' : '\u062d\u0630\u0641 \u0627\u0644\u0645\u0646\u062a\u062c'),
                    content: Text(en
                        ? 'Delete "${p.nameEn}" permanently? Customer requests and purchases linked to it will be affected.'
                        : 'حذف "${p.nameAr}" نهائياً؟ الطلبات والمشتريات المرتبطة به ستتأثر.'),
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
                  final backend = await BackendManager.resolve();
                  await backend.deleteProduct(app.token!, p.id);
                  await app.loadProducts();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(en
                          ? 'Unable to delete the product. Check your connection.'
                          : 'تعذر حذف المنتج. تحقق من الاتصال.'),
                      duration: const Duration(seconds: 3),
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

  void _clearForm() {
    _editId = null;
    _category = '';
    _nameTimer?.cancel();
    _descTimer?.cancel();
    _nameEn.clear();
    _nameAr.clear();
    _descEn.clear();
    _descAr.clear();
    _unit.clear();
    _unitChoice = 'كيلو';
    _nameEnFor = '';
    _descEnFor = '';
    _price.clear();
    _costPrice.clear();
    setState(() {});
  }
}

class _AddCategoryDialog extends StatefulWidget {
  final bool en;
  const _AddCategoryDialog({required this.en});

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final enCtrl = TextEditingController();
  final arCtrl = TextEditingController();

  @override
  void dispose() {
    enCtrl.dispose();
    arCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, (enCtrl.text.trim(), arCtrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.en ? 'Add a new section' : '\u0625\u0636\u0627\u0641\u0629 \u0642\u0633\u0645 \u062c\u062f\u064a\u062f'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: enCtrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Name EN *'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: arCtrl,
            decoration: const InputDecoration(hintText: '\u0627\u0644\u0627\u0633\u0645 \u0628\u0627\u0644\u0639\u0631\u0628\u064a *'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.en ? 'Cancel' : '\u0625\u0644\u063a\u0627\u0621'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.en ? 'Add' : '\u0625\u0636\u0627\u0641\u0629'),
        ),
      ],
    );
  }
}
