import 'package:flutter_test/flutter_test.dart';

import 'package:av_smartbilling_mobile/src/models.dart';
import 'package:av_smartbilling_mobile/src/whatsapp_service.dart';

void main() {
  const service = WhatsAppService();

  InvoiceDetail invoice({String phone = '9876543210'}) => InvoiceDetail(
    invoice: {
      'customer_name': 'Anand',
      'customer_phone': phone,
      'invoice_number': 'INV-101',
      'total_in_paise': 125050,
      'status': 'PAID',
    },
    items: const [],
    business: const {'company_name': 'AV Stores'},
  );

  test('builds an India WhatsApp chat URL with invoice summary', () {
    final url = service.customerChatUrl(invoice());

    expect(url.scheme, 'https');
    expect(url.host, 'wa.me');
    expect(url.path, '/919876543210');
    expect(url.queryParameters['text'], contains('Hello Anand'));
    expect(url.queryParameters['text'], contains('INV-101'));
    expect(url.queryParameters['text'], contains('AV Stores'));
    expect(url.queryParameters['text'], contains('PAID'));
  });

  test('keeps a valid number that already includes India country code', () {
    final url = service.customerChatUrl(invoice(phone: '+91 98765 43210'));

    expect(url.path, '/919876543210');
  });

  test('rejects a missing or invalid customer mobile number', () {
    expect(
      () => service.customerChatUrl(invoice(phone: '')),
      throwsFormatException,
    );
    expect(
      () => service.customerChatUrl(invoice(phone: '1234')),
      throwsFormatException,
    );
  });
}
