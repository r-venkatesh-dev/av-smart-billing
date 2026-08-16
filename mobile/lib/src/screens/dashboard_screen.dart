import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../ui_helpers.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.onSell,
  });
  final AppController controller;
  final VoidCallback onSell;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardStats> stats;

  @override
  void initState() {
    super.initState();
    stats = widget.controller.database.dashboard();
  }

  Future<void> _refresh() async {
    final next = widget.controller.database.dashboard();
    setState(() => stats = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AV Smartbilling',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            widget.controller.session!.customerName,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
    body: FutureBuilder<DashboardStats>(
      future: stats,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorState(
            message: errorMessage(snapshot.error!),
            onRetry: _refresh,
          );
        }
        if (!snapshot.hasData) return const LoadingView();
        final value = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff057c73), Color(0xff035f58)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TODAY\'S SALES',
                      style: TextStyle(
                        color: Colors.white70,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      money(value.todaySales),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: widget.onSell,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Create new bill'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xff035f58),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _StatCard(
                    label: 'Total sales',
                    value: money(value.totalSales),
                    icon: Icons.trending_up,
                  ),
                  _StatCard(
                    label: 'Invoices',
                    value: '${value.invoiceCount}',
                    icon: Icons.receipt_long,
                  ),
                  _StatCard(
                    label: 'Products',
                    value: '${value.productCount}',
                    icon: Icons.inventory_2,
                  ),
                  _StatCard(
                    label: 'Low stock',
                    value: '${value.lowStockCount}',
                    icon: Icons.warning_amber,
                    warning: value.lowStockCount > 0,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xffe6f2f0),
                    child: Icon(
                      Icons.phone_android,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: const Text(
                    'This phone works offline',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'License valid offline until ${widget.controller.session!.validUntil.toLocal().toString().substring(0, 16)}',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.warning = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool warning;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            icon,
            color: warning
                ? Colors.orange.shade700
                : Theme.of(context).colorScheme.primary,
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    ),
  );
}
