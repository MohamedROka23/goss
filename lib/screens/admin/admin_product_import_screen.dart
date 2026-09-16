import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';
import '../../providers/app_provider.dart';
import '../../services/product_import.dart';

/// Bulk products import from an Excel sheet. The admin downloads the template
/// (same columns the app uses), fills in all categories/products at once, then
/// uploads the file so everything lands in one shot.
class AdminProductImportScreen extends StatefulWidget {
  const AdminProductImportScreen({super.key});

  @override
  State<AdminProductImportScreen> createState() => _AdminProductImportScreenState();
}

class _AdminProductImportScreenState extends State<AdminProductImportScreen> {
  bool _busy = false;

  Future<void> _shareTemplate(bool en) async {
    try {
      final bytes = buildProductImportTemplate();
      if (bytes.isEmpty) throw Exception('empty template');
      // Write into the app cache (guaranteed accessible via FileProvider on
      // every Android version; getTemporaryDirectory() occasionally points to
      // a no-share zone on OEM skins).
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/GOSST-products-template.xlsx');
      await file.writeAsBytes(bytes, flush: true);
      final xfile = XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final shareResult = await SharePlus.instance.share(
        ShareParams(
          files: [xfile],
          fileNameOverrides: [xfile.name],
        ),
      );
      if (shareResult.status == ShareResultStatus.dismissed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(en
              ? 'Share sheet closed without selecting an app.'
              : 'تم إغلاق نافذة المشاركة بدون اختيار تطبيق.'),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(en
            ? 'Unable to create the template. ($e)'
            : 'تعذر إنشاء القالب. ($e)'),
        backgroundColor: GossColors.red,
      ));
    }
  }

  Future<void> _pickAndImport(AppProvider app, bool en) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls'],
    );
    if (files.isEmpty || !mounted) return;
    final bytes = await files.first.readAsBytes();
    if (bytes.isEmpty || !mounted) return;

    final parsed = parseProductImport(
      bytes,
      existingCategories: app.productCategories,
      existingProducts: app.products,
    );

    if (parsed.products.isEmpty && parsed.categories.isEmpty) {
      if (!mounted) return;
      await _showInfo(
        en
            ? 'No products found'
            : 'لم يتم العثور على منتجات',
        (parsed.warnings.isEmpty
                ? (en ? 'Check that the file follows the template columns.' : 'تأكد أن الملف يتبع أعمدة القالب.')
                : parsed.warnings.join('\n'))
            .toString(),
      );
      return;
    }

    final existingCatIds = app.productCategories.map((c) => c.id).toSet();
    final newCats = parsed.categories.where((c) => !existingCatIds.contains(c.id)).length;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(en ? 'Confirm import' : 'تأكيد الرفع'),
        content: Text(en
            ? 'This will add/update:\n\n'
                '• ${parsed.products.length} products\n'
                '• ${parsed.categories.length} sections ($newCats new)\n\n'
                'Products with the same name will be updated, not duplicated.'
            : 'سيتم إضافة/تحديث ما يلي:\n\n'
                '• ${parsed.products.length} منتج\n'
                '• ${parsed.categories.length} قسم ($newCats جديد)\n\n'
                'المنتجات الموجودة بنفس الاسم سيتم تحديثها ولن يتم تكرارها.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(en ? 'Cancel' : 'إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(en ? 'Import now' : 'رفع الآن'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final (err, catsCreated, created, updated) = await app.bulkImportProducts(
      parsed.categories.map((c) => c.toMap()).toList(),
      parsed.products.map((p) => p.toMap()).toList(),
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (err.isNotEmpty) {
      await _showInfo(en ? 'Import failed' : 'فشل الرفع', err);
      return;
    }

    final warnings = parsed.warnings.take(12).toList();
    final notes = <String>[
      en
          ? 'Done: $catsCreated sections and $created products added, $updated updated.'
          : 'تم: $catsCreated أقسام و $created منتج جديد، وتم تحديث $updated.',
      if (warnings.isNotEmpty) (en ? 'Warnings:' : 'ملاحظات:'),
      ...warnings,
      if (parsed.warnings.length > 12) (en ? '…and ${parsed.warnings.length - 12} more.' : '… و${parsed.warnings.length - 12} ملاحظات أخرى.'),
    ];
    await _showInfo(en ? 'Import complete' : 'تم الرفع بنجاح', notes.join('\n'));
  }

  Future<void> _showInfo(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;

    return Scaffold(
      appBar: AppBar(
        title: Text(en ? 'Import products from Excel' : 'رفع المنتجات من Excel'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: GossColors.navy,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(en ? 'How it works' : 'طريقة العمل',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    en
                        ? '1. Download the template.\n2. Fill each row with a product: section (EN/AR), product name (EN/AR), unit, quantity, price and cost.\n3. Upload the file – every product lands at once in quotes and purchases.'
                        : '1. نزّل القالب.\n2. املأ كل صف بمنتج: القسم (عربي/إنجليزي)، اسم المنتج (عربي/إنجليزي)، الوحدة، الكمية، سعر البيع والتكلفة.\n3. ارفع الملف — كل المنتجات تنزل مرة واحدة في عروض الأسعار والمشتريات.',
                    style: const TextStyle(color: Colors.white70, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _stepCard(
            en: en,
            title: en ? 'Download the template' : 'توليد القالب',
            subtitle: en
                ? 'An .xlsx with the exact app columns opens in the share sheet for your phone / PC.'
                : 'ملف .xlsx بنفس أعمدة البرنامج يظهر في نافذة المشاركة على موبايلك أو الكمبيوتر.',
            icon: Icons.download_outlined,
            onPressed: _busy ? null : () => _shareTemplate(en),
          ),
          const SizedBox(height: 12),
          _stepCard(
            en: en,
            title: en ? 'Upload the filled sheet' : 'رفع الملف الممتلي',
            subtitle: en
                ? 'Choose the .xlsx you filled. Existing names are updated, new ones are added.'
                : 'اختر ملف .xlsx اللي عبيته. الأسماء الموجودة تتحدث والجديدة تتضاف.',
            icon: Icons.upload_file_outlined,
            busy: _busy,
            onPressed: _busy ? null : () => _pickAndImport(app, en),
          ),
          const SizedBox(height: 16),

          Text(en ? 'Template columns (same as the app)' : 'أعمدة القالب (نفس البرنامج)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.headingColor)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _col(en ? 'Category EN / AR' : 'القسم بالإنجليزي / العربي', ': to group products under sections', ''),
                  _col(en ? 'Product EN / AR' : 'اسم المنتج بالإنجليزي / العربي', ': what customers see', ''),
                  _col(en ? 'Unit' : 'الوحدة', ': kg, carton, piece …', ''),
                  _col(en ? 'Stock (Qty)' : 'الكمية (الرصيد)', ': starting quantity', ''),
                  _col(en ? 'Price (EGP)' : 'سعر البيع (ج.م)', ': the selling price', ''),
                  _col(en ? 'Cost (EGP)' : 'سعر التكلفة (ج.م)', ': what you buy it for', ''),
                  _col(en ? 'Notes EN / AR' : 'الوصف', ': optional', ''),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _col(String label, String hint, String extra) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text.rich(
        TextSpan(text: label, style: const TextStyle(fontWeight: FontWeight.w700), children: [
          TextSpan(text: ' $hint', style: TextStyle(color: Colors.grey[600])),
        ]),
      ),
    );
  }

  Widget _stepCard({
    required bool en,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onPressed,
    bool busy = false,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: GossColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(icon, color: GossColors.blue),
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