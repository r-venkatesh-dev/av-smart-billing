import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../ui_helpers.dart';
import 'invoices_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.revision,
    required this.onSell,
    required this.onInvoices,
    required this.drawer,
  });
  final AppController controller;
  final int revision;
  final VoidCallback onSell;
  final VoidCallback onInvoices;
  final Widget drawer;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> data;

  @override
  void initState() {
    super.initState();
    data = _load();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) data = _load();
  }

  Future<_DashboardData> _load() async => _DashboardData(
    stats: await widget.controller.database.dashboard(),
    invoices: await widget.controller.database.invoices(),
  );

  Future<void> _refresh() async {
    final next = _load();
    setState(() => data = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: widget.drawer,
    appBar: AppBar(
      toolbarHeight: 72,
      titleSpacing: 4,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/branding/app-logo.png',
              width: 38,
              height: 38,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'AV Smartbilling',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => showMessage(context, 'No new notifications.'),
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded, size: 28),
        ),
        const SizedBox(width: 6),
      ],
    ),
    body: FutureBuilder<_DashboardData>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorState(
            message: errorMessage(snapshot.error!),
            onRetry: _refresh,
          );
        }
        if (!snapshot.hasData) return const LoadingView();
        final value = snapshot.data!.stats;
        final recentInvoices = snapshot.data!.invoices.take(3).toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage(
                      'assets/branding/drawer-header-pattern.png',
                    ),
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TODAY\'S SALES',
                      style: TextStyle(
                        color: Color(0xffd5eeeb),
                        letterSpacing: 0.8,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              money(value.todaySales),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: widget.onSell,
                          icon: const Icon(Icons.add_circle, size: 21),
                          label: const Text('Create new bill'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xff057c73),
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
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
                childAspectRatio: 1.48,
                children: [
                  _StatCard(
                    label: 'Total sales',
                    value: money(value.totalSales),
                    icon: Icons.currency_rupee_rounded,
                  ),
                  _StatCard(
                    label: 'Invoices',
                    value: '${value.invoiceCount}',
                    icon: Icons.receipt_long_outlined,
                  ),
                  _StatCard(
                    label: 'Products',
                    value: '${value.productCount}',
                    icon: Icons.inventory_2_outlined,
                  ),
                  _StatCard(
                    label: 'Low stock',
                    value: '${value.lowStockCount}',
                    icon: Icons.warning_amber_rounded,
                    warning: value.lowStockCount > 0,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xffe0e5e3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text(
                                'RECENT BILLS',
                                style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                  color: Color(0xff343c39),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onInvoices,
                            child: const Text('View all'),
                          ),
                        ],
                      ),
                      if (recentInvoices.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 18),
                          child: Text(
                            'Your latest completed bills will appear here.',
                          ),
                        )
                      else
                        for (
                          var index = 0;
                          index < recentInvoices.length;
                          index++
                        ) ...[
                          if (index > 0) const Divider(height: 1, indent: 58),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            leading: const CircleAvatar(
                              radius: 21,
                              backgroundColor: Color(0xffe4f3f0),
                              child: Icon(
                                Icons.receipt_long_outlined,
                                color: Color(0xff057c73),
                                size: 22,
                              ),
                            ),
                            title: Text(
                              recentInvoices[index].invoiceNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(recentInvoices[index].customerName),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  money(recentInvoices[index].totalInPaise),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => InvoiceDetailScreen(
                                  controller: widget.controller,
                                  invoiceId: recentInvoices[index].id,
                                ),
                              ),
                            ),
                          ),
                        ],
                    ],
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

class _DashboardData {
  const _DashboardData({required this.stats, required this.invoices});

  final DashboardStats stats;
  final List<InvoiceSummary> invoices;
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
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xffe0e5e3)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(11),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: warning
                ? const Color(0xffffedd7)
                : const Color(0xffe4f3f0),
            foregroundColor: warning
                ? const Color(0xffd58100)
                : const Color(0xff057c73),
            child: Icon(icon, size: 23),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff646c69),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: warning
                          ? const Color(0xffd58100)
                          : const Color(0xff202623),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
