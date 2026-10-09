import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../ui_helpers.dart';
import '../widgets/import_action_sheet.dart';
import '../widgets/summary_filter_chips.dart';
import 'editor_dialogs.dart';

enum ProductFilter {
  all,
  active,
  lowStock,
  inactive,
}

enum ProductSort {
  nameAsc,
  nameDesc,
  priceAsc,
  priceDesc,
  stockAsc,
  stockDesc,
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({
    super.key,
    required this.controller,
    this.drawer,
  });
  final AppController controller;
  final Widget? drawer;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String query = '';
  ProductFilter _activeFilter = ProductFilter.all;
  ProductSort _currentSort = ProductSort.nameAsc;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
            child: const Text('Yes'),
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
                        'Sort Products',
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
                  title: const Text('Name (A to Z)'),
                  trailing: _currentSort == ProductSort.nameAsc
                      ? const Icon(Icons.check, color: Color(0xff004d40))
                      : null,
                  onTap: () {
                    setState(() => _currentSort = ProductSort.nameAsc);
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  title: const Text('Name (Z to A)'),
                  trailing: _currentSort == ProductSort.nameDesc
                      ? const Icon(Icons.check, color: Color(0xff004d40))
                      : null,
                  onTap: () {
                    setState(() => _currentSort = ProductSort.nameDesc);
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  title: const Text('Price: Low to High'),
                  trailing: _currentSort == ProductSort.priceAsc
                      ? const Icon(Icons.check, color: Color(0xff004d40))
                      : null,
                  onTap: () {
                    setState(() => _currentSort = ProductSort.priceAsc);
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  title: const Text('Price: High to Low'),
                  trailing: _currentSort == ProductSort.priceDesc
                      ? const Icon(Icons.check, color: Color(0xff004d40))
                      : null,
                  onTap: () {
                    setState(() => _currentSort = ProductSort.priceDesc);
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  title: const Text('Stock: Low to High'),
                  trailing: _currentSort == ProductSort.stockAsc
                      ? const Icon(Icons.check, color: Color(0xff004d40))
                      : null,
                  onTap: () {
                    setState(() => _currentSort = ProductSort.stockAsc);
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  title: const Text('Stock: High to Low'),
                  trailing: _currentSort == ProductSort.stockDesc
                      ? const Icon(Icons.check, color: Color(0xff004d40))
                      : null,
                  onTap: () {
                    setState(() => _currentSort = ProductSort.stockDesc);
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

  List<Product> _sortProducts(List<Product> products) {
    final list = List<Product>.from(products);
    switch (_currentSort) {
      case ProductSort.nameAsc:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ProductSort.nameDesc:
        list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case ProductSort.priceAsc:
        list.sort((a, b) => a.priceInPaise.compareTo(b.priceInPaise));
        break;
      case ProductSort.priceDesc:
        list.sort((a, b) => b.priceInPaise.compareTo(a.priceInPaise));
        break;
      case ProductSort.stockAsc:
        list.sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));
        break;
      case ProductSort.stockDesc:
        list.sort((a, b) => b.stockQuantity.compareTo(a.stockQuantity));
        break;
    }
    return list;
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
        title: Text(
          widget.controller.isOnline ? 'Products · Online' : 'Products',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => showImportActionSheet(
              context: context,
              controller: widget.controller,
              type: ImportDataType.products,
              onRefresh: () async {
                if (mounted) setState(() {});
                await widget.controller.checkLowStock();
                widget.controller.markDataChanged();
              },
            ),
            icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
            tooltip: 'Import / Export Excel',
          ),
          IconButton(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'Add product',
          ),
        ],
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
                      decoration: const InputDecoration(
                        hintText: 'Search products...',
                        hintStyle: TextStyle(
                          color: Color(0xff94a3b8),
                          fontSize: 15,
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
                        fontSize: 15,
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
                    tooltip: 'Sort & filter options',
                    splashRadius: 18,
                    onPressed: _showSortFilterSheet,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),

          // Main body with Summary Chips and Product list
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

                final allProducts = snapshot.data!;
                final totalCount = allProducts.length;
                final activeCount =
                    allProducts.where((p) => p.active).length;
                final lowStockCount =
                    allProducts.where((p) => p.stockQuantity <= 5).length;
                final inactiveCount =
                    allProducts.where((p) => !p.active).length;

                final List<Product> filteredProducts;
                switch (_activeFilter) {
                  case ProductFilter.all:
                    filteredProducts = allProducts;
                    break;
                  case ProductFilter.active:
                    filteredProducts =
                        allProducts.where((p) => p.active).toList();
                    break;
                  case ProductFilter.lowStock:
                    filteredProducts =
                        allProducts.where((p) => p.stockQuantity <= 5).toList();
                    break;
                  case ProductFilter.inactive:
                    filteredProducts =
                        allProducts.where((p) => !p.active).toList();
                    break;
                }

                final displayProducts = _sortProducts(filteredProducts);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Summary Filter Chips row
                    SummaryFilterChips<ProductFilter>(
                      selectedValue: _activeFilter,
                      onSelected: (filter) =>
                          setState(() => _activeFilter = filter),
                      items: [
                        SummaryChipItem(
                          value: ProductFilter.all,
                          label: 'All',
                          count: totalCount,
                          variant: SummaryChipVariant.primary,
                        ),
                        SummaryChipItem(
                          value: ProductFilter.active,
                          label: 'Active',
                          count: activeCount,
                          variant: SummaryChipVariant.success,
                        ),
                        SummaryChipItem(
                          value: ProductFilter.lowStock,
                          label: 'Low Stock',
                          count: lowStockCount,
                          variant: SummaryChipVariant.warning,
                        ),
                        SummaryChipItem(
                          value: ProductFilter.inactive,
                          label: 'Inactive',
                          count: inactiveCount,
                          variant: SummaryChipVariant.neutral,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // "Showing X products" count subtitle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Showing ${displayProducts.length} ${displayProducts.length == 1 ? 'product' : 'products'}',
                        style: const TextStyle(
                          color: Color(0xff64748b),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Products List
                    Expanded(
                      child: displayProducts.isEmpty
                          ? (allProducts.isEmpty
                              ? const EmptyState(
                                  icon: Icons.inventory_2_outlined,
                                  title: 'No products yet',
                                  message: 'Tap + to add your first product.',
                                )
                              : Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.filter_alt_off_outlined,
                                          size: 48,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No products match this filter',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextButton(
                                          onPressed: () => setState(
                                            () => _activeFilter =
                                                ProductFilter.all,
                                          ),
                                          child: const Text('Show All Products'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ))
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 96),
                              itemCount: displayProducts.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final product = displayProducts[index];
                                return ProductCard(
                                  product: product,
                                  onEdit: () => _edit(product),
                                  onDelete: () => _delete(product),
                                  onStatusChanged: (value) =>
                                      _changeStatus(product, value),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _edit(),
        tooltip: 'Add a new product',
        backgroundColor: const Color(0xff004d40),
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 8,
        extendedIconLabelSpacing: 10,
        extendedPadding: const EdgeInsets.fromLTRB(12, 0, 20, 0),
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
  Widget build(BuildContext context) {
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
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Product details column (Flexible to avoid overflow on narrow screens)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff004d40),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.sku.isNotEmpty ? product.sku : 'No SKU',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff64748b),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          money(product.priceInPaise),
                          style: const TextStyle(
                            color: Color(0xff0f172a),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          stockLabel(product.stockQuantity, product.unit),
                          style: TextStyle(
                            color: product.stockQuantity <= 0
                                ? const Color(0xffdc2626)
                                : product.stockQuantity <= 5
                                    ? const Color(0xffd97706)
                                    : const Color(0xff334155),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (product.discountPercent > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xfffef3c7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${formatPercent(product.discountPercent)} OFF',
                              style: const TextStyle(
                                color: Color(0xff92400e),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Switch and Active/Inactive status indicator
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Switch.adaptive(
                    value: product.active,
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xff16a34a),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xffcbd5e1),
                    onChanged: onStatusChanged,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.active ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: product.active
                          ? const Color(0xff16a34a)
                          : const Color(0xff94a3b8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // Actions menu (edit / delete)
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xff94a3b8),
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Product actions',
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Edit product'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete product',
                            style: TextStyle(color: Colors.red)),
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
  }
}
