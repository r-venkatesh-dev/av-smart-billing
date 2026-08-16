import 'package:flutter/material.dart';

import '../app.dart';
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'invoices_screen.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});
  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        controller: widget.controller,
        onSell: () => setState(() => index = 1),
      ),
      PosScreen(controller: widget.controller),
      ProductsScreen(controller: widget.controller),
      InvoicesScreen(controller: widget.controller),
      MoreScreen(controller: widget.controller),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Sell',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Invoices',
          ),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('More')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          tileColor: Colors.white,
          leading: const Icon(Icons.people_outline),
          title: const Text('Customers'),
          subtitle: const Text('Customer details and GSTIN'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomersScreen(controller: controller),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ListTile(
          tileColor: Colors.white,
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Business settings'),
          subtitle: const Text('Invoice identity and license'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsScreen(controller: controller),
            ),
          ),
        ),
      ],
    ),
  );
}
