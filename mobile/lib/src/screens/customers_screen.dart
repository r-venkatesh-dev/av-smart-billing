import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../ui_helpers.dart';
import 'editor_dialogs.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  Future<void> _edit([Customer? customer]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => CustomerEditorDialog(
        customer: customer,
        onSave: widget.controller.database.saveCustomer,
      ),
    );
    if (mounted && saved == true) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Customers'),
      actions: [
        IconButton(
          onPressed: () => _edit(),
          icon: const Icon(Icons.person_add_alt_1),
        ),
      ],
    ),
    body: FutureBuilder<List<Customer>>(
      future: widget.controller.database.customers(),
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
        if (snapshot.data!.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline,
            title: 'No customers yet',
            message:
                'Save regular customers or bill walk-in customers directly.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final customer = snapshot.data![index];
            return Card(
              child: ListTile(
                onTap: () => _edit(customer),
                leading: CircleAvatar(
                  child: Text(customer.name.substring(0, 1).toUpperCase()),
                ),
                title: Text(
                  customer.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  [
                    customer.phone,
                    customer.gstin,
                  ].where((value) => value.isNotEmpty).join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          },
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text('Customer'),
    ),
  );
}
