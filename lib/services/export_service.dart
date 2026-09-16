import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';

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

  /// Sanitizes a display title into an ASCII file name so Android's
  /// FileProvider / share intent never sees Arabic, spaces or slashes.
  static String _safeFileName(String name) {
    var ext = '';
    final dot = name.lastIndexOf('.');
    if (dot != -1) {
      ext = name.substring(dot).toLowerCase();
      name = name.substring(0, dot);
    }
    var sb = StringBuffer();
    for (final unit in name.codeUnits) {
      if ((unit >= 48 && unit <= 57) || // 0-9
          (unit >= 65 && unit <= 90) || // A-Z
          (unit >= 97 && unit <= 122)) {
        sb.writeCharCode(unit);
      } else if (unit == 32) {
        sb.writeCharCode(45); // space -> hyphen
      }
    }
    var clean = sb.toString();
    while (clean.endsWith('-')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (clean.isEmpty) clean = 'GOSST-file';
    return '$clean$ext';
  }

  static Future<File> _writeToTemp(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_safeFileName(name)}');
    return file.writeAsBytes(bytes, flush: true);
  }

  static Future<void> _share(File file, String displayName) async {
    final mime = displayName.endsWith('.pdf') ? 'application/pdf'
        : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    final xfile = XFile(file.path, mimeType: mime);
    await SharePlus.instance.share(
      ShareParams(
        files: [xfile],
        fileNameOverrides: [xfile.name],
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

  /// Exports a customer price quote as a proper A4 PDF document showing the
  /// customer details, every line item, the subtotal, the optional 14% VAT,
  /// and the final total. The file is shared so the customer can save/print it.
  static Future<void> exportPriceQuote(
    CustomerRequest request, {
    required bool isArabic,
  }) async {
    final baseFont = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
    final boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
    final navy = PdfColor.fromInt(_navy);
    final stamp = _formatStamp(DateTime.now(), isArabic);

    final subtotal = request.items.fold<double>(0, (n, i) => n + i.price * i.qty);
    final vat = request.vat ? subtotal * 0.14 : 0.0;
    final total = subtotal + vat;

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('GOSST', style: pw.TextStyle(font: boldFont, fontSize: 20, color: navy)),
                pw.Text(stamp, style: pw.TextStyle(font: baseFont, fontSize: 9, color: PdfColors.blueGrey600)),
              ],
            ),
            pw.Divider(color: navy, thickness: 1.4),
            pw.SizedBox(height: 14),
            pw.Text(
              isArabic ? 'عرض سعر' : 'Price Quote',
              style: pw.TextStyle(font: boldFont, fontSize: 24, color: navy),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${isArabic ? 'رقم العرض' : 'Quote No.'}: ${request.orderLabel}',
              style: pw.TextStyle(font: baseFont, fontSize: 13, color: PdfColors.blueGrey800),
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _info((isArabic ? 'الشركة' : 'Company'), request.company.isEmpty ? '—' : request.company, baseFont),
                      _info((isArabic ? 'اسم المسؤول' : 'Contact'), request.name, baseFont),
                      _info((isArabic ? 'الهاتف' : 'Phone'), request.phone.isEmpty ? '—' : request.phone, baseFont),
                      _info((isArabic ? 'البريد' : 'Email'), request.email.isEmpty ? '—' : request.email, baseFont),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.TableHelper.fromTextArray(
              headers: [
                isArabic ? 'المنتج' : 'Item',
                isArabic ? 'الكمية' : 'Qty',
                isArabic ? 'الوحدة' : 'Unit',
                isArabic ? 'السعر' : 'Unit price',
                isArabic ? 'الإجمالي' : 'Total',
              ],
              data: request.items.map((i) => [
                isArabic ? i.nameAr : i.nameEn,
                '${i.qty}',
                i.unit,
                (isArabic ? 'ج.م ' : 'EGP ') + i.price.toStringAsFixed(2),
                (isArabic ? 'ج.م ' : 'EGP ') + (i.price * i.qty).toStringAsFixed(2),
              ]).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 11, color: PdfColors.white),
              cellStyle: pw.TextStyle(font: baseFont, fontSize: 10),
              headerDecoration: pw.BoxDecoration(color: navy),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              cellAlignments: {
                for (var i in List.generate(5, (i) => i)) i: isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
              },
              headerAlignments: {
                for (var i in List.generate(5, (i) => i)) i: isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
              },
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              columnWidths: {
                0: pw.FlexColumnWidth(4),
                1: pw.FlexColumnWidth(1.2),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(2),
                4: pw.FlexColumnWidth(2),
              },
              headerDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              tableDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            ),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Container(
                width: 260,
                child: pw.Column(
                  children: [
                    _totalRow(isArabic ? 'الإجمالي الفرعي' : 'Subtotal', subtotal, isArabic, baseFont, boldFont, navy),
                    if (request.vat) _totalRow(isArabic ? 'ضريبة 14%' : 'VAT 14%', vat, isArabic, baseFont, boldFont, navy),
                    pw.SizedBox(height: 6),
                    pw.Container(
                      height: 1.2,
                      color: navy,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(isArabic ? 'الإجمالي' : 'TOTAL', style: pw.TextStyle(font: boldFont, fontSize: 15, color: navy)),
                        pw.Text(
                          '${isArabic ? 'ج.م ' : 'EGP '}${total.toStringAsFixed(2)}',
                          style: pw.TextStyle(font: boldFont, fontSize: 15, color: navy),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (request.notes.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              pw.Text(isArabic ? 'ملاحظات' : 'Notes', style: pw.TextStyle(font: boldFont, fontSize: 12, color: navy)),
              pw.SizedBox(height: 4),
              pw.Text(request.notes, style: pw.TextStyle(font: baseFont, fontSize: 10, color: PdfColors.blueGrey800)),
            ],
            pw.Spacer(),
            pw.Center(
              child: pw.Text(
                isArabic ? 'شكراً لتعاملكم مع GOSST' : 'Thank you for choosing GOSST',
                style: pw.TextStyle(font: baseFont, fontSize: 10, color: PdfColors.blueGrey500),
              ),
            ),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    final safeCode = request.orderLabel.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    final fileName = 'GOSST_$safeCode.pdf';
    final file = await _writeToTemp(Uint8List.fromList(bytes), fileName);
    await _share(file, fileName);
  }

  static pw.Widget _info(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('$label: ', style: pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.Expanded(
            child: pw.Text(value.isEmpty ? '—' : value, style: pw.TextStyle(font: font, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(String label, double amount, bool isArabic, pw.Font base, pw.Font bold, PdfColor navy) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: base, fontSize: 12, color: PdfColors.blueGrey800)),
          pw.Text(
            '${isArabic ? 'ج.م ' : 'EGP '}${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(font: bold, fontSize: 12, color: PdfColors.blueGrey900),
          ),
        ],
      ),
    );
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