import 'package:flutter_test/flutter_test.dart';

import 'package:av_smartbilling_mobile/src/models.dart';
import 'package:av_smartbilling_mobile/src/screens/invoices_screen.dart';

void main() {
  final invoices = [
    InvoiceSummary(
      id: '1',
      invoiceNumber: 'INV-101',
      customerName: 'Anand Stores',
      issuedAt: DateTime(2026, 8, 21, 10, 30),
      totalInPaise: 125050,
      status: 'PAID',
    ),
    InvoiceSummary(
      id: '2',
      invoiceNumber: 'INV-102',
      customerName: 'Bala',
      issuedAt: DateTime(2026, 8, 22, 11),
      totalInPaise: 50000,
      status: 'UNPAID',
    ),
  ];

  test('filters invoices by number, customer, status, date and amount', () {
    expect(filterInvoices(invoices, '101').single.id, '1');
    expect(filterInvoices(invoices, 'anand').single.id, '1');
    expect(filterInvoices(invoices, 'unpaid').single.id, '2');
    expect(filterInvoices(invoices, '22/08/2026').single.id, '2');
    expect(filterInvoices(invoices, '1250.50').single.id, '1');
  });

  test('supports multiple search words and returns all for blank search', () {
    expect(filterInvoices(invoices, 'anand paid').single.id, '1');
    expect(filterInvoices(invoices, '   '), hasLength(2));
    expect(filterInvoices(invoices, 'missing'), isEmpty);
  });
}
