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
        onSave: widget.controller.database.saveProduct,
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: widget.drawer,
    appBar: AppBar(
      title: const Text('Products'),
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
            future: widget.controller.database.products(query: query),
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
                  return Card(
                    child: ListTile(
                      onTap: () => _edit(product),
                      leading: CircleAvatar(
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
                      title: Text(
                        product.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: product.active
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                      subtitle: Text(
                        '${product.sku}${product.barcode.isEmpty ? '' : ' · ${product.barcode}'}\nStock: ${product.stockQuantity} ${product.unit} · GST ${product.taxRateBasisPoints / 100}%',
                      ),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            money(product.priceInPaise),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (product.active)
                            InkWell(
                              onTap: () async {
                                try {
                                  await widget.controller.database
                                      .archiveProduct(product.id);
                                  if (mounted) setState(() {});
                                } catch (error) {
                                  if (mounted) {
                                    showMessage(
                                      this.context,
                                      errorMessage(error),
                                      error: true,
                                    );
                                  }
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.only(top: 5),
                                child: Text(
                                  'Archive',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
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
      icon: const Icon(Icons.add),
      label: const Text('Product'),
    ),
  );
}
