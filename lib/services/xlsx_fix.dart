import 'dart:typed_data';

import 'package:archive/archive.dart';

/// The `excel` package (4.0.6) always ships an empty drawing part plus a stale
/// sheet relationship in its template archive. When a sheet is rebuilt with
/// custom styles / column widths, the `<drawing r:id="rId1"/>` element inside
/// the worksheet is dropped while the relationship and `[Content_Types].xml`
/// override survive, so Microsoft Excel reports
/// "We found a problem with some content..." and offers to repair the file.
///
/// This post-processor removes those orphaned drawing artifacts and normalizes
/// a few other XML quirks (wrong `<dimension>` ref, empty `<font/>` entries)
/// so the generated workbook opens cleanly in Excel, LibreOffice and Google
/// Sheets. It is safe because the GOSST exports never embed real drawings.
Uint8List fixXlsxArtifacts(Uint8List raw) {
  final archive = ZipDecoder().decodeBytes(raw);
  final outFiles = <ArchiveFile>[];

  for (final file in archive) {
    final name = file.name;

    // Drop the empty drawing parts entirely (never used by GOSST exports).
    if (name.startsWith('xl/drawings/')) continue;

    // Strip the drawing relationship from each worksheet .rels. If nothing
    // remains, drop the relationship file itself.
    if (name.startsWith('xl/worksheets/_rels/sheet') &&
        name.endsWith('.rels')) {
      var content = _text(file);
      final hadDrawing = content.contains('relationships/drawing');
      if (hadDrawing) {
        content =
            content.replaceAll(RegExp(r'<Relationship[^>]*drawing[^>]*/>\s*'), '');
        content = content.replaceAll(
            RegExp(r'<Relationship[^>]*Target="\.\./drawings/[^"]*"[^>]*/>\s*'),
            '');
        if (!content.contains('<Relationship')) continue;
        final bytes = _bytes(content);
        outFiles.add(ArchiveFile(name, bytes.length, bytes));
        continue;
      }
    }

    // Remove the empty `<drawing r:id="..."/>` element from worksheet XML.
    if (name.startsWith('xl/worksheets/sheet') && name.endsWith('.xml')) {
      var content = _text(file);
      final before = content.length;
      content = content.replaceAll(RegExp(r'<drawing\s[^>]*/>\s*'), '');
      content = _fixDimension(content);
      if (content.length != before) {
        final bytes = _bytes(content);
        outFiles.add(ArchiveFile(name, bytes.length, bytes));
        continue;
      }
    }

    // Drop the drawing content-type override.
    if (name == '[Content_Types].xml') {
      var content = _text(file);
      final before = content.length;
      content = content.replaceAll(
        RegExp(r'<Override[^>]*PartName="[^"]*drawings[^"]*"[^>]*/>\s*'),
        '',
      );
      content = content.replaceAll(
        RegExp(r'<Default[^>]*Extension="emf"[^>]*/>\s*'), '',
      );
      content = content.replaceAll(
        RegExp(r'<Default[^>]*Extension="png"[^>]*/>\s*'), '',
      );
      if (content.length != before) {
        final bytes = _bytes(content);
        outFiles.add(ArchiveFile(name, bytes.length, bytes));
        continue;
      }
    }

    // Remove empty `<font/>` entries left by the package and fix the count.
    if (name == 'xl/styles.xml') {
      var content = _text(file);
      final before = content.length;
      content = content.replaceAll('<font/></fonts>', '</fonts>');
      final fontCount = RegExp(r'<font(?:\s|>)').allMatches(content).length;
      content = content.replaceFirstMapped(
        RegExp(r'(<fonts\s+count=")\d+(")'),
        (m) => '${m[1]}$fontCount${m[2]}',
      );
      if (content.length != before) {
        final bytes = _bytes(content);
        outFiles.add(ArchiveFile(name, bytes.length, bytes));
        continue;
      }
    }

    outFiles.add(file);
  }

  final out = Archive();
  for (final f in outFiles) {
    out.addFile(f);
  }
  return Uint8List.fromList(ZipEncoder().encode(out)!);
}

/// Replaces a wrong `<dimension ref="A1"/>` with the real used cell range so
/// Excel does not need to recalculate/tolerate an inconsistent reference.
String _fixDimension(String worksheetXml) {
  final matcher = RegExp(r'<dimension\s+ref="A1"\s*/>');
  if (!matcher.hasMatch(worksheetXml)) return worksheetXml;

  var maxCol = 0;
  var maxRow = 0;
  for (final m in RegExp(r'<c\s+r="([A-Z]+)(\d+)"').allMatches(worksheetXml)) {
    final col = _colIndex(m.group(1)!.toUpperCase());
    final row = int.tryParse(m.group(2) ?? '') ?? 0;
    if (col > maxCol) maxCol = col;
    if (row > maxRow) maxRow = row;
  }

  if (maxCol <= 0 && maxRow <= 0) return worksheetXml;
  final last = '${_colLetters(maxCol)}$maxRow';
  return worksheetXml.replaceAll(
      matcher, '<dimension ref="${'A1:$last'}" />');
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