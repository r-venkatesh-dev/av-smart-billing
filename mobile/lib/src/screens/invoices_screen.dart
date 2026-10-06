import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../invoice_pdf.dart';
import '../models.dart';
import '../ui_helpers.dart';
import '../whatsapp_service.dart';
import '../widgets/summary_filter_chips.dart';
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

enum InvoiceFilter {
  all,
  paid,
  pending,
  today,
}

enum InvoiceSort {
  dateDesc,
  dateAsc,
  amountDesc,
  amountAsc,  
}

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({
    super.key,
    required this.controller,
    required this.revision,
    this.drawer,
  });
  final AppController controller;
  final int revision;
  final Widget? drawer;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<InvoiceSummary>> invoices;
  String query = '';
  InvoiceFilter _activeFilter = InvoiceFilter.all;
  InvoiceSort _currentSort = InvoiceSort.dateDesc;

  @override
  void initState() {
    super.initState();
    invoices = widget.controller.database.invoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    final local = date.toLocal();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  void _showSortFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Text(
                        'Sort Invoices',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff004d40),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Date: Newest First'),
                  trailing: _currentSort == InvoiceSort.dateDesc
                      ? const Icon(Icons.check, color: Color(0xff004d40))
                      : null,
                  onTap: () {
                    setState(() => _currentSort = InvoiceSort.dateDesc);
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  title: const Text('Date: Oldest First'),
                  trailing: _currentSort == InvoiceSort.dateAsc
                      ? const Icon(Icons.check, color: Color(0xff004d40))
                      : null,
                  onTap: () {
                    setState(() => _currentSort = InvoiceSort.dateAsc);
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  title: const Text('Amount: High to Low'),
                  trailing: _currentSort == InvoiceSort.amountDesc
                      ? const Icon(Icons.check, color: Color(0xff004d40))
                      : null,
                  onTap: () {
                    setState(() => _currentSort = InvoiceSort.amountDesc);
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  title: const Text('Amount: Low to High'),
                  trailing: _currentSort == InvoiceSort.amountAsc
                      ? const Icon(Icons.check, color: Color(0xff004d40))
                      : null,
                  onTap: () {
                    setState(() => _currentSort = InvoiceSort.amountAsc);
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<InvoiceSummary> _sortInvoices(List<InvoiceSummary> list) {
    final sorted = List<InvoiceSummary>.from(list);
    switch (_currentSort) {
      case InvoiceSort.dateDesc:
        sorted.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
        break;
      case InvoiceSort.dateAsc:
        sorted.sort((a, b) => a.issuedAt.compareTo(b.issuedAt));
        break;
      case InvoiceSort.amountDesc:
        sorted.sort((a, b) => b.totalInPaise.compareTo(a.totalInPaise));
        break;
      case InvoiceSort.amountAsc:
        sorted.sort((a, b) => a.totalInPaise.compareTo(b.totalInPaise));
        break;
    }
    return sorted;
  }

  Future<void> _delete(InvoiceSummary invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: Icons.delete_outline_rounded,
        danger: true,
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
  Widget build(BuildContext context) {
    const tealHeaderColor = Color(0xff004d40);

    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      drawer: widget.drawer,
      appBar: AppBar(
        backgroundColor: tealHeaderColor,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          tooltip: 'Open menu',
          onPressed: () {
            final root = context.findRootAncestorStateOfType<ScaffoldState>();
            if (root != null && root.hasDrawer) {
              root.openDrawer();
            } else if (widget.drawer != null) {
              Scaffold.maybeOf(context)?.openDrawer();
            }
          },
        ),
        title: const Text(
          'Invoices',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Teal top bar container containing the rounded search bar
          Container(
            color: tealHeaderColor,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.search_rounded,
                    color: Color(0xff64748b),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => query = value),
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Search invoice number, customer or date',
                        hintStyle: TextStyle(
                          color: Color(0xff94a3b8),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                        filled: false,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xff1e293b),
                      ),
                    ),
                  ),
                  if (query.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        size: 20,
                        color: Color(0xff64748b),
                      ),
                      splashRadius: 18,
                      onPressed: () {
                        _searchController.clear();
                        setState(() => query = '');
                      },
                    ),
                  Container(
                    height: 24,
                    width: 1,
                    color: const Color(0xffe2e8f0),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: Color(0xff475569),
                      size: 20,
                    ),
                    tooltip: 'Sort options',
                    splashRadius: 18,
                    onPressed: _showSortFilterSheet,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),

          // Main body with Summary Chips and Invoices list
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
                final searchedInvoices = filterInvoices(allInvoices, query);

                // Compute counts from searched results (or total if query is empty)
                final totalCount = searchedInvoices.length;
                final paidCount = searchedInvoices
                    .where((inv) => inv.status.toUpperCase() == 'PAID')
                    .length;
                final pendingCount = searchedInvoices
                    .where((inv) => inv.status.toUpperCase() != 'PAID')
                    .length;
                final todayCount = searchedInvoices
                    .where((inv) => _isToday(inv.issuedAt))
                    .length;

                final List<InvoiceSummary> filteredInvoices;
                switch (_activeFilter) {
                  case InvoiceFilter.all:
                    filteredInvoices = searchedInvoices;
                    break;
                  case InvoiceFilter.paid:
                    filteredInvoices = searchedInvoices
                        .where((inv) => inv.status.toUpperCase() == 'PAID')
                        .toList();
                    break;
                  case InvoiceFilter.pending:
                    filteredInvoices = searchedInvoices
                        .where((inv) => inv.status.toUpperCase() != 'PAID')
                        .toList();
                    break;
                  case InvoiceFilter.today:
                    filteredInvoices = searchedInvoices
                        .where((inv) => _isToday(inv.issuedAt))
                        .toList();
                    break;
                }

                final displayInvoices = _sortInvoices(filteredInvoices);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Summary Filter Chips row
                    SummaryFilterChips<InvoiceFilter>(
                      selectedValue: _activeFilter,
                      onSelected: (filter) =>
                          setState(() => _activeFilter = filter),
                      items: [
                        SummaryChipItem(
                          value: InvoiceFilter.all,
                          label: 'All',
                          count: totalCount,
                          variant: SummaryChipVariant.primary,
                        ),
                        SummaryChipItem(
                          value: InvoiceFilter.paid,
                          label: 'Paid',
                          count: paidCount,
                          variant: SummaryChipVariant.success,
                        ),
                        SummaryChipItem(
                          value: InvoiceFilter.pending,
                          label: 'Pending',
                          count: pendingCount,
                          variant: SummaryChipVariant.warning,
                        ),
                        SummaryChipItem(
                          value: InvoiceFilter.today,
                          label: 'Today',
                          count: todayCount,
                          variant: SummaryChipVariant.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // "Showing X invoices" subtitle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Showing ${displayInvoices.length} ${displayInvoices.length == 1 ? 'invoice' : 'invoices'}',
                        style: const TextStyle(
                          color: Color(0xff64748b),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Invoices List
                    Expanded(
                      child: displayInvoices.isEmpty
                          ? (allInvoices.isEmpty
                              ? const EmptyState(
                                  icon: Icons.receipt_long_outlined,
                                  title: 'No invoices yet',
                                  message: 'Completed sales will appear here.',
                                )
                              : Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.search_off_outlined,
                                          size: 48,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No matching invoices found',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextButton(
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              query = '';
                                              _activeFilter = InvoiceFilter.all;
                                            });
                                          },
                                          child: const Text('Reset filters'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ))
                          : RefreshIndicator(
                              onRefresh: _refresh,
                              child: ListView.separated(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                    16, 4, 16, 24),
                                itemCount: displayInvoices.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final invoice = displayInvoices[index];
                                  final isPaid = invoice.status.toUpperCase() ==
                                      'PAID';

                                  return Card(
                                    elevation: 0,
                                    margin: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(
                                        color: Color(0xffe2e8f0),
                                        width: 1,
                                      ),
                                    ),
                                    color: Colors.white,
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => InvoiceDetailScreen(
                                            controller: widget.controller,
                                            invoiceId: invoice.id,
                                          ),
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 14, 12, 14),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    invoice.invoiceNumber,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Color(0xff004d40),
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: -0.2,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    invoice.customerName.isEmpty
                                                        ? 'Walk-in Customer'
                                                        : invoice.customerName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Color(0xff64748b),
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    DateFormat(
                                                            'dd MMM yyyy, hh:mm a')
                                                        .format(invoice.issuedAt
                                                            .toLocal()),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Color(0xff94a3b8),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  money(invoice.totalInPaise),
                                                  style: const TextStyle(
                                                    color: Color(0xff0f172a),
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isPaid
                                                        ? const Color(0xffecfdf5)
                                                        : const Color(0xfffffbeb),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                      color: isPaid
                                                          ? const Color(
                                                              0xffa7f3d0)
                                                          : const Color(
                                                              0xfffde68a),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    invoice.status.toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: isPaid
                                                          ? const Color(
                                                              0xff065f46)
                                                          : const Color(
                                                              0xff92400e),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            PopupMenuButton<String>(
                                              icon: const Icon(
                                                Icons.more_vert_rounded,
                                                color: Color(0xff94a3b8),
                                                size: 20,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              tooltip: 'Invoice actions',
                                              onSelected: (value) {
                                                if (value == 'delete') {
                                                  _delete(invoice);
                                                }
                                              },
                                              itemBuilder: (_) => const [
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.delete_outline,
                                                        size: 18,
                                                        color: Colors.red,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Delete invoice',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
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

  Future<void> _markAsPaid() async {
    var paymentMethod = 'CASH';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          icon: Icons.payments_outlined,
          title: const Text('Mark invoice as paid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select how the customer paid this invoice.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _PaymentMethodTile(
                      icon: Icons.payments_outlined,
                      label: 'Cash',
                      selected: paymentMethod == 'CASH',
                      onTap: () => setDialogState(() => paymentMethod = 'CASH'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PaymentMethodTile(
                      icon: Icons.qr_code_rounded,
                      label: 'UPI / QR',
                      selected: paymentMethod == 'UPI_QR',
                      onTap: () =>
                          setDialogState(() => paymentMethod = 'UPI_QR'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PaymentMethodTile(
                      icon: Icons.credit_card_rounded,
                      label: 'Card',
                      selected: paymentMethod == 'CARD',
                      onTap: () => setDialogState(() => paymentMethod = 'CARD'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Mark as paid'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.controller.database.markInvoicePaid(
        widget.invoiceId,
        paymentMethod,
      );
      widget.controller.markDataChanged();
      await _retry();
      if (mounted) showMessage(context, 'Invoice marked as paid.');
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    }
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
            if (invoice['status'] == 'DUE') ...[
              FilledButton.icon(
                onPressed: _markAsPaid,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Mark as paid'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 10),
            ],
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
            // const SizedBox(height: 10),
            // OutlinedButton.icon(
            //   onPressed: () => printInvoice(detail),
            //   icon: const Icon(Icons.print),
            //   label: const Text('Print A4 using phone'),
            //   style: OutlinedButton.styleFrom(
            //     minimumSize: const Size.fromHeight(50),
            //   ),
            // ),
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

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xffe6f2f0) : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: selected ? const Color(0xff057c73) : const Color(0xffd9dfdd),
        width: selected ? 1.5 : 1,
      ),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          SizedBox(
            height: 108,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 30,
                  color: selected
                      ? const Color(0xff057c73)
                      : const Color(0xff4d5653),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xff057c73)
                        : const Color(0xff343c39),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            const Positioned(
              right: 7,
              top: 7,
              child: CircleAvatar(
                radius: 9,
                backgroundColor: Color(0xff057c73),
                child: Icon(Icons.check, color: Colors.white, size: 12),
              ),
            ),
        ],
      ),
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
