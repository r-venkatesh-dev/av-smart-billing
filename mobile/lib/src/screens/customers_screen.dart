import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../ui_helpers.dart';
import '../widgets/import_action_sheet.dart';
import '../widgets/summary_filter_chips.dart';
import 'editor_dialogs.dart';

enum CustomerFilter {
  all,
  withPhone,
  withGstin,
}

enum CustomerSort {
  nameAsc,
  nameDesc,
}

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({
    super.key,
    required this.controller,
    this.drawer,
  });
  final AppController controller;
  final Widget? drawer;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String query = '';
  CustomerFilter _activeFilter = CustomerFilter.all;
  CustomerSort _currentSort = CustomerSort.nameAsc;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _edit([Customer? customer]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => CustomerEditorDialog(
        customer: customer,
        onSave: widget.controller.saveCustomer,
      ),
    );
    if (mounted && saved == true) setState(() {});
  }

  Future<void> _delete(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: Icons.person_remove_outlined,
        danger: true,
        title: const Text('Delete customer?'),
        content: Text(
          'Delete ${customer.name}? Existing invoices will keep their customer details.',
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
      await widget.controller.deleteCustomer(customer.id);
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
                        'Sort Customers',
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
                  trailing: _currentSort == CustomerSort.nameAsc
                      ? const Icon(Icons.check, color: Color(0xff004d40))
                      : null,
                  onTap: () {
                    setState(() => _currentSort = CustomerSort.nameAsc);
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  title: const Text('Name (Z to A)'),
                  trailing: _currentSort == CustomerSort.nameDesc
                      ? const Icon(Icons.check, color: Color(0xff004d40))
                      : null,
                  onTap: () {
                    setState(() => _currentSort = CustomerSort.nameDesc);
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

  List<Customer> _filterAndSortCustomers(List<Customer> customers) {
    var list = customers;

    // Filter by query
    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.phone.toLowerCase().contains(q) ||
            c.gstin.toLowerCase().contains(q) ||
            c.address.toLowerCase().contains(q);
      }).toList();
    }

    // Filter by chip category
    switch (_activeFilter) {
      case CustomerFilter.all:
        break;
      case CustomerFilter.withPhone:
        list = list.where((c) => c.phone.trim().isNotEmpty).toList();
        break;
      case CustomerFilter.withGstin:
        list = list.where((c) => c.gstin.trim().isNotEmpty).toList();
        break;
    }

    final sorted = List<Customer>.from(list);
    switch (_currentSort) {
      case CustomerSort.nameAsc:
        sorted.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case CustomerSort.nameDesc:
        sorted.sort(
            (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
    }
    return sorted;
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
        leading: widget.drawer != null
            ? Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  tooltip: 'Open menu',
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              )
            : null,
        title: Text(
          widget.controller.isOnline ? 'Customers · Online' : 'Customers',
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
              type: ImportDataType.customers,
              onRefresh: () {
                if (mounted) setState(() {});
                widget.controller.markDataChanged();
              },
            ),
            icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
            tooltip: 'Import / Export Excel',
          ),
          IconButton(
            onPressed: () => _edit(),
            icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
            tooltip: 'Add customer',
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
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Search name, phone, GSTIN or address',
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

          // Main body with Summary Chips and Customers list
          Expanded(
            child: FutureBuilder<List<Customer>>(
              future: widget.controller.customers(),
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

                final allCustomers = snapshot.data!;
                final totalCount = allCustomers.length;
                final withPhoneCount = allCustomers
                    .where((c) => c.phone.trim().isNotEmpty)
                    .length;
                final withGstinCount = allCustomers
                    .where((c) => c.gstin.trim().isNotEmpty)
                    .length;

                final displayCustomers = _filterAndSortCustomers(allCustomers);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Summary Filter Chips row
                    SummaryFilterChips<CustomerFilter>(
                      selectedValue: _activeFilter,
                      onSelected: (filter) =>
                          setState(() => _activeFilter = filter),
                      items: [
                        SummaryChipItem(
                          value: CustomerFilter.all,
                          label: 'All',
                          count: totalCount,
                          variant: SummaryChipVariant.primary,
                        ),
                        SummaryChipItem(
                          value: CustomerFilter.withPhone,
                          label: 'With Phone',
                          count: withPhoneCount,
                          variant: SummaryChipVariant.success,
                        ),
                        SummaryChipItem(
                          value: CustomerFilter.withGstin,
                          label: 'GST Registered',
                          count: withGstinCount,
                          variant: SummaryChipVariant.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // "Showing X customers" subtitle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Showing ${displayCustomers.length} ${displayCustomers.length == 1 ? 'customer' : 'customers'}',
                        style: const TextStyle(
                          color: Color(0xff64748b),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Customers List
                    Expanded(
                      child: displayCustomers.isEmpty
                          ? (allCustomers.isEmpty
                              ? const EmptyState(
                                  icon: Icons.people_outline,
                                  title: 'No customers yet',
                                  message:
                                      'Save regular customers or bill walk-in customers directly.',
                                )
                              : Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.person_search_outlined,
                                          size: 48,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No matching customers found',
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
                                              _activeFilter = CustomerFilter.all;
                                            });
                                          },
                                          child: const Text('Reset filters'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ))
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 96),
                              itemCount: displayCustomers.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final customer = displayCustomers[index];
                                final initial = customer.name.isNotEmpty
                                    ? customer.name
                                        .substring(0, 1)
                                        .toUpperCase()
                                    : '?';

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
                                    onTap: () => _edit(customer),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          14, 14, 10, 14),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor:
                                                const Color(0xffe6f2f0),
                                            child: Text(
                                              initial,
                                              style: const TextStyle(
                                                color: Color(0xff004d40),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  customer.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Color(0xff004d40),
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Wrap(
                                                  spacing: 12,
                                                  runSpacing: 4,
                                                  children: [
                                                    if (customer.phone.isNotEmpty)
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons.phone_outlined,
                                                            size: 13,
                                                            color:
                                                                Color(0xff64748b),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            customer.phone,
                                                            style:
                                                                const TextStyle(
                                                              color: Color(
                                                                  0xff64748b),
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    if (customer.gstin.isNotEmpty)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 6,
                                                          vertical: 1.5,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                              0xfff0f9ff),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                          border: Border.all(
                                                            color: const Color(
                                                                0xffbae6fd),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          'GST: ${customer.gstin}',
                                                          style:
                                                              const TextStyle(
                                                            color: Color(
                                                                0xff0369a1),
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                if (customer.address.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 3),
                                                    child: Text(
                                                      customer.address,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color:
                                                            Color(0xff94a3b8),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
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
                                            tooltip: 'Customer actions',
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _edit(customer);
                                              }
                                              if (value == 'delete') {
                                                _delete(customer);
                                              }
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_outlined,
                                                        size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Edit customer'),
                                                  ],
                                                ),
                                              ),
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
                                                      'Delete customer',
                                                      style: TextStyle(
                                                          color: Colors.red),
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
        tooltip: 'Add a new customer',
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
            child: Icon(Icons.person_add_alt_1, size: 22),
          ),
        ),
        label: const Text(
          'Add Customer',
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
