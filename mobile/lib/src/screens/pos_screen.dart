import 'package:flutter/material.dart';

import '../app.dart';
import '../billing_math.dart';
import '../models.dart';
import '../ui_helpers.dart';
import 'barcode_scanner_screen.dart';
import 'editor_dialogs.dart';
import 'invoices_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key, required this.controller, required this.drawer});
  final AppController controller;
  final Widget drawer;

  @override
  State<PosScreen> createState() => PosScreenState();
}

class PosScreenState extends State<PosScreen> {
  List<Product> products = [];
  final List<CartLine> cart = [];
  String query = '';
  bool loading = true;
  Object? loadError;
  int heldCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        loadError = null;
      });
    }
    try {
      final results = await Future.wait([
        widget.controller.database.products(),
        widget.controller.database.heldBills(),
      ]);
      final value = results[0] as List<Product>;
      if (mounted) {
        setState(() {
          products = value
              .where((item) => item.active && item.stockQuantity > 0)
              .toList();
          loading = false;
          heldCount = (results[1] as List<HeldBillSummary>).length;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          loadError = error;
          loading = false;
        });
      }
    }
  }

  void _add(Product product) {
    final existing = cart
        .where((line) => line.product.id == product.id)
        .firstOrNull;
    if (existing != null) {
      if (existing.quantity >= product.stockQuantity) {
        return showMessage(
          context,
          'Only ${formatQuantity(product.stockQuantity)} ${readableUnit(product.unit, quantity: product.stockQuantity)} available.',
          error: true,
        );
      }
      existing.quantity++;
    } else {
      cart.add(
        CartLine(product: product, discountPercent: product.discountPercent),
      );
    }
    setState(() {});
  }

  int get total => cart.fold(
    0,
    (sum, line) =>
        sum +
        calculateLine(
          priceInPaise: line.product.priceInPaise,
          quantity: line.quantity,
          discountPercent: line.discountPercent,
          taxRateBasisPoints: line.product.taxRateBasisPoints,
        ).total,
  );

  Future<void> startBarcodeScan() async {
    final value = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (value == null) return;
    Product? product;
    try {
      product = await widget.controller.database.productByBarcode(value);
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
      return;
    }
    if (!mounted) return;
    if (product == null) {
      return showMessage(
        context,
        'No active product matches this barcode.',
        error: true,
      );
    }
    _add(product);
  }

  Future<void> _review() async {
    if (cart.isEmpty) return;
    List<Customer> customers;
    try {
      customers = await widget.controller.database.customers();
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
      return;
    }
    if (!mounted) return;
    final business = await widget.controller.database.getBusiness();
    if (!mounted) return;
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CheckoutSheet(
        cart: cart,
        customers: customers,
        paymentQrPath: business['payment_qr_path'] as String? ?? '',
        onSave: (customer, name, phone, payment, overallDiscount) =>
            widget.controller.database.createInvoice(
              customer: customer,
              walkInName: name,
              walkInPhone: phone,
              lines: cart,
              paymentMethod: payment,
              overallDiscountPercent: overallDiscount,
            ),
        onHold: (lines) async {
          await widget.controller.database.holdBill(lines);
          cart.clear();
        },
        onCancel: () {
          if (mounted) setState(cart.clear);
        },
      ),
    );
    if (!mounted) return;
    setState(() {});
    if (id == null) {
      if (cart.isEmpty) await _load();
      return;
    }
    widget.controller.markDataChanged();
    cart.clear();
    await _load();
    await widget.controller.checkLowStock();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            InvoiceDetailScreen(controller: widget.controller, invoiceId: id),
      ),
    );
  }

  Future<void> _showHeldBills() async {
    if (cart.isNotEmpty) {
      showMessage(
        context,
        'Hold or cancel the current bill before resuming another bill.',
        error: true,
      );
      return;
    }
    final bills = await widget.controller.database.heldBills();
    if (!mounted) return;
    if (bills.isEmpty) {
      showMessage(context, 'There are no held bills.');
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Held bills',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...bills.map(
                (bill) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.pause_circle_outline),
                    title: Text(bill.label),
                    subtitle: Text('${bill.itemCount} product lines'),
                    onTap: () => Navigator.pop(context, bill.id),
                    trailing: IconButton(
                      tooltip: 'Delete held bill',
                      onPressed: () =>
                          Navigator.pop(context, 'delete:${bill.id}'),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action.startsWith('delete:')) {
      await widget.controller.database.deleteHeldBill(action.substring(7));
      await _load();
      return;
    }
    final resumed = await widget.controller.database.takeHeldBill(action);
    if (!mounted) return;
    setState(() {
      cart.addAll(resumed);
      heldCount = (heldCount - 1).clamp(0, heldCount);
    });
    if (resumed.isEmpty) {
      showMessage(
        context,
        'The held products are no longer active or in stock.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = products.where((product) {
      final term = query.toLowerCase();
      return term.isEmpty ||
          product.name.toLowerCase().contains(term) ||
          product.sku.toLowerCase().contains(term) ||
          product.barcode.contains(term);
    }).toList();
    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(
        title: const Text('Quick Sell'),
        actions: [
          IconButton(
            onPressed: _showHeldBills,
            tooltip: 'Held bills',
            icon: Badge(
              isLabelVisible: heldCount > 0,
              label: Text('$heldCount'),
              child: const Icon(Icons.pause_circle_outline),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search products',
              ),
            ),
          ),
          Expanded(
            child: loadError != null
                ? ErrorState(message: errorMessage(loadError!), onRetry: _load)
                : loading
                ? const LoadingView()
                : matches.isEmpty
                ? const EmptyState(
                    icon: Icons.qr_code_scanner,
                    title: 'No products found',
                    message: 'Add products first or try another search.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: matches.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final product = matches[index];
                      return Card(
                        color: product.discountPercent > 0
                            ? const Color(0xfffff8e7)
                            : null,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _add(product),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Product code: ${product.sku}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        stockLabel(
                                          product.stockQuantity,
                                          product.unit,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (product.discountPercent > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 3,
                                          ),
                                          child: Text(
                                            'Offer: ${formatPercent(product.discountPercent)} discount',
                                            style: TextStyle(
                                              color: Colors.orange.shade900,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      money(product.priceInPaise),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Icon(
                                      Icons.add_circle,
                                      color: Color(0xff057c73),
                                      size: 30,
                                    ),
                                    const Text(
                                      'Add',
                                      style: TextStyle(fontSize: 11),
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
          if (cart.isNotEmpty)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 14)],
                ),
                child: Row(
                  children: [
                    CircleAvatar(child: Text('${cart.length}')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Current bill'),
                          Text(
                            money(total),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: _review,
                      child: const Text('Review bill'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
