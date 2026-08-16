import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../invoice_pdf.dart';
import '../models.dart';
import '../ui_helpers.dart';
import 'thermal_print_sheet.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({
    super.key,
    required this.controller,
    required this.drawer,
  });
  final AppController controller;
  final Widget drawer;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  late Future<List<InvoiceSummary>> invoices;

  @override
  void initState() {
    super.initState();
    invoices = widget.controller.database.invoices();
  }

  Future<void> _refresh() async {
    final next = widget.controller.database.invoices();
    setState(() => invoices = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: widget.drawer,
    appBar: AppBar(title: const Text('Invoices')),
    body: FutureBuilder<List<InvoiceSummary>>(
      future: invoices,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorState(
            message: errorMessage(snapshot.error!),
            onRetry: _refresh,
          );
        }
        if (!snapshot.hasData) return const LoadingView();
        if (snapshot.data!.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No invoices yet',
            message: 'Completed sales will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final invoice = snapshot.data![index];
              return Card(
                child: ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvoiceDetailScreen(
                        controller: widget.controller,
                        invoiceId: invoice.id,
                      ),
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xffe6f2f0),
                    child: const Icon(Icons.receipt, color: Color(0xff057c73)),
                  ),
                  title: Text(
                    invoice.invoiceNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${invoice.customerName}\n${DateFormat('dd MMM yyyy, hh:mm a').format(invoice.issuedAt.toLocal())}',
                  ),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(invoice.totalInPaise),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        invoice.status,
                        style: TextStyle(
                          fontSize: 11,
                          color: invoice.status == 'PAID'
                              ? Colors.green.shade700
                              : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({
    super.key,
    required this.controller,
    required this.invoiceId,
  });
  final AppController controller;
  final String invoiceId;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  late Future<InvoiceDetail> invoice;

  @override
  void initState() {
    super.initState();
    invoice = widget.controller.database.invoice(widget.invoiceId);
  }

  Future<void> _retry() async {
    final next = widget.controller.database.invoice(widget.invoiceId);
    setState(() => invoice = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Invoice')),
    body: FutureBuilder<InvoiceDetail>(
      future: invoice,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorState(
            message: errorMessage(snapshot.error!),
            onRetry: _retry,
          );
        }
        if (!snapshot.hasData) return const LoadingView();
        final detail = snapshot.data!;
        final invoice = detail.invoice;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            detail.business['company_name'] as String,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Chip(label: Text(invoice['status'] as String)),
                      ],
                    ),
                    Text(
                      invoice['invoice_number'] as String,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 28),
                    const Text(
                      'BILL TO',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      invoice['customer_name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    if ((invoice['customer_phone'] as String).isNotEmpty)
                      Text(invoice['customer_phone'] as String),
                    const SizedBox(height: 18),
                    ...detail.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['description'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${item['quantity']} ${item['unit']} × ${money(item['unit_price_in_paise'] as int)} · GST ${(item['tax_rate_basis_points'] as int) / 100}%',
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              money(
                                (item['taxable_in_paise'] as int) +
                                    (item['tax_in_paise'] as int),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 28),
                    _Amount(
                      label: 'Subtotal',
                      value: money(invoice['subtotal_in_paise'] as int),
                    ),
                    if ((invoice['discount_in_paise'] as int) > 0)
                      _Amount(
                        label: 'Discount',
                        value:
                            '- ${money(invoice['discount_in_paise'] as int)}',
                      ),
                    _Amount(
                      label: 'GST',
                      value: money(invoice['tax_in_paise'] as int),
                    ),
                    const SizedBox(height: 8),
                    _Amount(
                      label: 'Grand total',
                      value: money(invoice['total_in_paise'] as int),
                      strong: true,
                    ),
                    _Amount(
                      label: 'Payment',
                      value: invoice['payment_method'] as String,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () async {
                try {
                  await shareInvoice(detail);
                } catch (error) {
                  if (context.mounted) {
                    showMessage(
                      context,
                      'Could not share this invoice.',
                      error: true,
                    );
                  }
                }
              },
              icon: const Icon(Icons.share),
              label: const Text('Share PDF / WhatsApp'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => printInvoice(detail),
              icon: const Icon(Icons.print),
              label: const Text('Print A4 using phone'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => ThermalPrintSheet(invoice: detail),
              ),
              icon: const Icon(Icons.bluetooth),
              label: const Text('Bluetooth thermal print'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.label,
    required this.value,
    this.strong = false,
  });
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: strong
              ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)
              : null,
        ),
        Text(
          value,
          style: strong
              ? TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Theme.of(context).colorScheme.primary,
                )
              : const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
