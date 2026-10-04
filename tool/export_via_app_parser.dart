import 'dart:convert';
import 'dart:io';

import '../lib/services/product_import.dart';

/// Runs the app's own in-app importer over real price-list files and writes the
/// JSON the uploader consumes.
///
/// Going through [parseProductImport] — rather than a separate parser — means
/// what lands in Firestore is exactly what the app would write if the same sheet
/// were uploaded from the Products screen. No second interpretation of the
/// file, and no chance of the two drifting apart again.
void main(List<String> args) {
  final output = args.first;
  final inputs = args.skip(1).toList();

  final products = <Map<String, dynamic>>[];
  final warnings = <String>[];

  for (final path in inputs) {
    final parsed = parseProductImport(File(path).readAsBytesSync());
    stdout.writeln('${path.split(RegExp(r'[\/\\]')).last}: '
        '${parsed.products.length} products, '
        '${parsed.categories.length} sections, '
        '${parsed.warnings.length} warnings');

    // The parser's own categories carry the ids it will write, so they are
    // forwarded rather than re-derived here.
    for (final c in parsed.categories) {
      products.add({
        'section': c.ar.isNotEmpty ? c.ar : c.en,
        'sectionId': c.id,
        'name': c.en.isNotEmpty ? c.en : c.ar,
        'unit': 'unit',
        'price': 0,
        'row': 0,
        'isCategory': true,
      });
    }
    for (final p in parsed.products) {
      warnings.addAll(parsed.warnings);
      products.add({
        'section': p.categoryId,
        'sectionId': p.categoryId,
        'name': p.nameEn,
        'nameAr': p.nameAr,
        'unit': p.unit,
        'price': p.price,
        'cost': p.cost,
        'stock': p.stock,
        'row': 0,
      });
    }
  }

  // A product must never be written without a section: an orphan shows up
  // under "All" and is unreachable from every section filter.
  final orphans = products
      .where((p) => p['isCategory'] != true)
      .where((p) => (p['section'] as String).trim().isEmpty)
      .toList();
  if (orphans.isNotEmpty) {
    stderr.writeln('ABORT: ${orphans.length} product(s) have no section.');
    for (final o in orphans.take(10)) {
      stderr.writeln('  ${o['name']}');
    }
    exit(1);
  }

  File(output).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'products': products,
      'warnings': warnings,
    }),
    flush: true,
  );

  final real = products.where((p) => p['isCategory'] != true).length;
  stdout.writeln('');
  stdout.writeln('categories: ${products.where((p) => p['isCategory'] == true).length}');
  stdout.writeln('products:   $real');
  stdout.writeln('orphans:    ${orphans.length}');
  stdout.writeln('json: $output');
}