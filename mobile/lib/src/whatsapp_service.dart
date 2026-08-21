import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'ui_helpers.dart';

class WhatsAppService {
  const WhatsAppService();

  Uri customerChatUrl(InvoiceDetail detail) {
    final invoice = detail.invoice;
    final phone = _internationalPhone(invoice['customer_phone'] as String?);
    final customerName = (invoice['customer_name'] as String?)?.trim();
    final businessName =
        (detail.business['company_name'] as String?)?.trim() ?? '';
    final invoiceNumber = (invoice['invoice_number'] as String?)?.trim() ?? '';
    final total = (invoice['total_in_paise'] as num?)?.toInt() ?? 0;
    final status = (invoice['status'] as String?)?.trim() ?? '';

    final message = <String>[
      'Hello ${customerName?.isNotEmpty == true ? customerName : 'Customer'},',
      '',
      'Your invoice $invoiceNumber from $businessName is ready.',
      'Total: ${money(total)}',
      if (status.isNotEmpty) 'Payment status: $status',
      '',
      'Thank you.',
    ].join('\n');

    return Uri.https('wa.me', '/$phone', {'text': message});
  }

  Future<void> openCustomerChat(InvoiceDetail detail) async {
    final opened = await launchUrl(
      customerChatUrl(detail),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw Exception(
        'Could not open WhatsApp. Please check that WhatsApp is installed.',
      );
    }
  }

  String _internationalPhone(String? rawPhone) {
    var digits = (rawPhone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length == 10) return '91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return digits;
    throw const FormatException(
      'Add a valid 10-digit customer mobile number before opening WhatsApp.',
    );
  }
}
