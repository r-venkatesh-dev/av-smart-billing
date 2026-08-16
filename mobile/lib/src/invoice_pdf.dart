import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'models.dart';

String _money(Object? paise) => 'Rs ${((paise as num?)?.toInt() ?? 0) / 100.0}'
    .replaceFirst(RegExp(r'\.0$'), '.00');

Future<Uint8List> buildInvoicePdf(InvoiceDetail detail) async {
  final invoice = detail.invoice;
  final business = detail.business;
  final document = pw.Document(
    title: invoice['invoice_number'] as String,
    author: business['company_name'] as String,
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    business['company_name'] as String,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if ((business['address'] as String).isNotEmpty)
                    pw.Text(business['address'] as String),
                  if ((business['phone'] as String).isNotEmpty)
                    pw.Text(business['phone'] as String),
                  if ((business['gstin'] as String).isNotEmpty)
                    pw.Text('GSTIN: ${business['gstin']}'),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'TAX INVOICE',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal700,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  invoice['invoice_number'] as String,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text((invoice['issued_at'] as String).substring(0, 10)),
              ],
            ),
          ],
        ),
        pw.Divider(height: 28),
        pw.Text(
          'Bill to',
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Text(
          invoice['customer_name'] as String,
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        if ((invoice['customer_phone'] as String).isNotEmpty)
          pw.Text(invoice['customer_phone'] as String),
        if ((invoice['customer_address'] as String).isNotEmpty)
          pw.Text(invoice['customer_address'] as String),
        if ((invoice['customer_gstin'] as String?)?.isNotEmpty == true)
          pw.Text('GSTIN: ${invoice['customer_gstin']}'),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headers: const ['Item', 'Qty', 'Rate', 'GST', 'Amount'],
          data: detail.items
              .map(
                (item) => [
                  item['description'],
                  '${item['quantity']} ${item['unit']}',
                  _money(item['unit_price_in_paise']),
                  '${(item['tax_rate_basis_points'] as int) / 100}%',
                  _money(
                    (item['taxable_in_paise'] as int) +
                        (item['tax_in_paise'] as int),
                  ),
                ],
              )
              .toList(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
          ),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 8,
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 230,
            child: pw.Column(
              children: [
                _totalRow('Subtotal', _money(invoice['subtotal_in_paise'])),
                if ((invoice['discount_in_paise'] as int) > 0)
                  _totalRow(
                    'Discount',
                    '- ${_money(invoice['discount_in_paise'])}',
                  ),
                _totalRow('GST', _money(invoice['tax_in_paise'])),
                pw.Divider(),
                _totalRow(
                  'Grand total',
                  _money(invoice['total_in_paise']),
                  bold: true,
                ),
                _totalRow('Payment', invoice['payment_method'] as String),
                _totalRow('Status', invoice['status'] as String),
              ],
            ),
          ),
        ),
        pw.Spacer(),
        pw.Divider(),
        pw.Center(
          child: pw.Text(
            (business['invoice_footer'] as String).isEmpty
                ? 'Thank you for your business.'
                : business['invoice_footer'] as String,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    ),
  );
  return document.save();
}

pw.Widget _totalRow(String label, String value, {bool bold = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(
            value,
            style: bold
                ? pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)
                : null,
          ),
        ],
      ),
    );

Future<void> shareInvoice(InvoiceDetail detail) async {
  await Printing.sharePdf(
    bytes: await buildInvoicePdf(detail),
    filename: '${detail.invoice['invoice_number']}.pdf',
  );
}

Future<void> printInvoice(InvoiceDetail detail) async {
  await Printing.layoutPdf(
    name: detail.invoice['invoice_number'] as String,
    onLayout: (_) => buildInvoicePdf(detail),
  );
}
