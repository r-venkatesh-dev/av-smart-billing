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
      final value = await widget.controller.database.products();
      if (mounted) {
        setState(() {
          products = value
              .where((item) => item.active && item.stockQuantity > 0)
              .toList();
          loading = false;
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
          'Only ${product.stockQuantity} ${product.unit} available.',
          error: true,
        );
      }
      existing.quantity++;
    } else {
      cart.add(CartLine(product: product));
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
    final reviewCart = cart
        .map(
          (line) => CartLine(
            product: line.product,
            quantity: line.quantity,
            discountPercent: line.discountPercent,
          ),
        )
        .toList();
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CheckoutSheet(
        cart: reviewCart,
        customers: customers,
        onSave: (customer, name, phone, payment) =>
            widget.controller.database.createInvoice(
              customer: customer,
              walkInName: name,
              walkInPhone: phone,
              lines: reviewCart,
              paymentMethod: payment,
            ),
      ),
    );
    if (!mounted) return;
    setState(() {});
    if (id == null) return;
    cart.clear();
    await _load();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            InvoiceDetailScreen(controller: widget.controller, invoiceId: id),
      ),
    );
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
      appBar: AppBar(title: const Text('Quick Sell')),
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
                        child: ListTile(
                          onTap: () => _add(product),
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${product.sku} · ${product.stockQuantity} ${product.unit} available',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                money(product.priceInPaise),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.add_circle,
                                color: Color(0xff057c73),
                              ),
                            ],
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
