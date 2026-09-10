import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  static final _arabicPattern = RegExp(r'[\u0600-\u06FF]');

  static const _navy = 0xFF0C2340;

  /// Wraps a string in Unicode right-to-left embedding markers so mixed
  /// Arabic/number cells render in the correct order everywhere.
  static String _rtlWrap(String s) =>
      _arabicPattern.hasMatch(s) ? '\u202B$s\u202C' : s;

  static String _formatStamp(DateTime d, bool ar) {
    String two(int v) => v.toString().padLeft(2, '0');
    final date =
        '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
    return ar ? 'تاريخ الإنشاء: $date' : 'Generated: $date';
  }

  static Future<File> _writeToTemp(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    return file.writeAsBytes(bytes, flush: true);
  }

  static Future<void> _share(File file, String displayName) async {
    final mime = displayName.endsWith('.pdf') ? 'application/pdf'
        : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mime)],
        fileNameOverrides: [displayName],
      ),
    );
  }

  // -------------------------------------------------------------------------
  //  PDF
  // -------------------------------------------------------------------------
  static Future<void> exportPdf({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    bool isArabic = false,
  }) async {
    final baseFont = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
    final boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Bold.ttf'));

    final navy = PdfColor.fromInt(_navy);
    final stamp = _formatStamp(DateTime.now(), isArabic);
    final align = isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft;

    // Give longer columns proportionally more width so the table fits the page.
    final weights = <double>[];
    for (var c = 0; c < headers.length; c++) {
      var maxLen = headers[c].length.toDouble();
      for (final row in rows) {
        if (c < row.length && row[c].length > maxLen) {
          maxLen = row[c].length.toDouble();
        }
      }
      weights.add((maxLen + 4).clamp(6.0, 50.0));
    }

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: .6)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('GOSST', style: pw.TextStyle(font: boldFont, fontSize: 16, color: navy)),
              pw.Text(stamp,
                  style: pw.TextStyle(font: baseFont, fontSize: 9, color: PdfColors.blueGrey500)),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(isArabic ? 'إجمالي السجلات: ${rows.length}' : 'Total records: ${rows.length}',
                  style: pw.TextStyle(font: baseFont, fontSize: 9, color: PdfColors.blueGrey500)),
              pw.Text(isArabic ? 'صفحة ${ctx.pageNumber}' : 'Page ${ctx.pageNumber}',
                  style: pw.TextStyle(font: baseFont, fontSize: 9, color: PdfColors.blueGrey500)),
            ],
          ),
        ),
        build: (ctx) => [
          pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 18, color: navy)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
            headerStyle: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.white),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: pw.BoxDecoration(color: navy),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            cellAlignments: {
              for (var i in List.generate(headers.length, (i) => i)) i: align,
            },
            headerAlignments: {
              for (var i in List.generate(headers.length, (i) => i)) i: align,
            },
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            headerPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            columnWidths: {
              for (var i = 0; i < weights.length; i++) i: pw.FlexColumnWidth(weights[i]),
            },
            headerDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            tableDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final file = await _writeToTemp(Uint8List.fromList(bytes), '$title.pdf');
    await _share(file, '$title.pdf');
  }

  // -------------------------------------------------------------------------
  //  Excel
  // -------------------------------------------------------------------------
  static Future<void> exportExcel({
    required String sheetName,
    required List<String> headers,
    required List<List<String>> rows,
    bool isArabic = false,
  }) async {
    final wb = Excel.createExcel();
    // remove default sheet
    if (wb.sheets.isNotEmpty) {
      final defaultSheet = wb.sheets.keys.first;
      wb.delete(defaultSheet);
    }
    final sheet = wb[sheetName];

    final navyHex = ExcelColor.fromHexString('FF0C2340');
    final white = ExcelColor.fromHexString('FFFFFFFF');
    final borderGrey = ExcelColor.fromHexString('FFBFBFBF');
    final zebraGrey = ExcelColor.fromHexString('FFF2F2F2');

    final thinBorder = Border(borderStyle: BorderStyle.Thin, borderColorHex: borderGrey);

    final headerStyle = CellStyle(
      fontColorHex: white,
      backgroundColorHex: navyHex,
      bold: true,
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );

    final bodyStyle = CellStyle(
      fontSize: 11,
      horizontalAlign: isArabic ? HorizontalAlign.Right : HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
    );
    final zebraStyle = bodyStyle.copyWith(backgroundColorHexVal: zebraGrey);

    for (var c = 0; c < headers.length; c++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
        TextCellValue(_rtlWrap(headers[c])),
        cellStyle: headerStyle,
      );
    }

    for (var r = 0; r < rows.length; r++) {
      final style = r.isOdd ? zebraStyle : bodyStyle;
      for (var c = 0; c < headers.length; c++) {
        final value = c < rows[r].length ? rows[r][c] : '';
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1),
          TextCellValue(_rtlWrap(value)),
          cellStyle: style,
        );
      }
    }

    sheet.setDefaultColumnWidth(24);
    sheet.setRowHeight(0, 26);

    final bytes = wb.encode();
    if (bytes == null) return;
    final file = await _writeToTemp(Uint8List.fromList(bytes), '$sheetName.xlsx');
    await _share(file, '$sheetName.xlsx');
  }
}