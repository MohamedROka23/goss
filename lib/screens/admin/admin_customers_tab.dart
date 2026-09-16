import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/admin_provider.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class AdminCustomersTab extends StatefulWidget {
  const AdminCustomersTab({super.key});

  @override
  State<AdminCustomersTab> createState() => _AdminCustomersTabState();
}

class _AdminCustomersTabState extends State<AdminCustomersTab> {
  final _selected = <String>{};
  DateTime? _from;
  DateTime? _to;
  bool _selectAll = false;
  bool _showArchive = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matchSearch(CustomerRequest r) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return r.name.toLowerCase().contains(q) ||
        r.company.toLowerCase().contains(q) ||
        r.phone.contains(q);
  }

  static DateTime? _parse(String iso) {
    final t = DateTime.tryParse(iso);
    return t?.toLocal();
  }

  /// Group every request under a stable customer key (phone preferred).
  Map<String, List<CustomerRequest>> _byCustomer(List<CustomerRequest> all) {
    final map = <String, List<CustomerRequest>>{};
    for (final r in all) {
      final key = '${r.phone.trim()}\u0000${r.name.trim().toLowerCase()}';
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  String _customerName(String key, Map<String, List<CustomerRequest>> map) {
    final base = key.endsWith('\x00archive') ? key.substring(0, key.length - 8) : key;
    return map[base]!.first.name;
  }

  double _invoiceTotal(CustomerRequest r) {
    return r.items.fold(0.0, (n, i) => n + i.price * i.qty);
  }

  double _invoiceProfit(CustomerRequest r, List<Product> products) {
    double profit = 0;
    for (final i in r.items) {
      final matches = products.where((p) => p.id == i.productId);
      if (matches.isEmpty) continue;
      profit += (i.price - matches.first.costPrice) * i.qty;
    }
    return profit;
  }

  bool _inRange(CustomerRequest r) {
    final t = _parse(r.createdAt);
    if (t == null) return true;
    if (_from != null && t.isBefore(_from!)) return false;
    if (_to != null && !t.isBefore(_to!.add(const Duration(days: 1)))) return false;
    return true;
  }

  Future<void> _pickDate(BuildContext context, bool en) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        DateTime? f = _from;
        DateTime? t = _to;
        return StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            title: Text(en ? 'Filter by date' : 'الفلترة حسب التاريخ'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(en ? 'From' : 'من'),
                  trailing: Text(f == null ? (en ? 'Any' : 'أي') : DateFormat('yyyy-MM-dd').format(f!)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: f ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: t ?? DateTime(2100),
                    );
                    if (d != null) setSt(() => f = d);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(en ? 'To' : 'إلى'),
                  trailing: Text(t == null ? (en ? 'Any' : 'أي') : DateFormat('yyyy-MM-dd').format(t!)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: t ?? f ?? DateTime.now(),
                      firstDate: f ?? DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setSt(() => t = d);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setSt(() {
                    f = null;
                    t = null;
                  });
                  _from = null;
                  _to = null;
                  Navigator.pop(ctx);
                },
                child: Text(en ? 'Clear' : 'مسح'),
              ),
              FilledButton(
                onPressed: () {
                  _from = f;
                  _to = t;
                  Navigator.pop(ctx);
                },
                child: Text(en ? 'Apply' : 'تطبيق'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final admin = context.watch<AdminProvider>();
    final en = !app.isArabic;
    final products = app.products;
    final byCustomer = _byCustomer(admin.requests);
    final allByCustomer = <String, List<CustomerRequest>>{};
    for (final e in byCustomer.entries) {
      final activeReqs = e.value.where((r) => !r.archived).toList();
      final archivedReqs = e.value.where((r) => r.archived).toList();
      if (activeReqs.isNotEmpty) allByCustomer[e.key] = activeReqs;
      if (archivedReqs.isNotEmpty) allByCustomer['${e.key}\x00archive'] = archivedReqs;
    }
    final viewMap = _showArchive
        ? allByCustomer.entries.where((e) => e.key.endsWith('\x00archive')).toList()
        : allByCustomer.entries.where((e) => !e.key.endsWith('\x00archive')).toList();

    final filteredCustomers = viewMap.where((e) {
      return e.value.any((r) => _inRange(r) && _matchSearch(r));
    }).toList();

    final customersView = filteredCustomers.isNotEmpty
        ? filteredCustomers
        : viewMap;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                en ? 'Customers' : '\u0627\u0644\u0639\u0645\u0644\u0627\u0621',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.headingColor),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: TextButton.icon(
                onPressed: () => _pickDate(context, en),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                  _from == null && _to == null
                      ? (en ? 'Date filter' : 'فلترة بالتاريخ')
                      : (_from != null && _to != null
                          ? '${DateFormat('MM/dd').format(_from!)} - ${DateFormat('MM/dd').format(_to!)}'
                          : (_from != null
                              ? '${en ? 'From' : 'من'} ${DateFormat('MM/dd').format(_from!)}'
                              : '${en ? 'To' : 'إلى'} ${DateFormat('MM/dd').format(_to!)}')),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        Text(
          en
              ? 'Grouped by customer. Pick one or more to view their quotes and profit.'
              : '\u0645\u062c\u0645\u0639\u0629 \u062d\u0633\u0628 \u0627\u0644\u0639\u0645\u064a\u0644. \u0627\u062e\u062a\u0631 \u0639\u0645\u064a\u0644 \u0623\u0648 \u0623\u0643\u062b\u0631 \u0644\u0639\u0631\u0636 \u0639\u0631\u0648\u0636 \u0627\u0644\u0623\u0633\u0639\u0627\u0631 \u0648\u0627\u0644\u0631\u0628\u062d.',
          style: TextStyle(color: context.mutedColor),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(en ? 'Active' : 'نشطة'), icon: const Icon(Icons.list_alt, size: 18)),
            ButtonSegment(value: true, label: Text(en ? 'Archive' : 'أرشيف'), icon: const Icon(Icons.archive_outlined, size: 18)),
          ],
          selected: {_showArchive},
          onSelectionChanged: (s) => setState(() => _showArchive = s.first),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: en ? 'Search by customer name, company or phone...' : '\u0627\u0628\u062d\u062b \u0628\u0627\u0633\u0645 \u0627\u0644\u0639\u0645\u064a\u0644 \u0623\u0648 \u0627\u0644\u0634\u0631\u0643\u0629 \u0623\u0648 \u0627\u0644\u0647\u0627\u062a\u0641...',
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Checkbox(
              value: _selectAll && customersView.length == _selected.length,
              tristate: false,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selected.addAll(customersView.map((e) => e.key));
                  } else {
                    _selected.clear();
                  }
                  _selectAll = v == true;
                });
              },
            ),
            Text(en ? 'Select all' : 'تحديد الكل'),
            const Spacer(),
            if (_selected.isNotEmpty)
              Text(
                '${_selected.length} ${en ? 'selected' : 'محدد'}',
                style: TextStyle(color: context.mutedColor, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ...customersView.map((entry) {
          final key = entry.key;
          final requests = entry.value.where(_inRange).toList();
          final isSel = _selected.contains(key);
          return Card(
            child: InkWell(
              onTap: () {
                setState(() {
                  if (_selected.contains(key)) {
                    _selected.remove(key);
                  } else {
                    _selected.add(key);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Checkbox(value: isSel, onChanged: null),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${requests.first.name} \u00b7 ${requests.first.company}',
                            style: TextStyle(fontWeight: FontWeight.w700, color: context.bodyColor),
                          ),
                          Text(
                            '${requests.first.phone}  \u2022  ${en ? 'quotes' : 'عروض'}: ${requests.length}',
                            style: TextStyle(color: context.mutedColor, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        if (_selected.isNotEmpty)
          ..._buildDetails(context, en, allByCustomer, products, _selected),
      ],
    );
  }

  List<Widget> _buildDetails(
    BuildContext context,
    bool en,
    Map<String, List<CustomerRequest>> byCustomer,
    List<Product> products,
    Set<String> selected,
  ) {
    double grandTotal = 0;
    double grandProfit = 0;
    final cards = <Widget>[];

    for (final key in selected.where((k) => byCustomer[k] != null)) {
      final requests = byCustomer[key]!.where(_inRange).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final name = _customerName(key, byCustomer);
      double custTotal = 0;
      double custProfit = 0;

      cards.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          name,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: context.headingColor),
        ),
      ));

      for (final r in requests) {
        final t = _invoiceTotal(r);
        final p = _invoiceProfit(r, products);
        custTotal += t;
        custProfit += p;
        final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(_parse(r.createdAt) ?? DateTime.now());
        cards.add(Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      r.orderLabel,
                      style: TextStyle(
                        color: GossColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(dateStr, style: TextStyle(color: context.mutedColor, fontSize: 12)),
                    const Spacer(),
                    Text(requestStatusLabel(r.status, ar: !en), style: TextStyle(
                      color: requestStatusColor(r.status),
                      fontSize: 12,
                    )),
                  ],
                ),
                const Divider(height: 12),
                ...r.items.map((i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        '${en ? i.nameEn : i.nameAr} \u00d7 ${i.qty} ${i.unit}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    )),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${en ? 'Total' : 'الإجمالي'}: ${en ? 'EGP' : 'ج.م'} ${t.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${en ? 'Profit' : 'الربح'}: ${en ? 'EGP' : 'ج.م'} ${p.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: p >= 0 ? GossColors.green : GossColors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ));
      }

      cards.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '${en ? 'Customer total' : 'إجمالي العميل'}: ${en ? 'EGP' : 'ج.م'} ${custTotal.toStringAsFixed(2)}   \u2022   '
          '${en ? 'Customer profit' : 'ربح العميل'}: ${en ? 'EGP' : 'ج.م'} ${custProfit.toStringAsFixed(2)}',
          style: TextStyle(fontWeight: FontWeight.w800, color: context.headingColor),
        ),
      ));
      grandTotal += custTotal;
      grandProfit += custProfit;
    }

    final summary = <Widget>[
      const SizedBox(height: 8),
      Card(
        color: GossColors.navy,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                en ? 'Overall summary' : '\u0627\u0644\u0645\u0644\u062e\u0635 \u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _summaryItem(en ? 'Total sales' : 'إجمالي المبيعات', grandTotal.toStringAsFixed(2), en, Colors.white),
                  ),
                  Expanded(
                    child: _summaryItem(en ? 'Total profit' : 'إجمالي الربح', grandProfit.toStringAsFixed(2), en,
                        grandProfit >= 0 ? Colors.lightGreenAccent : Colors.redAccent),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];

    return [...cards, ...summary];
  }

  Widget _summaryItem(String label, String value, bool en, Color color) {
    return Column(
      children: [
        Text('${en ? 'EGP' : 'ج.م'} $value',
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 20)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}