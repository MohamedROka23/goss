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

/// Builds a sheet that mirrors the real Arabic price lists: a section title on
/// its own line, a header row, then products.
Uint8List _stackedSheet({
  required String section,
  required List<List<Object?>> products,
}) {
  return _sheet([
    [section, '', ''],
    const ['اسم الصنف', 'الوحدة', 'السعر'],
    ...products,
  ]);
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
      const [
        'Category EN',
        'Category AR',
        'Product EN',
        'Product AR',
        'Unit',
        'Stock (Qty)',
        'Price (EGP)',
        'Cost (EGP)',
      ],
      ['Vegetables', 'خضروات', 'Tomato', 'طماطم', 'kg', '500', '25', '18'],
      ['Vegetables', 'خضروات', 'Potato', 'بطاطس', 'kg', '300', '15', '10'],
      ['Fruits', 'فاكهة', 'Orange', 'برتقال', 'kg', '200', '20', '14'],
    ]);
    final parsed = parseProductImport(bytes);
    expect(parsed.products.length, 3);
    expect(parsed.categories.length, 2);
    final tomato = parsed.products.firstWhere((p) => p.nameEn == 'Tomato');
    expect(tomato.price, 25);
    expect(tomato.cost, 18);
    expect(tomato.stock, 500);
    expect(tomato.categoryId, isNotEmpty);
  });

  test('keeps prices with thousands separators readable', () {
    final bytes = _sheet([
      const ['Category EN', 'Category AR', 'Product EN', 'Product AR', 'Unit', 'Stock (Qty)', 'Price (EGP)', 'Cost (EGP)'],
      ['Bulk', 'جملة', 'Rice', 'أرز', 'kg', '0', '1,250.50', '900'],
    ]);
    final parsed = parseProductImport(bytes);
    expect(parsed.products.single.price, 1250.50);
    expect(parsed.products.single.cost, 900);
  });

  test('skips rows without a product name', () {
    final bytes = _sheet([
      const ['Category EN', 'Category AR', 'Product EN', 'Product AR', 'Unit', 'Stock (Qty)', 'Price (EGP)', 'Cost (EGP)'],
      ['', '', '', '', '', '', '', ''],
      ['Veg', 'خضروات', 'Tomato', 'طماطم', 'kg', '1', '25', ''],
    ]);
    final parsed = parseProductImport(bytes);
    expect(parsed.products.length, 1);
    expect(parsed.products.single.nameEn, 'Tomato');
  });

  test('treats a repeated product in the same sheet as a duplicate', () {
    final bytes = _sheet([
      const ['Category EN', 'Category AR', 'Product EN', 'Product AR', 'Unit', 'Stock (Qty)', 'Price (EGP)', 'Cost (EGP)'],
      ['Veg', 'خضروات', 'Tomato', 'طماطم', 'kg', '', '99', ''],
      ['Veg', 'خضروات', 'Tomato', 'طماطم', 'kg', '', '99', ''],
    ]);
    final parsed = parseProductImport(bytes);
    expect(parsed.products.length, 1);
    expect(parsed.warnings.any((w) => w.contains('duplicate')), isTrue);
  });

  group('slugify', () {
    test('produces stable lowercase ids', () {
      expect(slugify('  Tomato Red  '), 'tomato-red');
      expect(slugify('Fresh Vegetables'), 'fresh-vegetables');
    });

    test('keeps Arabic text instead of collapsing it to an empty id', () {
      // The original pattern stripped everything that was not [a-z0-9], so an
      // Arabic section produced '' and its products were written with an empty
      // category: visible under "All", absent from every section.
      final id = slugify('مشروبات غازية');
      expect(id, isNotEmpty);
      expect(id, contains('مشروبات'));
    });

    test('collapses separators and trims the edges', () {
      expect(slugify('  Tomato   Red  '), 'tomato-red');
      expect(slugify('A / B : C'), 'a-b-c');
    });

    test('falls back to a positional id when nothing usable remains', () {
      final id = slugify('   ', fallbackIndex: 42);
      expect(id, isNotEmpty);
      expect(id, contains('42'));
    });

    test('applies the category prefix used by the bulk uploader', () {
      // Both paths must agree, otherwise importing the same sheet through the
      // app creates a second category beside the one the scripts created.
      expect(slugify('مشروبات غازية', prefix: 'cat'), startsWith('cat-'));
    });
  });

  group('Arabic-only sheets', () {
    test('assigns every product a non-empty category id', () {
      final bytes = _sheet([
        const ['القسم', 'المنتج', 'الوحدة', 'السعر'],
        ['مشروبات غازية', 'بيبشي & دايت', 'بالتة *24', '351.12'],
        ['مشروبات غازية', 'كوكا كولا', 'بالتة *24', '351.12'],
        ['تونة', 'تونة ذرة', 'علبة', '180.00'],
      ]);
      final parsed = parseProductImport(bytes);
      expect(parsed.products.length, 3);
      for (final p in parsed.products) {
        expect(
          p.categoryId,
          isNotEmpty,
          reason: 'product "${p.nameEn}" was left without a section',
        );
      }
      expect(parsed.categories.length, 2);
    });

    test('reuses the id of a category that already exists by name', () {
      // This is the path that keeps an app import landing on the categories
      // already in Firestore rather than forking a duplicate.
      final existing = [
        const ProductCategory(id: 'cat-مشروبات-غازية', en: 'Soft Drinks', ar: 'مشروبات غازية'),
      ];
      final bytes = _sheet([
        const ['Category EN', 'Category AR', 'Product EN', 'Product AR', 'Unit', 'Stock (Qty)', 'Price (EGP)', 'Cost (EGP)'],
        ['Soft Drinks', 'مشروبات غازية', 'بيبشي', 'بيبشي', 'بالتة', '0', '351.12', '0'],
      ]);
      final parsed = parseProductImport(
        bytes,
        existingCategories: existing,
      );
      expect(parsed.products.single.categoryId, 'cat-مشروبات-غازية');
    });

    test('handles a stacked sheet where the section sits above the header', () {
      final bytes = _stackedSheet(
        section: 'هاينز',
        products: [
          ['هاينزز( كاتش) -  كاتشب - جركن10 كجم', 'جركن10', '550.05'],
        ],
      );
      final parsed = parseProductImport(bytes);
      // The header row is consumed as a header, so only the real product row
      // is left — and it must carry a section.
      expect(parsed.products.length, 1);
      expect(parsed.products.single.price, 550.05);
      expect(parsed.products.single.categoryId, isNotEmpty);
    });
  });
}