import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../services/export_service.dart';
import '../../widgets/widgets.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  bool _acting = false;
  bool _showArchive = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadMyRequests();
    });
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      context.read<AppProvider>().loadMyRequests(silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  int _stageStep(String status) {
    final idx = RequestStatus.stages.indexOf(status);
    if (idx >= 0) return idx;
    if (status == RequestStatus.rejected) {
      return RequestStatus.stages.indexOf(RequestStatus.delivering);
    }
    return 0;
  }

  Future<void> _decideDelivery(AppProvider app, bool en, CustomerRequest r, bool accept) async {
    if (!accept) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(en ? 'Reject delivery' : '\u0631\u0641\u0636 \u0627\u0644\u062a\u0633\u0644\u064a\u0645'),
          content: Text(en
              ? 'Are you sure you want to reject this delivery? The team will be notified and contact you.'
              : 'هل أنت متأكد من رفض هذا التسليم؟ سيتم إشعار الفريق وسيتواصلون معك.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(en ? 'Cancel' : '\u0625\u0644\u063a\u0627\u0621'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: GossColors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(en ? 'Reject' : '\u0631\u0641\u0636'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _acting = true);
    final err = await (accept ? app.acceptDelivery(r.id) : app.rejectDelivery(r.id));
    if (!mounted) return;
    setState(() => _acting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err.isEmpty
          ? (accept
              ? (en ? 'Delivery accepted. Thank you!' : 'تم قبول التسليم. شكراً لك!')
              : (en ? 'Delivery rejected.' : 'تم رفض التسليم.'))
          : err),
      backgroundColor: err.isEmpty ? GossColors.green : GossColors.red,
    ));
  }

  String _dateStr(String date) {
    try {
      return DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(date).toLocal());
    } catch (_) {
      return date;
    }
  }

  Future<void> _toggleArchive(AppProvider app, bool en, CustomerRequest r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(r.archived
            ? (en ? 'Restore order' : 'استعادة الطلب')
            : (en ? 'Archive order' : 'أرشفة الطلب')),
        content: Text(r.archived
            ? (en ? 'Restore this order to active list?' : 'استعادة هذا الطلب للقائمة النشطة؟')
            : (en ? 'Move this order to the archive?' : 'نقل هذا الطلب إلى الأرشيف؟')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(en ? 'Cancel' : 'إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(r.archived ? (en ? 'Restore' : 'استعادة') : (en ? 'Archive' : 'أرشفة')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _acting = true);
    final err = await app.archiveMyOrder(r, archived: !r.archived);
    if (!mounted) return;
    setState(() => _acting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err.isEmpty
          ? (r.archived
              ? (en ? 'Order restored.' : 'تمت استعادة الطلب.')
              : (en ? 'Order archived.' : 'تمت أرشفة الطلب.'))
          : err),
      backgroundColor: err.isEmpty ? GossColors.green : GossColors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;
    final allRequests = app.myRequests;
    final loading = app.myRequestsLoading;
    // Completed orders leave the active list automatically (they are archived
    // on the server once a terminal status is reached). The customer can still
    // restore them from the archive like the admin.
    final active = allRequests
        .where((r) => !r.archived && !RequestStatus.isDone(r.status))
        .toList();
    final archive = allRequests
        .where((r) => r.archived || RequestStatus.isDone(r.status))
        .toList();
    final visible = _showArchive ? archive : active;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GossColors.navy,
        title: Text(en ? 'My Orders' : '\u0637\u0644\u0628\u0627\u062a\u064a'),
      ),
      body: loading && allRequests.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => app.loadMyRequests(),
              child: allRequests.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        const Icon(Icons.inbox_outlined, size: 64, color: GossColors.navy2),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            en ? 'No orders yet. Send a supply request from the Supply Request tab and follow it here.' : 'لا توجد طلبات بعد. أرسل طلب توريد من قسم طلب التوريد وتابعه هنا.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.mutedColor),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          en ? 'Follow your orders live from request to delivery.' : 'تابع طلباتك لحظة بلحظة من الطلب حتى التسليم.',
                          style: TextStyle(color: context.mutedColor, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(
                              value: false,
                              label: Text(en ? 'Active' : 'نشطة'),
                              icon: const Icon(Icons.list_alt, size: 18),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text(en ? 'Archive' : '\u0623\u0631\u0634\u064a\u0641'),
                              icon: const Icon(Icons.archive_outlined, size: 18),
                            ),
                          ],
                          selected: {_showArchive},
                          onSelectionChanged: (s) => setState(() => _showArchive = s.first),
                        ),
                        const SizedBox(height: 12),
                        if (visible.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                _showArchive
                                    ? (en ? 'No archived orders' : 'لا توجد طلبات مؤرشفة')
                                    : (en ? 'No active orders' : 'لا توجد طلبات نشطة'),
                                style: TextStyle(color: context.mutedColor),
                              ),
                            ),
                          ),
                        ...visible.map((r) => _orderCard(app, en, r)),
                      ],
                    ),
            ),
    );
  }

  Widget _orderCard(AppProvider app, bool en, CustomerRequest r) {
    final step = _stageStep(r.status);
    final isQuote = r.type == 'quote';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.name} \u00b7 ${r.company.isEmpty ? (en ? 'No company' : '\u0628\u062f\u0648\u0646 \u0634\u0631\u0643\u0629') : r.company}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: context.bodyColor),
                      ),
                      Text(
                        '${r.orderLabel} \u00b7 ${_dateStr(r.createdAt)}',
                        style: TextStyle(
                          color: GossColors.navy,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isQuote ? GossColors.blue.withValues(alpha: 0.12) : GossColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isQuote ? (en ? 'Quote' : 'عرض سعر') : (en ? 'Supply' : 'طلب توريد'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isQuote ? GossColors.blue : GossColors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    RequestStatusChip(status: r.status, isArabic: !en),
                    const SizedBox(width: 4),
                    if (isQuote)
                      IconButton(
                        tooltip: en ? 'Print quote as PDF' : 'طباعة عرض السعر PDF',
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: GossColors.red),
                        visualDensity: VisualDensity.compact,
                        onPressed: _acting
                            ? null
                            : () async {
                          setState(() => _acting = true);
                          try {
                            await ExportService.exportPriceQuote(r, isArabic: !en);
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(en
                                    ? 'Could not generate the PDF. Try again.'
                                    : 'تعذر إنشاء الملف PDF. حاول مرة أخرى.'),
                                backgroundColor: GossColors.red,
                              ));
                            }
                          } finally {
                            if (mounted) setState(() => _acting = false);
                          }
                        },
                      ),
                    IconButton(
                      tooltip: r.archived
                          ? (en ? 'Restore from archive' : 'استعادة من الأرشيف')
                          : (en ? 'Archive order' : 'أرشفة الطلب'),
                      icon: Icon(
                        r.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                        size: 18,
                        color: context.mutedColor,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: _acting ? null : () => _toggleArchive(app, en, r),
                    ),
                  ],
                ),
              ],
            ),
if (isQuote && !r.converted) ...[
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: GossColors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: GossColors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        en
                            ? 'This is a price quote request - for pricing review only. It does not enter the accounting pipeline.'
                            : 'هذا طلب عرض سعر - للاطلاع على التسعير فقط. لا يدخل في النظام الحسابي.',
                        style: TextStyle(fontSize: 12.5, color: context.bodyColor, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: GossButton(
                  label: en ? 'Convert to Supply Request' : 'تحويل إلى طلب توريد',
                  color: GossColors.red,
                  icon: Icons.swap_horiz,
                  onPressed: _acting
                      ? null
                      : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(en ? 'Convert to supply request' : 'تحويل إلى طلب توريد'),
                        content: Text(en
                            ? 'Create a supply request with the same products from this quote?'
                            : 'إنشاء طلب توريد بنفس المنتجات الموجودة في هذا العرض؟'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(en ? 'Cancel' : 'إلغاء'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: GossColors.red),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(en ? 'Convert' : 'تحويل'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !mounted) return;
                    setState(() => _acting = true);
                    try {
                      await app.convertQuoteToSupply(r);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(en ? 'Supply request created successfully.' : 'تم إنشاء طلب التوريد بنجاح.'),
                        backgroundColor: GossColors.green,
                      ));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(en ? 'Failed to convert. Try again.' : 'فشل التحويل. اجرِ محاولة أخرى.'),
                        backgroundColor: GossColors.red,
                      ));
                    } finally {
                      if (mounted) setState(() => _acting = false);
                    }
                  },
                ),
              ),
            ],
            if (isQuote && r.converted) ...[
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: GossColors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18, color: GossColors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        en
                            ? 'This quote has been converted to a supply request.'
                            : 'تم تحويل هذا العرض إلى طلب توريد.',
                        style: TextStyle(fontSize: 12.5, color: context.bodyColor, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!isQuote) ...[
              const Divider(height: 20),
              Text(
                en ? 'Order journey' : 'خط سير الطلب',
                style: TextStyle(fontWeight: FontWeight.w700, color: context.headingColor, fontSize: 13),
              ),
            const SizedBox(height: 12),
            RequestStatusTimeline(step: step),
            const SizedBox(height: 8),
            Text(
              requestStatusLabel(r.status, ar: !en),
              style: TextStyle(color: requestStatusColor(r.status), fontWeight: FontWeight.w800, fontSize: 14),
            ),
            if (r.status == RequestStatus.rejected) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: GossColors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cancel_outlined, size: 18, color: GossColors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        en
                            ? 'You rejected this delivery. The team has been notified and will follow up with you.'
                            : 'قمت برفض هذا التسليم. تم إشعار الفريق وسيتواصلون معك.',
                        style: TextStyle(fontSize: 12.5, color: context.bodyColor, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (step >= 1 && r.status != RequestStatus.rejected) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: GossColors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 16, color: GossColors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        deliveryPromiseNote(ar: !en),
                        style: TextStyle(fontSize: 12.5, color: context.bodyColor, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (r.status == RequestStatus.delivering || r.status == RequestStatus.delivered) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: GossColors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  en
                      ? 'The delivery has arrived. Please accept or reject it below.'
                      : 'وصلت الشحنة للتسليم. يرجى تأكيد قبولها أو رفضها بالأسفل.',
                  style: TextStyle(fontSize: 12.5, color: context.bodyColor, height: 1.35),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GossButton(
                      label: en ? 'Accept delivery' : '\u0642\u0628\u0648\u0644 \u0627\u0644\u062a\u0633\u0644\u064a\u0645',
                      color: GossColors.green,
                      icon: Icons.verified_outlined,
                      onPressed: _acting ? null : () => _decideDelivery(app, en, r, true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GossButton(
                      label: en ? 'Reject' : '\u0631\u0641\u0636',
                      color: GossColors.red,
                      icon: Icons.cancel_outlined,
                      onPressed: _acting ? null : () => _decideDelivery(app, en, r, false),
                    ),
                  ),
                ],
              ),
            ],
            ],
            const Divider(height: 20),
            Text(
              en ? 'Items' : '\u0627\u0644\u0623\u0635\u0646\u0627\u0641',
              style: TextStyle(fontWeight: FontWeight.w700, color: context.headingColor, fontSize: 13),
            ),
            const SizedBox(height: 8),
            ...r.items.map((i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${en ? i.nameEn : i.nameAr} \u00d7 ${i.qty} ${i.unit} \u2014 ${en ? 'EGP' : '\u062c.\u0645'} ${(i.price * i.qty).toStringAsFixed(2)}',
                textDirection: TextDirection.ltr,
                style: TextStyle(fontSize: 13, color: context.bodyColor),
              ),
            )),
            if (r.origin.isNotEmpty || r.destination.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: GossColors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 16, color: GossColors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        en
                            ? '${r.origin.isEmpty ? 'Origin unspecified' : r.origin} → ${r.destination.isEmpty ? 'Destination unspecified' : r.destination}'
                            : 'من ${r.origin.isEmpty ? 'غير محددة' : r.origin} إلى ${r.destination.isEmpty ? 'غير محددة' : r.destination}',
                        style: TextStyle(fontSize: 12.5, color: context.bodyColor, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (r.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.notes, style: TextStyle(color: context.mutedColor)),
            ],
          ],
        ),
      ),
    );
  }
}