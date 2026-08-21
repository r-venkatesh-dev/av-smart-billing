import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../invoice_pdf.dart';
import '../models.dart';
import '../ui_helpers.dart';
import '../whatsapp_service.dart';
import 'thermal_print_sheet.dart';

List<InvoiceSummary> filterInvoices(
  Iterable<InvoiceSummary> invoices,
  String query,
) {
  final terms = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList();
  if (terms.isEmpty) return invoices.toList();

  return invoices.where((invoice) {
    final issuedAt = invoice.issuedAt.toLocal();
    final total = invoice.totalInPaise / 100;
    final searchableText = [
      invoice.invoiceNumber,
      invoice.customerName,
      invoice.status,
      DateFormat('dd MMM yyyy').format(issuedAt),
      DateFormat('dd/MM/yyyy').format(issuedAt),
      DateFormat('dd-MM-yyyy').format(issuedAt),
      money(invoice.totalInPaise),
      total.toStringAsFixed(2),
      if (total == total.roundToDouble()) total.toInt().toString(),
    ].join(' ').toLowerCase();
    return terms.every(searchableText.contains);
  }).toList();
}

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({
    super.key,
    required this.controller,
    required this.revision,
    required this.drawer,
  });
  final AppController controller;
  final int revision;
  final Widget drawer;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  late Future<List<InvoiceSummary>> invoices;
  String query = '';

  @override
  void initState() {
    super.initState();
    invoices = widget.controller.database.invoices();
  }

  @override
  void didUpdateWidget(covariant InvoicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      invoices = widget.controller.database.invoices();
    }
  }

  Future<void> _refresh() async {
    final next = widget.controller.database.invoices();
    setState(() => invoices = next);
    await next;
  }

  Future<void> _delete(InvoiceSummary invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete invoice?'),
        content: Text(
          'Delete ${invoice.invoiceNumber}? Its sold quantities will be returned to stock. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep invoice'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete and restore stock'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.controller.database.deleteInvoice(invoice.id);
      await _refresh();
      widget.controller.markDataChanged();
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: widget.drawer,
    appBar: AppBar(title: const Text('Invoices')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (value) => setState(() => query = value),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search invoice number, customer or date',
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<InvoiceSummary>>(
            future: invoices,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorState(
                  message: errorMessage(snapshot.error!),
                  onRetry: _refresh,
                );
              }
              if (!snapshot.hasData) return const LoadingView();
              final allInvoices = snapshot.data!;
              final visibleInvoices = filterInvoices(allInvoices, query);
              if (allInvoices.isEmpty) {
                return const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No invoices yet',
                  message: 'Completed sales will appear here.',
                );
              }
              if (visibleInvoices.isEmpty) {
                return const EmptyState(
                  icon: Icons.search_off_outlined,
                  title: 'No matching invoices',
                  message: 'Try a different invoice number, customer or date.',
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: visibleInvoices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final invoice = visibleInvoices[index];
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
                          child: const Icon(
                            Icons.receipt,
                            color: Color(0xff057c73),
                          ),
                        ),
                        title: Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${invoice.customerName}\n${DateFormat('dd MMM yyyy, hh:mm a').format(invoice.issuedAt.toLocal())}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  money(invoice.totalInPaise),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
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
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') _delete(invoice);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete invoice'),
                                ),
                              ],
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
        ),
      ],
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
                    if ((detail.business['address'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(detail.business['address'] as String),
                      ),
                    if ((detail.business['phone'] as String).isNotEmpty)
                      Text('Phone: ${detail.business['phone']}'),
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
                                    '${formatQuantity(item['quantity'] as num)} ${readableUnit(item['unit'] as String, quantity: item['quantity'] as num)} × ${money(item['unit_price_in_paise'] as int)} · GST ${formatPercent((item['tax_rate_basis_points'] as int) / 100)}',
                                  ),
                                  if ((item['discount_in_paise'] as int) > 0)
                                    Text(
                                      'Discount ${formatPercent((item['discount_percent'] as num?) ?? 0)} · -${money(item['discount_in_paise'] as int)}',
                                      style: TextStyle(
                                        color: Colors.orange.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
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
                    if (((invoice['line_discount_in_paise'] as int?) ?? 0) > 0)
                      _Amount(
                        label: 'Product discounts',
                        value:
                            '- ${money(invoice['line_discount_in_paise'] as int)}',
                      ),
                    if (((invoice['overall_discount_in_paise'] as int?) ?? 0) >
                        0)
                      _Amount(
                        label:
                            'Overall discount (${formatPercent(invoice['overall_discount_percent'] as num)})',
                        value:
                            '- ${money(invoice['overall_discount_in_paise'] as int)}',
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
                  await const WhatsAppService().openCustomerChat(detail);
                } catch (error) {
                  if (context.mounted) {
                    showMessage(context, errorMessage(error), error: true);
                  }
                }
              },
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Message customer on WhatsApp'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff128c7e),
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
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
              label: const Text('Share invoice PDF'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => ThermalReceiptPreviewSheet(invoice: detail),
              ),
              icon: const Icon(Icons.preview_outlined),
              label: const Text('Preview thermal receipt'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
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
