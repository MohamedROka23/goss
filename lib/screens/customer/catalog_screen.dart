import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import 'my_orders_screen.dart';

class CatalogScreen extends StatefulWidget {
  final String? initialCategory;
  final ValueNotifier<int>? cartSignal;
  final bool showBack;
  const CatalogScreen({super.key, this.initialCategory, this.cartSignal, this.showBack = false});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String _search = '';
  late String _category;
  bool _showCart = false;
  bool _sent = false;
  bool _submitting = false;
  String? _error;

  final _companyCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _originCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final Map<String, TextEditingController> _qtyCtrls = {};

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? 'all';
    widget.cartSignal?.addListener(_onCartSignal);
  }

  void _onCartSignal() {
    if (!mounted) return;
    setState(() {
      _showCart = true;
      _error = null;
      _sent = false;
    });
  }

  void _resetForm() {
    _companyCtrl.clear();
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _emailCtrl.clear();
    _notesCtrl.clear();
    _originCtrl.clear();
    _destinationCtrl.clear();
  }

  @override
  void dispose() {
    widget.cartSignal?.removeListener(_onCartSignal);
    _companyCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    _originCtrl.dispose();
    _destinationCtrl.dispose();
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _qtyController(String productId, int qty) {
    final c = _qtyCtrls.putIfAbsent(productId, () => TextEditingController(text: '$qty'));
    if (c.text != '$qty') c.text = '$qty';
    return c;
  }

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

    final body = Column(
      children: [
        Stack(
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
                en ? 'Supply Request & Product Search' : '\u0637\u0644\u0628 \u062a\u0648\u0631\u064a\u062f \u0648\u0627\u0644\u0628\u062d\u062b \u0639\u0646 \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, height: 1.5),
              ),
            ),
            if (widget.showBack)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: IconButton(
                      tooltip: en ? 'Back' : '\u0631\u062c\u0648\u0639',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black26,
                        foregroundColor: Colors.white,
                      ),
                      icon: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.arrow_forward
                            : Icons.arrow_back,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
          ],
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
                  _productGrid(filtered, app, en),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.showBack) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: body,
      );
    }
    return body;
  }

  Widget _filterBar(BuildContext context, bool en) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: en ? 'Search a product...' : '\u0627\u0628\u062d\u062b \u0639\u0646 \u0645\u0646\u062a\u062c...',
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
                  DropdownMenuItem(value: 'all', child: Text(en ? 'All categories' : '\u0643\u0644 \u0627\u0644\u0623\u0642\u0633\u0627\u0645', overflow: TextOverflow.ellipsis)),
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
              tooltip: en ? 'Your request' : '\u0637\u0644\u0628\u0643',
              icon: Badge(
                isLabelVisible: context.read<AppProvider>().cartCount > 0,
                label: Text('${context.read<AppProvider>().cartCount}'),
                child: const Icon(Icons.shopping_cart),
              ),
              onPressed: () => setState(() => _showCart = !_showCart),
            ),
          ],
        ),
      ],
    );
  }

  Widget _productGrid(List<Product> products, AppProvider app, bool en) {
    if (products.isEmpty) {
      final isCategoryEmpty = _search.trim().isEmpty && _category != 'all';
      final msg = isCategoryEmpty
          ? (en ? 'No products in this category yet.' : '\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0646\u062a\u062c\u0627\u062a \u0641\u064a \u0647\u0630\u0627 \u0627\u0644\u0642\u0633\u0645 \u0628\u0639\u062f.')
          : (en ? 'No products match your search.' : '\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0646\u062a\u062c\u0627\u062a \u0645\u0637\u0627\u0628\u0642\u0629.');
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          msg,
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
                  onAdd: () {
                    app.addToCart(p.id);
                    setState(() {
                      _showCart = true;
                      _error = null;
                      _sent = false;
                    });
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _cartPanel(BuildContext context, AppProvider app, bool en) {
    final lines = app.cartLines;
    final total = app.cartTotal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              en ? 'Customer request' : '\u0637\u0644\u0628 \u0627\u0644\u0639\u0645\u064a\u0644',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.headingColor),
            ),
            const SizedBox(height: 4),
            Text(
              en ? 'Fill your details below and send the request to Gosst admin.'
                  : '\u0627\u0643\u062a\u0628 \u0628\u064a\u0627\u0646\u0627\u062a\u0643 \u0623\u062f\u0646\u0627\u0647 \u0648\u0623\u0631\u0633\u0644 \u0627\u0644\u0637\u0644\u0628 \u0644\u0625\u062f\u0627\u0631\u0629 \u062c\u0648\u0633\u062a.',
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
                            ? 'You are offline — requests cannot be sent right now.'
                            : '\u0623\u0646\u062a \u063a\u064a\u0631 \u0645\u062a\u0635\u0644 \u0628\u0627\u0644\u0625\u0646\u062a\u0631\u0646\u062a \u2014 \u0644\u0627 \u064a\u0645\u0643\u0646 \u0625\u0631\u0633\u0627\u0644 \u0627\u0644\u0637\u0644\u0628\u0627\u062a \u062d\u0627\u0644\u064a\u0627\u064b.',
                        style: const TextStyle(
                          color: GossColors.red,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  en ? 'Add products from the catalog.' : '\u0623\u0636\u0641 \u0645\u0646\u062a\u062c\u0627\u062a \u0645\u0646 \u0627\u0644\u0643\u062a\u0627\u0644\u0648\u062c.',
                  style: TextStyle(color: context.mutedColor),
                ),
              ),
            ...lines.map((entry) {
              final item = entry.key;
              final product = entry.value;
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
                            '${en ? 'EGP' : '\u062c.\u0645'} ${(product.price * item.qty).toStringAsFixed(2)}',
                            textDirection: TextDirection.ltr,
                            style: TextStyle(color: context.mutedColor, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: en ? 'Decrease quantity' : '\u062a\u0642\u0644\u064a\u0644 \u0627\u0644\u0643\u0645\u064a\u0629',
                      icon: const Icon(Icons.remove_circle_outline, size: 22),
                      onPressed: () {
                        final n = item.qty - 1;
                        if (n < 1) {
                          _qtyCtrls.remove(item.productId)?.dispose();
                          app.removeFromCart(item.productId);
                        } else {
                          app.setCartQty(item.productId, n);
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
                            app.setCartQty(item.productId, q);
                          } else if (q == 0) {
                            _qtyCtrls.remove(item.productId)?.dispose();
                            app.removeFromCart(item.productId);
                          } else if (v.trim().isNotEmpty) {
                            final c = _qtyCtrls[item.productId];
                            if (c != null && c.text != '1') c.text = '1';
                          }
                        },
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: en ? 'Increase quantity' : '\u0632\u064a\u0627\u062f\u0629 \u0627\u0644\u0643\u0645\u064a\u0629',
                      icon: const Icon(Icons.add_circle_outline, size: 22),
                      onPressed: () {
                        app.setCartQty(item.productId, (item.qty + 1).clamp(1, 9999));
                      },
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: en ? 'Remove from request' : '\u0645\u0633\u062d \u0645\u0646 \u0627\u0644\u0637\u0644\u0628',
                      icon: const Icon(Icons.delete_outline, size: 20, color: GossColors.red),
                      onPressed: () {
                        _qtyCtrls.remove(item.productId)?.dispose();
                        app.removeFromCart(item.productId);
                      },
                    ),
                  ],
                ),
              );
            }),
            const Divider(),
            Text(
              '${en ? "Estimated total" : "\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u062a\u0642\u062f\u064a\u0631\u064a"}: ${en ? 'EGP' : '\u062c.\u0645'} ${total.toStringAsFixed(2)}',
              textDirection: TextDirection.ltr,
              style: TextStyle(fontWeight: FontWeight.w700, color: context.headingColor),
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
                      en ? 'Price quote request sent. Gosst admin will review it.' : '\u062a\u0645 \u0625\u0631\u0633\u0627\u0644 \u0637\u0644\u0628 \u0639\u0631\u0636 \u0633\u0639\u0631. \u0633\u064a\u0631\u0627\u062c\u0639\u0647 \u0627\u0644\u0622\u0646 \u0644\u062f\u0649 \u0627\u0644\u0625\u062f\u0627\u0631\u0629.',
                      style: const TextStyle(color: GossColors.green, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: GossColors.green,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
                        );
                      },
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: Text(en ? 'Track it in My Orders' : '\u062a\u0627\u0628\u0639\u0647 \u0641\u064a \u0637\u0644\u0628\u0627\u062a\u064a', style: const TextStyle(fontWeight: FontWeight.w700)),
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
            if (!_sent && lines.isNotEmpty) ...[
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
          decoration: InputDecoration(hintText: en ? 'Company' : '\u0627\u0644\u0634\u0631\u0643\u0629'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(hintText: en ? 'Contact name' : '\u0627\u0633\u0645 \u0627\u0644\u0645\u0633\u0624\u0648\u0644'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(hintText: en ? 'Phone' : '\u0627\u0644\u0647\u0627\u062a\u0641'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(hintText: en ? 'Email' : '\u0627\u0644\u0628\u0631\u064a\u062f \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _originCtrl,
                decoration: InputDecoration(
                  hintText: en ? 'Origin (optional)' : '\u0627\u0644\u0627\u0646\u0637\u0644\u0627\u0642 (اختياري)',
                  prefixIcon: const Icon(Icons.trip_origin, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _destinationCtrl,
                decoration: InputDecoration(
                  hintText: en ? 'Destination (optional)' : '\u0627\u0644\u0648\u062c\u0647\u0629 (اختياري)',
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: InputDecoration(hintText: en ? 'Notes' : '\u0645\u0644\u0627\u062d\u0638\u0627\u062a'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: GossButton(
            label: en ? 'Request price quote' : '\u0637\u0644\u0628 \u0639\u0631\u0636 \u0633\u0639\u0631',
            color: GossColors.red,
            onPressed: _submitting
                ? null
                : () async {
              setState(() => _error = null);
              if (_nameCtrl.text.trim().isEmpty) {
                setState(() => _error = en ? 'Please enter your name.' : '\u0645\u0646 \u0641\u0636\u0644\u0643 \u0623\u062f\u062e\u0644 \u0627\u0633\u0645\u0643.');
                return;
              }
              if (_phoneCtrl.text.trim().isEmpty) {
                setState(() => _error = en ? 'Please enter your phone number.' : '\u0645\u0646 \u0641\u0636\u0644\u0643 \u0623\u062f\u062e\u0644 \u0631\u0642\u0645 \u0627\u0644\u0647\u0627\u062a\u0641.');
                return;
              }
              final email = _emailCtrl.text.trim();
              if (email.isNotEmpty &&
                  !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                setState(() => _error = en
                    ? 'Please enter a valid email address.'
                    : '\u0645\u0646 \u0641\u0636\u0644\u0643 \u0623\u062f\u062e\u0644 \u0628\u0631\u064a\u062f \u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a \u0635\u0627\u0644\u062d.');
                return;
              }
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(en ? 'Request price quote' : '\u0637\u0644\u0628 \u0639\u0631\u0636 \u0633\u0639\u0631'),
                  content: Text(en
                      ? 'Send this price quote request to Gosst admin? This does not affect accounting — it is for pricing review only.'
                      : '\u0647\u0644 \u062a\u0631\u064a\u062f \u0625\u0631\u0633\u0627\u0644 \u0637\u0644\u0628 \u0639\u0631\u0636 \u0633\u0639\u0631 \u0644\u0625\u062f\u0627\u0631\u0629 \u062c\u0648\u0633\u062a\u061f \u0644\u0627 \u064a\u062f\u062e\u0644 \u0641\u064a \u0627\u0644\u062d\u0633\u0627\u0628\u0627\u062a \u2014 \u0645\u0631\u062c\u0639 \u0644\u0644\u0627\u0637\u0644\u0627\u0639 \u0639\u0644\u0649 \u0627\u0644\u062a\u0633\u0639\u064a\u0631 \u0641\u0642\u0637.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(en ? 'Cancel' : '\u0625\u0644\u063a\u0627\u0621'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: GossColors.red),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(en ? 'Send' : '\u0625\u0631\u0633\u0627\u0644'),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !mounted) return;
              final app2 = context.read<AppProvider>();
              if (app2.cartLines.isEmpty) {
                if (mounted) {
                  setState(() => _error = en
                      ? 'Your cart is empty. Add products first.'
                      : '\u0633\u0644\u062a\u0643 \u0641\u0627\u0631\u063a\u0629. \u0623\u0636\u0641 \u0645\u0646\u062a\u062c\u0627\u062a \u0623\u0648\u0644\u0627\u064b.');
                }
                return;
              }
              if (_submitting) return;
              setState(() => _submitting = true);
              try {
                final app = context.read<AppProvider>();
                await app.sendRequest(
                  company: _companyCtrl.text,
                  name: _nameCtrl.text,
                  phone: _phoneCtrl.text,
                  email: _emailCtrl.text,
                  notes: _notesCtrl.text,
                  origin: _originCtrl.text,
                  destination: _destinationCtrl.text,
                  type: 'quote',
                );
                if (!mounted) return;
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
                      ? 'Failed to send the request. Check your connection and try again.'
                      : '\u0641\u0634\u0644 \u0625\u0631\u0633\u0627\u0644 \u0627\u0644\u0637\u0644\u0628. \u062a\u062d\u0642\u0642 \u0645\u0646 \u0627\u0644\u0627\u062a\u0635\u0627\u0644 \u0648\u062d\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649.';
                });
              }
            },
          ),
        ),
      ],
    );
  }
}