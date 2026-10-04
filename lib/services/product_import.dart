import 'dart:typed_data';

import 'package:excel/excel.dart';
import '../models/models.dart';
import 'xlsx_fix.dart';

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

/// Builds a stable document id from a display name.
///
/// Arabic names used to collapse to an empty string here, because the old
/// pattern kept only `[a-z0-9]`. An Arabic section therefore produced an empty
/// id, so its products were written with `category: ''` — visible under "All"
/// but unreachable from any section, and rejected outright once the category
/// rules were deployed.
///
/// The id now keeps Arabic characters (Firestore accepts them in a path),
/// normalises whitespace and separators to single hyphens, and falls back to a
/// positional id when nothing usable remains. The output format matches the
/// ids the bulk-upload scripts write, so importing the same sheet through the
/// app and through the scripts converges on one category instead of creating a
/// duplicate.
String slugify(String s, {String prefix = '', int fallbackIndex = 0}) {
  var out = s.trim().toLowerCase();
  // Anything a document path cannot carry becomes a hyphen.
  out = out.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-');
  out = out.replaceAll(RegExp(r'\s+'), '-');
  out = out.replaceAll(RegExp(r'-+'), '-');
  out = out.replaceAll(RegExp(r'^-+|-+$'), '');
  // Firestore ids cap at 1500 bytes; staying well under it also keeps ids
  // readable in the console.
  if (out.length > 120) out = out.substring(0, 120).replaceAll(RegExp(r'-+$'), '');
  if (out.isEmpty) out = 'item-$fallbackIndex';
  return prefix.isEmpty ? out : '$prefix-$out';
}

double? _num(String raw) {
  final t = raw.replaceAll(',', '').replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (t.isEmpty || t == '.' || t == '-') return null;
  return double.tryParse(t);
}

/// Whether a cell reads like a column title rather than data.
///
/// `_ColumnRoles.fromHeader` deliberately falls back to the template layout when
/// it recognises nothing, which means a plain section title can look like a
/// valid header. Checking the wording separately keeps a heading row from being
/// consumed as a header and losing the section it introduces.
bool _looksLikeColumnTitle(String text) {
  final t = text.trim();
  if (t.isEmpty) return false;
  const titles = [
    'الصنف',
    'اسم الصنف',
    'المنتج',
    'السعر',
    'الوحدة',
    'العبوة',
    'الكمية',
    'الرصيد',
    'القسم',
    'التكلفة',
    'وصف',
  ];
  if (titles.any(t.contains)) return true;
  final lower = t.toLowerCase();
  const english = [
    'product',
    'item',
    'price',
    'unit',
    'stock',
    'qty',
    'category',
    'section',
    'cost',
  ];
  return english.any(lower.contains);
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
  if (bytes == null) return Uint8List(0);
  return fixXlsxArtifacts(Uint8List.fromList(bytes));
}

/// What a column in the sheet is used for.
enum _Slot {
  category,
  categoryAlt,
  name,
  nameAlt,
  unit,
  stock,
  price,
  cost,
  desc,
  descAlt,
}

/// Maps sheet columns onto [_Slot]s.
///
/// The exported template has a fixed layout, but real price lists vary: the
/// Arabic sheets this app receives are usually `الصنف | العبوة | السعر`, and
/// they stack one table per supplier, each with its own header. Resolving roles
/// from the header text means one parser handles all of them, instead of
/// reading fixed positions and silently shifting a narrower sheet.
class _ColumnRoles {
  const _ColumnRoles(this.map);

  final Map<_Slot, int> map;

  int? operator [](_Slot slot) => map[slot];

  /// The layout the app's own template exports.
  factory _ColumnRoles.template() => const _ColumnRoles({
        _Slot.category: 0,
        _Slot.categoryAlt: 1,
        _Slot.name: 2,
        _Slot.nameAlt: 3,
        _Slot.unit: 4,
        _Slot.stock: 5,
        _Slot.price: 6,
        _Slot.cost: 7,
        _Slot.desc: 8,
        _Slot.descAlt: 9,
      });

  /// Reads the roles off a header row, accepting both English and the Arabic
  /// wording these sheets use.
  factory _ColumnRoles.fromHeader(Sheet table, int row) {
    final headerRow = table.row(row);
    final header = <int, String>{};
    for (var c = 0; c < table.maxColumns; c++) {
      final text = headerRow.length > c ? headerRow[c]?.value?.toString().trim() ?? '' : '';
      if (text.isNotEmpty) header[c] = text;
    }

    final map = <_Slot, int>{};

    void assign(_Slot slot, bool Function(String) test) {
      for (final entry in header.entries) {
        if (test(entry.value)) {
          map.putIfAbsent(slot, () => entry.key);
          return;
        }
      }
    }

assign(_Slot.category, (t) =>
        t.contains('القسم') ||
        t.contains('المورد') ||
        t.toLowerCase().contains('category') ||
        t.toLowerCase().contains('section') ||
        t.toLowerCase().contains('supplier'));
    assign(_Slot.name, (t) =>
        t.contains('اسم الصنف') ||
        t.contains('المنتج') ||
        t.contains('الصنف') ||
        t.toLowerCase().contains('product') ||
        t.toLowerCase().contains('item'));
    assign(_Slot.nameAlt, (t) =>
        t.contains('المنتج') || t.toLowerCase().contains('product ar'));
    assign(_Slot.unit, (t) =>
        t.contains('الوحدة') ||
        t.contains('العبوة') ||
        t.contains('وزن') ||
        t.toLowerCase().contains('unit') ||
        t.toLowerCase().contains('pack'));
    assign(_Slot.stock, (t) =>
        t.contains('الكمية') ||
        t.contains('الرصيد') ||
        t.toLowerCase().contains('stock') ||
        t.toLowerCase().contains('qty'));
    // Cost is matched before price so a "سعر التكلفة" column is never taken
    // as the selling price.
    assign(_Slot.cost, (t) =>
        t.contains('التكلفة') || t.toLowerCase().contains('cost'));
    assign(_Slot.price, (t) =>
        (t.contains('السعر') && !t.contains('التكلفة')) ||
        t.toLowerCase().contains('price'));
    assign(_Slot.desc, (t) =>
        t.contains('وصف') ||
        t.toLowerCase().contains('note') ||
        t.toLowerCase().contains('desc'));

    // A sheet with one name column fills both slots, so the English fallback
    // can borrow the Arabic text when building the product id.
    if (!map.containsKey(_Slot.nameAlt) && map.containsKey(_Slot.name)) {
      map[_Slot.nameAlt] = map[_Slot.name]!;
    }

    // Nothing recognisable: fall back to the template layout so a headerless
    // sheet still parses instead of dropping every row.
    if (!map.containsKey(_Slot.name) || !map.containsKey(_Slot.price)) {
      return _ColumnRoles.template();
    }
    return _ColumnRoles(map);
  }
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
    // `categoryFor` is called with a section title in the `en` slot and an empty
    // string in the `ar` slot when the sheet carries no explicit category
    // column. Falling back to whichever is populated keeps both display names
    // filled, which the category rules require and the catalogue renders.
    final nameEn = en.trim().isNotEmpty ? en.trim() : ar.trim();
    final nameAr = ar.trim().isNotEmpty ? ar.trim() : en.trim();

    // The `cat-` prefix matches what the bulk-upload scripts write, so a sheet
    // imported through the app lands on the same category document instead of
    // creating a near-duplicate beside it.
    final id = slugify(nameEn, prefix: 'cat', fallbackIndex: rowNo);
    // Existing by id.
    if (existingCatById.containsKey(id)) {
      return categories.putIfAbsent(
        id,
        () => SheetCategoryRow(id: id, en: nameEn, ar: nameAr),
      );
    }
    // Existing by name, in either language. This is what keeps a re-import of
    // a real sheet pointing at the categories already in Firestore.
    for (final c in existingCategories) {
      if ((c.en.isNotEmpty && c.en.toLowerCase() == nameEn.toLowerCase()) ||
          (c.ar.isNotEmpty && c.ar == nameAr)) {
        return categories.putIfAbsent(
          c.id,
          () => SheetCategoryRow(id: c.id, en: c.en, ar: c.ar),
        );
      }
    }
    return categories.putIfAbsent(
      id,
      () => SheetCategoryRow(id: id, en: nameEn, ar: nameAr),
    );
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

    // Column roles, resolved from the header row of whichever block is being
    // read. A real price list rarely matches the exported template exactly:
    // the sheets this app is fed are often just "الصنف | العبوة | السعر", and
    // they stack one table per supplier with its own header row. Reading
    // columns by position only — as this used to — silently shifted a 3-column
    // sheet so the price landed in the product-name column and every row was
    // dropped as nameless.
    var roles = _ColumnRoles.template();
    String? sectionTitle;
    var lastNonEmptyLine = '';

    String cellOf(int r, int c) {
      final row = table.row(r);
      return row.length > c && row[c]?.value != null
          ? row[c]!.value.toString().trim()
          : '';
    }

    for (var r = 0; r < table.maxRows; r++) {
      final rowText = [
        for (var c = 0; c < table.maxColumns; c++) cellOf(r, c),
      ].join(' ');

      // A header row names an item column and a price column.
      final looksLikeHeader =
          (rowText.contains('الصنف') || rowText.contains('اسم الصنف')) &&
              rowText.contains('السعر');

      if (looksLikeHeader) {
        roles = _ColumnRoles.fromHeader(table, r);
        // The nearest non-empty line above the header names the section. A
        // header with nothing above it keeps whatever section was already
        // established, because re-reading it as null would strand the products
        // that follow with no section at all.
        if (lastNonEmptyLine.isNotEmpty) sectionTitle = lastNonEmptyLine;
        continue;
      }

      // Row 0 is only treated as a header when it actually declares an item and
      // a price column. In these sheets row 0 is the *section title*, and
      // claiming it as a header would drop the section and leave every product
      // below it orphaned.
      if (r == 0) {
        final first = _ColumnRoles.fromHeader(table, r);
        final declaresColumns =
            first[_Slot.name] != null && first[_Slot.price] != null;
        // `_ColumnRoles.fromHeader` falls back to the template layout when it
        // recognises nothing, so a section line would "look like" a header.
        // Only accept it when the cells really read like column titles.
        final text = cellOf(r, 0);
        final looksLikeTitles = _looksLikeColumnTitle(text);
        if (declaresColumns && looksLikeTitles) {
          roles = first;
          continue;
        }
      }

      String at(_Slot slot) {
        final index = roles[slot];
        return index == null || index < 0 ? '' : cellOf(r, index);
      }

      final categoryEn = at(_Slot.category);
      final categoryAr = at(_Slot.categoryAlt);
      var nameEn = at(_Slot.name);
      var nameAr = at(_Slot.nameAlt);
      final unit = at(_Slot.unit);
      final stockRaw = at(_Slot.stock);
      final priceRaw = at(_Slot.price);
      final costRaw = at(_Slot.cost);
      final descEn = at(_Slot.desc);
      final descAr = at(_Slot.descAlt);
final hasAny = [
        nameEn,
        nameAr,
        categoryEn,
        categoryAr,
        unit,
        priceRaw,
      ].any((v) => v.isNotEmpty);
      if (!hasAny) continue;

      // No item name means this row cannot be a product. It is either the
      // heading that introduces the next block, or a stray category-only line —
      // both belong to the section bookkeeping below, not to the catalogue.
      //
      // This check has to come before the product path: above the first header
      // row the template column roles are still in force, so a section title
      // sitting in column 0 is read as a *category* with no item name, which
      // used to drop it as "no product name found".
      if (nameEn.isEmpty && nameAr.isEmpty) {
        final heading = categoryEn.isNotEmpty ? categoryEn : categoryAr;
        if (heading.isNotEmpty) {
          lastNonEmptyLine = heading;
          if (sectionTitle == null) sectionTitle = heading;
        }
        continue;
      }

      // A line carrying only an item name and nothing else is the next block's
      // section heading. Treating it as a product put entries named after their
      // own supplier into the catalogue.
      //
      // The section is remembered but must also become the *category id source*
      // for the block that follows, otherwise `categoryFor` falls back to a
      // positional id.
      if (unit.isEmpty &&
          priceRaw.isEmpty &&
          categoryEn.isEmpty &&
          categoryAr.isEmpty) {
        lastNonEmptyLine = nameEn;
        if (sectionTitle == null) sectionTitle = nameEn;
        continue;
      }

      // The Arabic column is the only name column in an Arabic-only sheet, so
      // it has to stand in for the English one. Without this the product id is
      // derived from an empty string.
      if (nameEn.isEmpty && nameAr.isNotEmpty) {
        nameEn = nameAr;
      }
      final price = _num(priceRaw) ?? 0;
      if (priceRaw.isNotEmpty && price == 0) {
        warnings.add('Row ${r + 1}: could not read the price "$priceRaw" for "$nameEn", set to 0.');
      }
      final cost = _num(costRaw) ?? 0;
      final stock = _num(stockRaw) ?? 0;

      // Positional fallback so a re-upload updates a price rather than
      // creating a duplicate of a product that already exists.
      var id = slugify(nameEn, fallbackIndex: r + 1);
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
      seenProductEn.add(nameEn.toLowerCase());

      final category = categoryFor(
        r + 1,
        categoryEn.isNotEmpty ? categoryEn : (sectionTitle ?? ''),
        categoryAr.isNotEmpty ? categoryAr : (sectionTitle ?? ''),
      );
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