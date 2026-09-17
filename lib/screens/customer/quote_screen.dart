import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import 'my_orders_screen.dart';

class QuoteScreen extends StatefulWidget {
  const QuoteScreen({super.key});

  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  String _search = '';
  String _category = 'all';
  bool _showCart = false;
  bool _vat = false;
  bool _sent = false;
  bool _submitting = false;
  String? _error;

  final List<CartItem> _lines = [];
  final Map<String, TextEditingController> _qtyCtrls = {};

  final _companyCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _companyCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _resetForm() {
    _companyCtrl.clear();
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _emailCtrl.clear();
    _notesCtrl.clear();
    _vat = false;
  }

  void _add(String productId) {
    final existing = _lines.where((c) => c.productId == productId);
    if (existing.isNotEmpty) {
      setState(() {
        existing.first.qty = (existing.first.qty + 1).clamp(1, 9999);
        _error = null;
        _sent = false;
      });
    } else {
      setState(() {
        _lines.add(CartItem(productId: productId, qty: 1));
        _error = null;
        _sent = false;
      });
    }
    _showCart = true;
  }

  void _remove(String productId) {
    setState(() {
      _lines.removeWhere((c) => c.productId == productId);
      _qtyCtrls.remove(productId)?.dispose();
    });
  }

  TextEditingController _qtyController(String productId, int qty) {
    final c = _qtyCtrls.putIfAbsent(productId, () => TextEditingController(text: '$qty'));
    if (c.text != '$qty') c.text = '$qty';
    return c;
  }

  double get _subtotal {
    final app = context.read<AppProvider>();
    double total = 0;
    for (final item in _lines) {
      final p = app.products.firstWhere((e) => e.id == item.productId, orElse: () => Product.fromJson(const {}));
      total += p.price * item.qty;
    }
    return total;
  }

  double get _vatAmount => _vat ? _subtotal * 0.14 : 0;

  double get _total => _subtotal + _vatAmount;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;

    final filtered = app.products.where((p) {
      final matchCat = _category == 'all' || p.category == _category;
      final q = _search.toLowerCase();
      final hay = '${p.nameEn} ${p.nameAr} ${p.descEn} ${p.descAr}'.toLowerCase();
      return matchCat && (q.isEmpty || hay.contains(q));
    }).toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [GossColors.navy, GossColors.navy2],
            ),
          ),
          child: Text(
            en ? 'Price Quote & Product Search' : 'عرض سعر والبحث عن المنتجات',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, height: 1.5),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => app.loadProducts(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _filterBar(context, en),
                  const SizedBox(height: 12),
                  if (_showCart) ...[
                    _cartPanel(context, app, en),
                    const SizedBox(height: 16),
                  ],
                  _productGrid(filtered, en),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterBar(BuildContext context, bool en) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: en ? 'Search a product...' : 'ابحث عن منتج...',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButton<String>(
                value: _category,
                isExpanded: true,
                underline: Container(height: 1, color: GossColors.navy.withValues(alpha: 0.3)),
                items: [
                  DropdownMenuItem(value: 'all', child: Text(en ? 'All categories' : 'كل الأقسام', overflow: TextOverflow.ellipsis)),
                  ...context.watch<AppProvider>().productCategories.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(en ? c.en : c.ar, overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'all'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: en ? 'Your quote' : 'عرضك',
              icon: Badge(
                isLabelVisible: _lines.isNotEmpty,
                label: Text('${_lines.length}'),
                child: const Icon(Icons.request_quote),
              ),
              onPressed: () => setState(() => _showCart = !_showCart),
            ),
          ],
        ),
      ],
    );
  }

  Widget _productGrid(List<Product> products, bool en) {
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          en ? 'No products match your search.' : 'لا توجد منتجات مطابقة.',
          style: TextStyle(color: context.mutedColor),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final avail = constraints.maxWidth;
        final cols = (avail ~/ 240).clamp(1, 5);
        final cardW = (avail - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final p in products)
              SizedBox(
                width: cardW,
                child: ProductCard(
                  product: p,
                  isArabic: !en,
                  onAdd: () => _add(p.id),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _cartPanel(BuildContext context, AppProvider app, bool en) {
    final products = _lines.map((item) {
      final p = app.products.firstWhere((e) => e.id == item.productId, orElse: () => Product.fromJson(const {}));
      return (item, p);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              en ? 'Your price quote' : 'عرض السعر الخاص بك',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.headingColor),
            ),
            const SizedBox(height: 4),
            Text(
              en
                  ? 'Send this quote to Gosst admin for pricing review.'
                  : 'أرسل هذا العرض لإدارة جوست للمراجعة والتسعير.',
              style: TextStyle(color: context.mutedColor, fontSize: 13),
            ),
            if (!app.online)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: GossColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.wifi_off, size: 18, color: GossColors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        en
                            ? 'You are offline — quotes cannot be sent right now.'
                            : 'أنت غير متصل بالإنترنت — لا يمكن إرسال العروض حالياً.',
                        style: const TextStyle(color: GossColors.red, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            if (_lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  en ? 'Add products from the catalog.' : 'أضف منتجات من الكتالوج.',
                  style: TextStyle(color: context.mutedColor),
                ),
              ),
            ...products.map((entry) {
              final item = entry.$1;
              final product = entry.$2;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            en ? product.nameEn : product.nameAr,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          Text(
                            '${en ? 'EGP' : 'ج.م'} ${(product.price * item.qty).toStringAsFixed(2)}',
                            textDirection: TextDirection.ltr,
                            style: TextStyle(color: context.mutedColor, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove_circle_outline, size: 22),
                      onPressed: () {
                        final n = item.qty - 1;
                        if (n < 1) {
                          _remove(item.productId);
                        } else {
                          setState(() => item.qty = n);
                        }
                      },
                    ),
                    SizedBox(
                      width: 44,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        controller: _qtyController(item.productId, item.qty),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 10),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          final q = int.tryParse(v);
                          if (q != null && q >= 1) {
                            setState(() => item.qty = q.clamp(1, 9999));
                          } else if (q == 0) {
                            _remove(item.productId);
                          }
                        },
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add_circle_outline, size: 22),
                      onPressed: () {
                        setState(() => item.qty = (item.qty + 1).clamp(1, 9999));
                      },
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline, size: 20, color: GossColors.red),
                      onPressed: () => _remove(item.productId),
                    ),
                  ],
                ),
              );
            }),
            const Divider(),
            CheckboxListTile(
              value: _vat,
              onChanged: _lines.isEmpty
                  ? null
                  : (v) => setState(() => _vat = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(en ? 'Add 14% VAT' : 'إضافة ضريبة 14%'),
              subtitle: Text(
                en ? 'VAT amount added to your total.' : 'تُضاف قيمة الضريبة إلى إجمالي عرض السعر.',
                style: TextStyle(color: context.mutedColor, fontSize: 12),
              ),
            ),
            if (_vat)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'VAT 14%: ${en ? 'EGP' : 'ج.م'} ${_vatAmount.toStringAsFixed(2)}',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(fontWeight: FontWeight.w600, color: context.mutedColor),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${en ? "Total" : "الإجمالي"}: ${en ? 'EGP' : 'ج.م'} ${_total.toStringAsFixed(2)}',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.headingColor),
                  ),
                ),
              ],
            ),
            if (_sent)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GossColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      en
                          ? 'Price quote sent. Gosst admin will review it.'
                          : 'تم إرسال عرض السعر. سيراجعه مدير جوست.',
                      style: const TextStyle(color: GossColors.green, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: GossColors.green, padding: EdgeInsets.zero),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
                        );
                      },
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: Text(en ? 'Track it in My Orders' : 'تابعه في طلباتي', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GossColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: GossColors.red, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            if (!_sent && _lines.isNotEmpty) ...[
              const SizedBox(height: 12),
              _requestForm(en),
            ],
          ],
        ),
      ),
    );
  }

  Widget _requestForm(bool en) {
    return Column(
      children: [
        TextField(
          controller: _companyCtrl,
          decoration: InputDecoration(hintText: en ? 'Company' : 'الشركة'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(hintText: en ? 'Contact name' : 'اسم المسؤول'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(hintText: en ? 'Phone' : 'الهاتف'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(hintText: en ? 'Email' : 'البريد الإلكتروني'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: InputDecoration(hintText: en ? 'Notes' : 'ملاحظات'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: GossButton(
            label: en ? 'Send price quote' : 'إرسال عرض سعر',
            color: GossColors.red,
            onPressed: _submitting
                ? null
                : () async {
              setState(() => _error = null);
              if (_nameCtrl.text.trim().isEmpty) {
                setState(() => _error = en ? 'Please enter your name.' : 'من فضلك أدخل اسمك.');
                return;
              }
              if (_phoneCtrl.text.trim().isEmpty) {
                setState(() => _error = en ? 'Please enter your phone number.' : 'من فضلك أدخل رقم الهاتف.');
                return;
              }
              final email = _emailCtrl.text.trim();
              if (email.isNotEmpty &&
                  !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                setState(() => _error = en
                    ? 'Please enter a valid email address.'
                    : 'من فضلك أدخل بريد إلكتروني صالح.');
                return;
              }
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(en ? 'Send price quote' : 'إرسال عرض سعر'),
                  content: Text(en
                      ? 'Send this price quote to Gosst admin? This does not affect accounting — it is for pricing review only.'
                      : 'هل تريد إرسال عرض السعر إلى إدارة جوست؟ لا يدخل في الحسابات — للمراجعة على التسعير فقط.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(en ? 'Cancel' : 'إلغاء'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: GossColors.red),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(en ? 'Send' : 'إرسال'),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !mounted) return;
              final app = context.read<AppProvider>();
              try {
                await app.sendRequest(
                  company: _companyCtrl.text,
                  name: _nameCtrl.text,
                  phone: _phoneCtrl.text,
                  email: _emailCtrl.text,
                  notes: _notesCtrl.text,
                  type: 'quote',
                  vat: _vat,
                  lines: _lines,
                );
                if (!mounted) return;
                _lines.clear();
                for (final c in _qtyCtrls.values) {
                  c.dispose();
                }
                _qtyCtrls.clear();
                _resetForm();
                setState(() {
                  _sent = true;
                  _submitting = false;
                });
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  _submitting = false;
                  _error = en
                      ? 'Failed to send the quote. Check your connection and try again.'
                      : 'فشل إرسال العرض. تحقق من الاتصال وحاول مرة أخرى.';
                });
              }
            },
          ),
        ),
      ],
    );
  }
}