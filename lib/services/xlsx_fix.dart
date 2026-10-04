import 'dart:typed_data';

import 'package:archive/archive.dart';

/// The `excel` package (4.0.6) writes workbooks that Microsoft Excel refuses
/// to open cleanly:
///   * it always ships an empty drawing part plus a stale sheet relationship;
///     when a sheet is rebuilt those references go stale, leaving an orphaned
///     relationship;
///   * a rebuilt sheet is emitted with the `<sheetFormatPr>`, `<dimension>`
///     and `<sheetViews>` children in the wrong schema order;
///   * `<sheetFormatPr>` is written without its REQUIRED `defaultRowHeight`
///     attribute;
///   * `<font>` elements can list `<b/>`/`<i/>` after `<sz>` etc., violating
///     the style schema.
///
/// Together these trigger "We found a problem with some content..." and the
/// Excel repair dialog. This post-processor regenerates those parts with a
/// valid structure. It is safe because GOSST exports never embed real
/// drawings.
Uint8List fixXlsxArtifacts(Uint8List raw) {
  final archive = ZipDecoder().decodeBytes(raw);
  final outFiles = <ArchiveFile>[];

  for (final file in archive) {
    final name = file.name;
    var replaced = false;

    // Drop the empty drawing parts entirely (never used by GOSST exports).
    if (name.startsWith('xl/drawings/')) continue;

    // Strip the drawing relationship from each worksheet .rels. If nothing
    // remains, drop the relationship file itself.
    if (name.startsWith('xl/worksheets/_rels/sheet') &&
        name.endsWith('.rels')) {
      var content = _text(file);
      content = content.replaceAll(
        RegExp(r'<Relationship[^>]*relationships/drawing[^>]*/>\s*'),
        '',
      );
      if (!RegExp(r'<Relationship\s').hasMatch(content)) continue;
      outFiles.add(ArchiveFile(name, content.length, _bytes(content)));
      continue;
    }

    // Normalize worksheet XML: correct child order, repair sheetFormatPr and
    // drop stale drawing elements left behind by the package.
    if (name.startsWith('xl/worksheets/sheet') && name.endsWith('.xml')) {
      final fixed = _fixWorksheet(_text(file));
      if (fixed != _text(file)) {
        outFiles.add(ArchiveFile(name, fixed.length, _bytes(fixed)));
        continue;
      }
    }

    // Drop the drawing content-type override + unused image extensions.
    if (name == '[Content_Types].xml') {
      var content = _text(file);
      content = content.replaceAll(
        RegExp(r'<Override[^>]*PartName="[^"]*drawings[^"]*"[^>]*/>\s*'),
        '',
      );
      content = content.replaceAll(
        RegExp(r'<Default[^>]*Extension="(?:emf|png|jpeg|jfif|bmp)"[^>]*/>\s*'),
        '',
      );
      outFiles.add(ArchiveFile(name, content.length, _bytes(content)));
      replaced = true;
    }

    // Fix corrupted `<font>` child order and empty font entries.
    if (name == 'xl/styles.xml') {
      var content = _text(file);
      content = _fixStyleFonts(content);
      outFiles.add(ArchiveFile(name, content.length, _bytes(content)));
      continue;
    }

    if (!replaced) {
      outFiles.add(file);
    }
  }

  final out = Archive();
  for (final f in outFiles) {
    out.addFile(f);
  }
  return Uint8List.fromList(ZipEncoder().encode(out)!);
}

/// Rebuilds the worksheet children in schema order:
/// `sheetPr, dimension, sheetViews, sheetFormatPr, cols, sheetData, pageMargins, ...`
String _fixWorksheet(String xml) {
  String head = '';
  var rest = xml;
  if (rest.startsWith('<?xml')) {
    final declEnd = rest.indexOf('?>');
    if (declEnd > 0) {
      head = rest.substring(0, declEnd + 2);
      rest = rest.substring(declEnd + 2);
    }
  }

  final openEnd = rest.indexOf('>');
  if (openEnd <= 0) return xml;
  final opening = rest.substring(0, openEnd + 1);
  var body = rest.substring(openEnd + 1);

  // Strip the stale drawing element the package always leaves behind.
  body = body.replaceAll(RegExp(r'<drawing\s[^>]*/>\s*'), ' ');

  final sheetPr =
      RegExp(r'<sheetPr>[\s\S]*?</sheetPr>|<sheetPr[^>]*/>')
          .firstMatch(body)?.group(0);
  final views = RegExp(r'<sheetViews>[\s\S]*?</sheetViews>')
      .firstMatch(body)?.group(0);
  String? sheetFormatPr =
      RegExp(r'<sheetFormatPr[^>]*/>').firstMatch(body)?.group(0);
  final cols = RegExp(r'<cols>[\s\S]*?</cols>|<cols[^>]*/>')
      .firstMatch(body)?.group(0);
  final sheetData = RegExp(r'<sheetData>[\s\S]*?</sheetData>')
      .firstMatch(body)?.group(0);
  final margins =
      RegExp(r'<pageMargins[^>]*/>').firstMatch(body)?.group(0);

  if (sheetFormatPr != null && !sheetFormatPr.contains('defaultRowHeight')) {
    sheetFormatPr = sheetFormatPr.replaceFirst(
      '<sheetFormatPr',
      '<sheetFormatPr defaultRowHeight="15.75"',
    );
  }
  if (sheetFormatPr == null) {
    sheetFormatPr = '<sheetFormatPr defaultRowHeight="15.75"/>';
  }

  body = body
      .replaceAll(RegExp(r'<sheetPr>[\s\S]*?</sheetPr>|<sheetPr[^>]*/>'), ' ')
      .replaceAll(RegExp(r'<dimension[^>]*/>'), ' ')
      .replaceAll(RegExp(r'<sheetViews>[\s\S]*?</sheetViews>'), ' ')
      .replaceAll(RegExp(r'<sheetFormatPr[^>]*/>'), ' ')
      .replaceAll(RegExp(r'<cols>[\s\S]*?</cols>|<cols[^>]*/>'), ' ')
      .replaceAll(RegExp(r'<sheetData>[\s\S]*?</sheetData>'), ' ')
      .replaceAll(RegExp(r'<pageMargins[^>]*/>'), ' ');

  final tail = body.trim();

  final range = _computeRange(xml);
  final sb = StringBuffer()
    ..write(head)
    ..write(opening)
    ..write(' ');
  if (sheetPr != null) sb.write('$sheetPr ');
  sb.write('<dimension ref="$range" /> ');
  if (views != null) sb.write('$views ');
  sb.write('$sheetFormatPr ');
  if (cols != null) sb.write('$cols ');
  if (sheetData != null) {
    sb.write(sheetData);
  } else {
    sb.write('<sheetData/>');
  }
  if (margins != null) sb.write(' $margins');
  if (tail.isNotEmpty) sb.write(' $tail');

  return sb.toString();
}

/// Computes the used cell range, e.g. `A1:J2`, from `<c r="...">` references.
String _computeRange(String worksheetXml) {
  var maxCol = 0;
  var maxRow = 0;
  for (final m
      in RegExp(r'<c\s+r="([A-Z]+)(\d+)"').allMatches(worksheetXml)) {
    final col = _colIndex(m.group(1)!.toUpperCase());
    final row = int.tryParse(m.group(2) ?? '') ?? 0;
    if (col > maxCol) maxCol = col;
    if (row > maxRow) maxRow = row;
  }
  if (maxCol == 0 || maxRow == 0) return 'A1';
  if (maxCol == 1 && maxRow == 1) return 'A1';
  return 'A1:${_colLetters(maxCol)}$maxRow';
}

/// Reorders `<font>` children so `b/i/strike/...` come before `sz/color/name`,
/// inserts the missing `defaultRowHeight` and drops empty `<font/>` nodes.
String _fixStyleFonts(String stylesXml) {
  var content = stylesXml.replaceAll('<font/></fonts>', '</fonts>');

  final flagTags = {
    'b', 'i', 'strike', 'condense', 'extend', 'outline', 'shadow', 'u', 'vertAlign',
  };
  const valueOrder = <String>[
    'sz', 'color', 'name', 'family', 'charset', 'scheme',
  ];

  content = content.replaceAllMapped(
    RegExp(r'<font>((?:(?!</font>).)*)</font>', dotAll: true),
    (m) {
      final inner = m.group(1)!;
      final flags = <String>[];
      final values = <String>[];
      for (final tag in RegExp(r'<[a-zA-Z]+(?:\s[^>]*)?/>').allMatches(inner)) {
        final nameTag =
            RegExp(r'<([a-zA-Z]+)').firstMatch(tag.group(0)!)!.group(1)!;
        (flagTags.contains(nameTag) ? flags : values).add(tag.group(0)!);
      }
      values.sort((a, b) {
        final na = RegExp(r'<([a-zA-Z]+)').firstMatch(a)!.group(1)!;
        final nb = RegExp(r'<([a-zA-Z]+)').firstMatch(b)!.group(1)!;
        final ia = valueOrder.indexOf(na);
        final ib = valueOrder.indexOf(nb);
        if (ia == -1 && ib == -1) return 0;
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia - ib;
      });
      final sorted = [...flags, ...values].join();
      return '<font>$sorted</font>';
    },
  );

  final fontCount = RegExp(r'<font(?:\s|>)').allMatches(content).length;
  content = content.replaceFirstMapped(
    RegExp(r'(<fonts\s+count=")\d+(")'),
    (m) => '${m[1]}$fontCount${m[2]}',
  );

  return content;
}

int _colIndex(String letters) {
  var result = 0;
  for (final ch in letters.codeUnits) {
    result = result * 26 + (ch - 64);
  }
  return result;
}

String _colLetters(int index) {
  var i = index;
  final sb = StringBuffer();
  while (i > 0) {
    final rem = (i - 1) % 26;
    sb.writeCharCode(65 + rem);
    i = (i - 1) ~/ 26;
  }
  return sb.toString().split('').reversed.join();
}

String _text(ArchiveFile f) => String.fromCharCodes(f.content as List<int>);

List<int> _bytes(String s) => s.codeUnits;