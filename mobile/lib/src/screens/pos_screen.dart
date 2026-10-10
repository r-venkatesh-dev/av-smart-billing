import 'package:flutter/material.dart';

import '../app.dart';
import '../billing_math.dart';
import '../models.dart';
import '../sound_service.dart';
import '../ui_helpers.dart';
import 'barcode_scanner_screen.dart';
import 'editor_dialogs.dart';
import 'invoices_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key, required this.controller, this.drawer});
  final AppController controller;
  final Widget? drawer;

  @override
  State<PosScreen> createState() => PosScreenState();
}

class PosScreenState extends State<PosScreen> {
  List<Product> products = [];
  final List<CartLine> cart = [];
  final _searchController = TextEditingController();
  String query = '';
  bool loading = true;
  Object? loadError;
  int heldCount = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
        widget.controller.products(),
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
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (scannerContext) => StatefulBuilder(
          builder: (context, setScannerState) {
            final cartItemCount = cart.fold<double>(
              0,
              (sum, line) => sum + line.quantity,
            );

            return BarcodeScannerScreen(
              title: 'Scan products',
              onContinuousScan: (scannedBarcode) async {
                Product? product;
                try {
                  product = await widget.controller.productByBarcode(
                    scannedBarcode,
                  );
                } catch (error) {
                  await SoundService.beepError();
                  return BarcodeScanFeedback(
                    success: false,
                    title: 'Database error',
                    subtitle: errorMessage(error),
                  );
                }

                if (product == null || !product.active) {
                  await SoundService.beepError();
                  return BarcodeScanFeedback(
                    success: false,
                    title: 'No matching product',
                    subtitle: 'Barcode: $scannedBarcode',
                  );
                }

                final targetProduct = product;

                final existing = cart
                    .where((line) => line.product.id == targetProduct.id)
                    .firstOrNull;
                if (existing != null &&
                    existing.quantity >= targetProduct.stockQuantity) {
                  await SoundService.beepError();
                  return BarcodeScanFeedback(
                    success: false,
                    title: 'Stock limit reached',
                    subtitle:
                        'Only ${formatQuantity(targetProduct.stockQuantity)} available',
                  );
                }

                _add(targetProduct);
                await SoundService.beepSuccess();
                setScannerState(() {});

                final newQty =
                    cart
                        .where((line) => line.product.id == targetProduct.id)
                        .firstOrNull
                        ?.quantity ??
                    1.0;

                return BarcodeScanFeedback(
                  success: true,
                  title: 'Added ${targetProduct.name}',
                  subtitle:
                      'Qty: ${formatQuantity(newQty)}  •  ${money(targetProduct.priceInPaise)}',
                );
              },
              bottomSummary: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xff1f2423),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${formatQuantity(cartItemCount)} in cart',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            money(total),
                            style: const TextStyle(
                              color: Color(0xff8fc5c0),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff057c73),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () => Navigator.pop(scannerContext),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Finish'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _review() async {
    if (cart.isEmpty) return;
    List<Customer> customers;
    try {
      customers = await widget.controller.customers();
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
        onSave:
            (customer, name, phone, payment, overallDiscount, saveCustomer) =>
                widget.controller.createInvoice(
                  customer: customer,
                  walkInName: name,
                  walkInPhone: phone,
                  saveWalkInCustomer: saveCustomer,
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
    const tealHeaderColor = Color(0xff004d40);

    final matches = products.where((product) {
      final term = query.toLowerCase();
      return term.isEmpty ||
          product.name.toLowerCase().contains(term) ||
          product.sku.toLowerCase().contains(term) ||
          product.barcode.contains(term);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      drawer: widget.drawer,
      appBar: AppBar(
        backgroundColor: tealHeaderColor,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            tooltip: 'Open menu',
            onPressed: () {
              final scaffold = Scaffold.maybeOf(ctx);
              if (scaffold != null && scaffold.hasDrawer) {
                scaffold.openDrawer();
                return;
              }
              final root = ctx.findRootAncestorStateOfType<ScaffoldState>();
              if (root != null && root.hasDrawer) {
                root.openDrawer();
              }
            },
          ),
        ),
        title: Text(
          widget.controller.isOnline ? 'Quick Sell · Online' : 'Quick Sell',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: startBarcodeScan,
            tooltip: 'Scan barcode',
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
          ),
          IconButton(
            onPressed: _showHeldBills,
            tooltip: 'Held bills',
            icon: Badge(
              isLabelVisible: heldCount > 0,
              label: Text('$heldCount'),
              child: const Icon(Icons.pause_circle_outline, color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
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
                    color: Colors.black.withValues(alpha: 0.06),
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
                      decoration: const InputDecoration(
                        hintText: 'Search products by name, SKU or barcode...',
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
                      Icons.qr_code_scanner_rounded,
                      color: Color(0xff004d40),
                      size: 20,
                    ),
                    tooltip: 'Scan barcode',
                    onPressed: startBarcodeScan,
                  ),
                  const SizedBox(width: 4),
                ],
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
                                      const SizedBox(height: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: product.stockQuantity <= 0
                                              ? const Color(0xfffef2f2)
                                              : product.stockQuantity <= 5
                                                  ? const Color(0xfffffbeb)
                                                  : const Color(0xfff1f5f9),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: product.stockQuantity <= 0
                                                ? const Color(0xfffecaca)
                                                : product.stockQuantity <= 5
                                                    ? const Color(0xfffde68a)
                                                    : const Color(0xffe2e8f0),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              product.stockQuantity <= 0
                                                  ? Icons.cancel_outlined
                                                  : product.stockQuantity <= 5
                                                      ? Icons
                                                          .warning_amber_rounded
                                                      : Icons
                                                          .inventory_2_outlined,
                                              size: 13,
                                              color: product.stockQuantity <= 0
                                                  ? const Color(0xffdc2626)
                                                  : product.stockQuantity <= 5
                                                      ? const Color(
                                                          0xffd97706)
                                                      : const Color(
                                                          0xff475569),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              stockLabel(
                                                product.stockQuantity,
                                                product.unit,
                                              ),
                                              style: TextStyle(
                                                color: product.stockQuantity <= 0
                                                    ? const Color(0xffdc2626)
                                                    : product.stockQuantity <= 5
                                                        ? const Color(
                                                            0xffb45309)
                                                        : const Color(
                                                            0xff334155),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
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
