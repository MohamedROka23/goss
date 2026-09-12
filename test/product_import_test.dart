import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:goss/models/models.dart';
import 'package:goss/services/product_import.dart';

Uint8List _sheet(List<List<Object?>> rows) {
  final wb = Excel.createExcel();
  final defaultSheet = wb.sheets.keys.first;
  if (defaultSheet != 'Products') {
    wb.rename(defaultSheet, 'Products');
  }
  final sheet = wb['Products'];
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].length; c++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        TextCellValue(rows[r][c]?.toString() ?? ''),
      );
    }
  }
  return Uint8List.fromList(wb.encode()!);
}

void main() {
  test('buildProductImportTemplate produces a readable xlsx', () {
    final bytes = buildProductImportTemplate();
    expect(bytes, isNotEmpty);
    final wb = Excel.decodeBytes(bytes);
    final sheet = wb.tables[wb.tables.keys.first]!;
    expect(sheet.maxRows, greaterThanOrEqualTo(2)); // header + sample
  });

  test('parses categories and products in one pass', () {
    final bytes = _sheet([
      const ['Category EN', 'Category AR', 'Product EN', 'Product AR', 'Unit', 'Stock (Qty)', 'Price (EGP)', 'Cost (EGP)'],
      ['Vegetables', 'خضروات', 'Tomato', 'طماطم', 'kg', '500', '25', '18'],
      ['Vegetables', 'خضروات', 'Potato', 'بطاطس', 'kg', '300', '15', '10'],
      ['Fruits', 'فواكه', 'Orange', 'برتقال', 'kg', '200', '20', '14'],
    ]);
    final parsed = parseProductImport(bytes);
    expect(parsed.categories.length, 2); // Vegetables deduped
    final vegetables = parsed.categories.firstWhere((c) => c.id == 'vegetables');
    expect(vegetables.en, 'Vegetables');
    expect(vegetables.ar, 'خضروات');
    expect(parsed.products.length, 3);
    expect(parsed.products.first.price, 25);
    expect(parsed.products.first.cost, 18);
    expect(parsed.products.first.stock, 500);
    expect(parsed.warnings, isEmpty);
  });

  test('reuses ids of existing categories and products (re-upload updates)', () {
    final bytes = _sheet([
      const ['Category EN', 'Category AR', 'Product EN', 'Product AR', 'Unit', '', 'Price (EGP)', ''],
      ['Vegetables', 'خضروات', 'Tomato', 'طماطم', 'kg', '', '30', ''],
    ]);
    final parsed = parseProductImport(
      bytes,
      existingCategories: const [ProductCategory(id: 'vegetables', en: 'Vegetables', ar: 'خضروات')],
      existingProducts: [
        Product(id: 'tomato', category: 'vegetables', unit: 'kg', price: 25, costPrice: 18, stock: 100, nameEn: 'Tomato', nameAr: 'طماطم', descEn: '', descAr: ''),
      ],
    );
    expect(parsed.categories.single.id, 'vegetables');
    expect(parsed.products.single.id, 'tomato'); // updated, not duplicated
    expect(parsed.products.single.price, 30);
  });

  test('names a category with an existing arabic/english match', () {
    final bytes = _sheet([
      const ['Category EN', 'Category AR', 'Product EN', 'Product AR', 'Unit', '', 'Price (EGP)', ''],
      ['greens_section', 'خضروات', 'Cucumber', 'خيار', 'kg', '', '10', ''],
    ]);
    final parsed = parseProductImport(
      bytes,
      existingCategories: const [ProductCategory(id: 'vegetables', en: 'Vegetables', ar: 'خضروات')],
    );
    expect(parsed.categories.single.id, 'vegetables');
  });

  test('reads currencies and commas, warns on unparsable prices, skips empty rows', () {
    final bytes = _sheet([
      const ['Category EN', 'Category AR', 'Product EN', 'Product AR', 'Unit', 'Stock (Qty)', 'Price (EGP)', 'Cost (EGP)'],
      ['Veg', 'خضار', 'Free', 'مجاني', 'kg', '1', 'EGP 1,200', '1,100'],
      ['Veg', 'خضار', 'Broken', 'مكسور', 'kg', '1', 'abc', '5'],
      ['', '', '', '', '', '', '', ''],
    ]);
    final parsed = parseProductImport(bytes);
    expect(parsed.products.where((p) => p.nameEn == 'Free').single.price, 1200);
    expect(parsed.products.where((p) => p.nameEn == 'Free').single.cost, 1100);
    expect(parsed.warnings.any((w) => w.contains('Broken')), isTrue);
    expect(parsed.products.where((p) => p.nameEn == 'Broken').single.price, 0);
    expect(parsed.products.length, 2);
  });

  test('skips duplicate product names within the same file', () {
    final bytes = _sheet([
      const ['Category EN', 'Category AR', 'Product EN', 'Product AR', 'Unit', '', 'Price (EGP)', ''],
      ['Veg', 'خضار', 'Tomato', 'طماطم', 'kg', '', '10', ''],
      ['Veg', 'خضار', 'Tomato', 'طماطم', 'kg', '', '99', ''],
    ]);
    final parsed = parseProductImport(bytes);
    expect(parsed.products.length, 1);
    expect(parsed.warnings.any((w) => w.contains('duplicate')), isTrue);
  });

  test('slugify produces stable lowercase ids', () {
    expect(slugify('  Tomato Red  '), 'tomato_red');
    expect(slugify('Fresh Vegetables'), 'fresh_vegetables');
  });
}