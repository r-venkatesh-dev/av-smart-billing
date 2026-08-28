import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../ui_helpers.dart';
import 'editor_dialogs.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({
    super.key,
    required this.controller,
    required this.drawer,
  });
  final AppController controller;
  final Widget drawer;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String query = '';

  Future<void> _edit([Product? product]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProductEditorDialog(
        product: product,
        onSave: widget.controller.saveProduct,
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      setState(() {});
      await widget.controller.checkLowStock();
      widget.controller.markDataChanged();
    }
  }

  Future<void> _delete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: Icons.delete_outline_rounded,
        danger: true,
        title: const Text('Delete product?'),
        content: Text(
          'Delete ${product.name}? Products already used on invoices must be marked inactive instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.controller.deleteProduct(product.id);
      await widget.controller.checkLowStock();
      widget.controller.markDataChanged();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    }
  }

  Future<void> _changeStatus(Product product, bool makeActive) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: makeActive
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        title: Text(
          makeActive ? 'Make product active?' : 'Make product inactive?',
        ),
        content: Text(
          textAlign: TextAlign.center,
          makeActive
              ? '${product.name} will appear in Quick Sell and can be added to new bills.'
              : '${product.name} will be hidden from Quick Sell. Existing invoices will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(makeActive ? 'Yes' : 'Yes'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.controller.setProductActive(product.id, makeActive);
      await widget.controller.checkLowStock();
      widget.controller.markDataChanged();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: widget.drawer,
    appBar: AppBar(
      title: Text(
        widget.controller.isOnline ? 'Products · Online' : 'Products',
      ),
      actions: [
        IconButton(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          tooltip: 'Add product',
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
              hintText: 'Search name, SKU or barcode',
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Product>>(
            future: widget.controller.products(query: query),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorState(
                  message: errorMessage(snapshot.error!),
                  onRetry: () async {
                    if (mounted) setState(() {});
                  },
                );
              }
              if (!snapshot.hasData) return const LoadingView();
              final products = snapshot.data!;
              if (products.isEmpty) {
                return const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No products yet',
                  message: 'Tap + to add your first product.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: products.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return ProductCard(
                    product: product,
                    onEdit: () => _edit(product),
                    onDelete: () => _delete(product),
                    onStatusChanged: (value) => _changeStatus(product, value),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      tooltip: 'Add a new product',
      backgroundColor: const Color(0xff057c73),
      foregroundColor: Colors.white,
      elevation: 4,
      highlightElevation: 8,
      extendedIconLabelSpacing: 10,
      extendedPadding: const EdgeInsets.fromLTRB(10, 0, 20, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: const DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0x26ffffff),
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: EdgeInsets.all(5),
          child: Icon(Icons.add_rounded, size: 22),
        ),
      ),
      label: const Text(
        'Add Product',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    ),
  );
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onStatusChanged;

  @override
  Widget build(BuildContext context) => Card(
    color: product.discountPercent > 0
        ? const Color(0xfffff8e7)
        : product.active
        ? null
        : Colors.grey.shade100,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 6, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: product.stockQuantity <= 5
                  ? Colors.orange.shade50
                  : const Color(0xffe6f2f0),
              child: Icon(
                Icons.inventory_2,
                color: product.stockQuantity <= 5
                    ? Colors.orange.shade800
                    : const Color(0xff057c73),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            decoration: product.active
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        money(product.priceInPaise),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        tooltip: 'Product actions',
                        onSelected: (value) {
                          if (value == 'edit') onEdit();
                          if (value == 'delete') onDelete();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit product'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete product'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    'Product code: ${product.sku}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  if (product.barcode.isNotEmpty)
                    Text(
                      'Barcode: ${product.barcode}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _ProductInfoChip(
                        icon: Icons.inventory_2_outlined,
                        label: stockLabel(product.stockQuantity, product.unit),
                      ),
                      _ProductInfoChip(
                        icon: Icons.receipt_long_outlined,
                        label:
                            'GST: ${formatPercent(product.taxRateBasisPoints / 100)}',
                      ),
                      if (product.discountPercent > 0)
                        _ProductInfoChip(
                          icon: Icons.discount_outlined,
                          label:
                              'Discount: ${formatPercent(product.discountPercent)}',
                          highlighted: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        product.active
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                        size: 18,
                        color: product.active
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          product.active
                              ? 'Available for billing'
                              : 'Not available for billing',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Switch.adaptive(
                        value: product.active,
                        onChanged: onStatusChanged,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProductInfoChip extends StatelessWidget {
  const _ProductInfoChip({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: highlighted ? Colors.orange.shade100 : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}
