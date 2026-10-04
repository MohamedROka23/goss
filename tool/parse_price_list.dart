import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';

/// Reads a multi-table price list into JSON for the Node uploader.
///
/// This sheet holds 40 stacked tables, each introduced by its own header row
/// with the supplier/section title on the line above. Header wording drifts
/// ("الصنف" / "اسم الصنف") and the unit column is variously "الوحدة" /
/// "العبوة" / "وزن الوحدة/كجم".
///
/// Column notes:
///   * col 2 is the price we want.
///   * col 3 holds a small constant (VAT-like ratio) that varies per block.
///   * col 4 holds Excel formulas rendered as text ("+D8*C8+(C8)"). Those are
///     ignored entirely — the price in col 2 is authoritative.
void main(List<String> args) {
  final input = args[0];
  final output = args[1];

  final excel = Excel.decodeBytes(File(input).readAsBytesSync());
  final sheet = excel.tables[excel.tables.keys.first]!;

  String cell(int r, int c) {
    final row = sheet.row(r);
    return row.length > c && row[c]?.value != null
        ? row[c]!.value.toString().trim()
        : '';
  }

  /// A header row names both an item column and a price column.
  bool isHeaderRow(int r) {
    final joined =
        [for (var c = 0; c < sheet.maxColumns; c++) cell(r, c)].join(' ');
    final hasName =
        joined.contains('الصنف') || joined.contains('اسم الصنف');
    final hasPrice = joined.contains('السعر');
    return hasName && hasPrice;
  }

  /// The formula column is text that starts with "=" or "+" and references
  /// cells; it must never be treated as data.
  bool isFormulaText(String v) {
    return v.startsWith('=') ||
        v.startsWith('+D') ||
        RegExp(r'^[=+][A-Z]+\d*\*').hasMatch(v);
  }

  double? num(String? raw) {
    if (raw == null) return null;
    final t = raw.replaceAll(',', '').replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (t.isEmpty || t == '.' || t == '-') return null;
    return double.tryParse(t);
  }

  final records = <Map<String, dynamic>>[];
  final warnings = <String>[];
  var section = '';

  for (var r = 0; r < sheet.maxRows; r++) {
    if (isHeaderRow(r)) {
      // The nearest non-empty cell above the header names the section.
      for (var back = r - 1; back >= 0; back--) {
        final v = cell(back, 0);
        if (v.isEmpty) continue;
        section = v;
        break;
      }
      continue;
    }

    final name = cell(r, 0);
    final unit = cell(r, 1);
    final priceRaw = cell(r, 2);

    if (name.isEmpty) continue;

    // A lone line with no unit and no price is the next section's title.
    if (unit.isEmpty && priceRaw.isEmpty) {
      section = name;
      continue;
    }

    // Skip the rendered-formula column if it ever landed in the price slot.
    if (isFormulaText(priceRaw)) continue;

    final price = num(priceRaw);
    if (price == null) {
      warnings.add('Row ${r + 1}: no usable price for "$name" (got "$priceRaw")');
      continue;
    }
    if (price <= 0) {
      warnings.add('Row ${r + 1}: price is $price for "$name"');
    }

    records.add({
      'section': section,
      'name': name,
      'unit': unit.isEmpty ? 'unit' : unit,
      'price': price,
      'row': r + 1,
    });
  }

  File(output).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'products': records,
      'warnings': warnings,
    }),
    flush: true,
  );

  final sections = records.map((e) => e['section'] as String).toSet();
  stdout.writeln('products: ${records.length}');
  stdout.writeln('sections: ${sections.length}');
  for (final s in sections) {
    final n = records.where((e) => e['section'] == s).length;
    stdout.writeln('  $s  ($n)');
  }
  stdout.writeln('warnings: ${warnings.length}');
  for (final w in warnings.take(12)) {
    stdout.writeln('  $w');
  }
  stdout.writeln('json: $output');
}