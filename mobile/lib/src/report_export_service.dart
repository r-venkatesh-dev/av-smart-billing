import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'models.dart';

class ReportExportService {
  static final _date = DateFormat('dd MMM yyyy');
  static final _dateTime = DateFormat('dd MMM yyyy, hh:mm a');

  String _fileBase(SalesReport report) =>
      'av-smartbilling-sales-${DateFormat('yyyyMMdd').format(report.from)}-${DateFormat('yyyyMMdd').format(report.to)}';

  Future<void> shareCsv(SalesReport report) async {
    final rows = <List<Object?>>[
      [
        'Invoice Number',
        'Date',
        'Customer',
        'Payment Method',
        'Status',
        'Subtotal',
        'Discount',
        'GST',
        'Total',
      ],
      ...report.invoices.map(
        (row) => [
          row.invoiceNumber,
          row.issuedAt.toLocal().toIso8601String(),
          row.customerName,
          row.paymentMethod,
          row.status,
          row.subtotalInPaise / 100,
          row.discountInPaise / 100,
          row.taxInPaise / 100,
          row.totalInPaise / 100,
        ],
      ),
    ];
    final csv = rows
        .map((row) => row.map((value) => _csvCell('$value')).join(','))
        .join('\r\n');
    await _share(
      Uint8List.fromList(utf8.encode('\ufeff$csv')),
      '${_fileBase(report)}.csv',
      'text/csv',
    );
  }

  Future<void> shareExcel(SalesReport report) async {
    final workbook = Excel.createExcel();
    final sheet = workbook['Sales Report'];
    workbook.delete('Sheet1');
    sheet.appendRow([
      TextCellValue('Invoice Number'),
      TextCellValue('Date'),
      TextCellValue('Customer'),
      TextCellValue('Payment Method'),
      TextCellValue('Status'),
      TextCellValue('Subtotal (Rs)'),
      TextCellValue('Discount (Rs)'),
      TextCellValue('GST (Rs)'),
      TextCellValue('Total (Rs)'),
    ]);
    for (final row in report.invoices) {
      sheet.appendRow([
        TextCellValue(row.invoiceNumber),
        TextCellValue(_dateTime.format(row.issuedAt.toLocal())),
        TextCellValue(row.customerName),
        TextCellValue(row.paymentMethod),
        TextCellValue(row.status),
        DoubleCellValue(row.subtotalInPaise / 100),
        DoubleCellValue(row.discountInPaise / 100),
        DoubleCellValue(row.taxInPaise / 100),
        DoubleCellValue(row.totalInPaise / 100),
      ]);
    }
    final bytes = workbook.save();
    if (bytes == null) throw Exception('Could not create the Excel report.');
    await _share(
      Uint8List.fromList(bytes),
      '${_fileBase(report)}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<void> sharePdf(SalesReport report) async {
    final document = pw.Document(title: 'AV Smartbilling Sales Report');
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Text(
            'AV Smartbilling - Sales Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('${_date.format(report.from)} to ${_date.format(report.to)}'),
          pw.SizedBox(height: 16),
          pw.Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _summary('Invoices', '${report.invoiceCount}'),
              _summary('Total sales', _rs(report.totalSales)),
              _summary('Collected', _rs(report.collected)),
              _summary('Outstanding', _rs(report.outstanding)),
              _summary('GST', _rs(report.totalTax)),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Invoice',
              'Date',
              'Customer',
              'Payment',
              'Status',
              'GST',
              'Total',
            ],
            data: report.invoices
                .map(
                  (row) => [
                    row.invoiceNumber,
                    _date.format(row.issuedAt.toLocal()),
                    row.customerName,
                    row.paymentMethod,
                    row.status,
                    _rs(row.taxInPaise),
                    _rs(row.totalInPaise),
                  ],
                )
                .toList(),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
    await _share(
      await document.save(),
      '${_fileBase(report)}.pdf',
      'application/pdf',
    );
  }

  pw.Widget _summary(String label, String value) => pw.Container(
    width: 120,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );

  Future<void> _share(Uint8List bytes, String name, String mimeType) =>
      SharePlus.instance.share(
        ShareParams(
          title: 'AV Smartbilling Sales Report',
          text: 'Sales report exported from AV Smartbilling.',
          files: [XFile.fromData(bytes, mimeType: mimeType)],
          fileNameOverrides: [name],
        ),
      );

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';
  String _rs(int paise) => 'Rs ${(paise / 100).toStringAsFixed(2)}';
}
