import 'dart:typed_data';

import 'package:excel/excel.dart';
import '../models/models.dart';

/// Excel bulk-import for products backed by the same columns the app uses:
/// categories/sections, product names, unit, quantity(stock), selling price,
/// cost price and descriptions. Provides both the template generator and the
/// parser so a filled sheet can be uploaded back in one shot.

class SheetCategoryRow {
  final String id;
  final String en;
  final String ar;

  const SheetCategoryRow({required this.id, required this.en, required this.ar});

  Map<String, dynamic> toMap() => {'id': id, 'en': en, 'ar': ar};
}

class SheetProductRow {
  final String id;
  final String categoryId;
  final String nameEn;
  final String nameAr;
  final String unit;
  final String descEn;
  final String descAr;
  final double price;
  final double cost;
  final double stock;

  const SheetProductRow({
    required this.id,
    required this.categoryId,
    required this.nameEn,
    required this.nameAr,
    required this.unit,
    required this.descEn,
    required this.descAr,
    required this.price,
    required this.cost,
    required this.stock,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'category': categoryId,
        'unit': unit,
        'price': price,
        'costPrice': cost,
        'stock': stock,
        'nameEn': nameEn,
        'nameAr': nameAr,
        'descEn': descEn,
        'descAr': descAr,
      };
}

class ParsedProductImport {
  final List<SheetCategoryRow> categories;
  final List<SheetProductRow> products;
  final List<String> warnings;

  const ParsedProductImport({
    required this.categories,
    required this.products,
    required this.warnings,
  });
}

/// Stable lowercase id from a name (used as the Firestore document id).
String slugify(String s) {
  var out = s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return out.replaceAll(RegExp(r'^_+|_+$'), '');
}

double? _num(String raw) {
  final t = raw.replaceAll(',', '').replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (t.isEmpty || t == '.' || t == '-') return null;
  return double.tryParse(t);
}

const List<String> _headers = [
  'Category EN',
  'Category AR',
  'Product EN',
  'Product AR',
  'Unit',
  'Stock (Qty)',
  'Price (EGP)',
  'Cost (EGP)',
  'Notes EN',
  'Notes AR',
];

const List<String> _headersAr = [
  'القسم (إنجليزي)',
  'القسم (عربي)',
  'المنتج (إنجليزي)',
  'المنتج (عربي)',
  'الوحدة',
  'الكمية (الرصيد)',
  'سعر البيع (ج.م)',
  'سعر التكلفة (ج.م)',
  'وصف (إنجليزي)',
  'وصف (عربي)',
];

/// Builds an .xlsx template the admin can edit and upload back.
Uint8List buildProductImportTemplate() {
  final wb = Excel.createExcel();
  final defaultSheet = wb.sheets.keys.first;
  if (defaultSheet != 'Products') {
    wb.rename(defaultSheet, 'Products');
  }
  final sheet = wb['Products'];

  final navy = ExcelColor.fromHexString('FF0C2340');
  final headerStyle = CellStyle(
    fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
    backgroundColorHex: navy,
    bold: true,
    fontSize: 11,
    textWrapping: TextWrapping.WrapText,
  );

  for (var c = 0; c < _headers.length; c++) {
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      TextCellValue('${_headers[c]} / ${_headersAr[c]}'),
      cellStyle: headerStyle,
    );
  }
  // One example row so the admin can see the pattern.
  const sample = ['Vegetables', 'خضروات', 'Tomato Red', 'طماطم أحمر', 'kg', '500', '25', '18', 'Fresh local', 'محلي طازج'];
  for (var c = 0; c < sample.length; c++) {
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1),
      TextCellValue(sample[c]),
    );
  }

  sheet.setDefaultColumnWidth(18);
  sheet.setRowHeight(0, 30);
  final bytes = wb.encode();
  return bytes == null ? Uint8List(0) : Uint8List.fromList(bytes);
}

/// Parses an uploaded sheet into categories and products.
/// Existing categories are matched by id or (case-insensitive) name so a
/// re-upload updates instead of duplicating.
ParsedProductImport parseProductImport(
  Uint8List bytes, {
  List<ProductCategory> existingCategories = const [],
  List<Product> existingProducts = const [],
}) {
  final warnings = <String>[];
  final categories = <String, SheetCategoryRow>{};
  final productById = <String, SheetProductRow>{};
  final seenProductEn = <String>{};

  final existingCatById = {for (final c in existingCategories) c.id: c};
  final existingProductIds = {for (final p in existingProducts) p.id};

  SheetCategoryRow categoryFor(int rowNo, String en, String ar) {
    var id = slugify(en);
    if (id.isEmpty) id = 'section';
    // Existing by id.
    if (existingCatById.containsKey(id)) {
      return categories.putIfAbsent(id, () => SheetCategoryRow(id: id, en: en, ar: ar));
    }
    // Existing by name (case-insensitive).
    for (final c in existingCategories) {
      if ((c.en.isNotEmpty && c.en.toLowerCase() == en.toLowerCase()) ||
          (c.ar.isNotEmpty && c.ar == ar)) {
        return categories.putIfAbsent(c.id, () => SheetCategoryRow(id: c.id, en: c.en, ar: c.ar));
      }
    }
    return categories.putIfAbsent(id, () => SheetCategoryRow(id: id, en: en, ar: ar));
  }

  try {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return ParsedProductImport(categories: const [], products: const [], warnings: const ['No sheets found.']);
    }
    // Prefer the Products sheet; otherwise the first populated sheet.
    var name = excel.tables.keys.first;
    if (excel.tables.containsKey('Products')) {
      name = 'Products';
    } else {
      for (final k in excel.tables.keys) {
        if ((excel.tables[k]?.maxRows ?? 0) > 0) {
          name = k;
          break;
        }
      }
    }
    final table = excel.tables[name]!;

    for (var r = 1; r < table.maxRows; r++) {
      final row = table.row(r);
      String cell(int c) => row.length > c && row[c]?.value != null ? row[c]!.value.toString().trim() : '';

      final categoryEn = cell(0);
      final categoryAr = cell(1);
      final nameEn = cell(2);
      final nameAr = cell(3);
      final unit = cell(4);
      final stockRaw = cell(5);
      final priceRaw = cell(6);
      final costRaw = cell(7);
      final descEn = cell(8);
      final descAr = cell(9);

      if (nameEn.isEmpty && nameAr.isEmpty && categoryEn.isEmpty && categoryAr.isEmpty) continue;
      if (nameEn.isEmpty && nameAr.isEmpty) {
        warnings.add('Row ${r + 1}: no product name found, skipped.');
        continue;
      }

      final price = _num(priceRaw) ?? 0;
      if (priceRaw.isNotEmpty && price == 0) {
        warnings.add('Row ${r + 1}: could not read the price "$priceRaw" for "$nameEn", set to 0.');
      }
      final cost = _num(costRaw) ?? 0;
      final stock = _num(stockRaw) ?? 0;

      var id = slugify(nameEn);
      if (id.isEmpty) id = 'product_${r + 1}';
      // Reuse the id of an existing product with the same English name so a
      // re-upload updates the price instead of creating a duplicate.
      for (final p in existingProducts) {
        if (p.nameEn.isNotEmpty && p.nameEn.toLowerCase() == nameEn.toLowerCase()) {
          id = p.id;
          break;
        }
      }
      if (productById.containsKey(id)) {
        warnings.add('Row ${r + 1}: duplicate of "${nameEn.isEmpty ? nameAr : nameEn}", skipped.');
        continue;
      }
      if (existingProductIds.contains(id) && seenProductEn.contains(nameEn.toLowerCase())) {
        continue;
      }
      if (nameEn.isNotEmpty) seenProductEn.add(nameEn.toLowerCase());

      final category = categoryFor(r + 1, categoryEn, categoryAr);
      productById[id] = SheetProductRow(
        id: id,
        categoryId: category.id,
        nameEn: nameEn,
        nameAr: nameAr.isEmpty ? nameEn : nameAr,
        unit: unit.isEmpty ? 'unit' : unit,
        descEn: descEn,
        descAr: descAr,
        price: price,
        cost: cost,
        stock: stock,
      );
    }
  } catch (e) {
    warnings.add('Could not read the file: $e');
  }

  return ParsedProductImport(
    categories: categories.values.toList(),
    products: productById.values.toList(),
    warnings: warnings,
  );
}