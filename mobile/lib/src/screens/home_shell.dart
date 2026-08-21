import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app.dart';
import '../billing_mode_service.dart';
import '../online_billing_service.dart';
import '../ui_helpers.dart';
import 'about_screen.dart';
import 'cloud_backup_screen.dart';
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'invoices_screen.dart';
import 'online_foundation_screen.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'security_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});
  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _sellKey = GlobalKey<PosScreenState>();
  int index = 0;
  bool switchingMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller.isOnline) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnlineMode());
    }
  }

  String _onlineError(Object error) =>
      error is OnlineConnectionException ||
          error is SocketException ||
          error is TimeoutException ||
          error is http.ClientException
      ? 'Online Billing requires internet. Please connect to the internet and try again, or switch to Offline Billing.'
      : errorMessage(error);

  Future<void> _checkOnlineMode() async {
    try {
      await widget.controller.ensureOnlineReady();
    } catch (error) {
      if (!mounted) return;
      final switchOffline = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Online Billing unavailable'),
          content: Text(_onlineError(error)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay in Online Mode'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Switch to Offline Billing'),
            ),
          ],
        ),
      );
      if (switchOffline == true) {
        await widget.controller.switchBillingMode(BillingMode.offline);
      }
    }
  }

  Future<void> _changeMode(BillingMode mode) async {
    if (switchingMode || mode == widget.controller.billingMode) return;
    final goingOnline = mode == BillingMode.online;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          goingOnline
              ? 'Switch to Online Billing?'
              : 'Switch to Offline Billing?',
        ),
        content: Text(
          goingOnline
              ? 'Online Mode requires internet and uses the cloud Products and Customers. Your existing offline products, customers and invoices will remain safely on this phone.'
              : 'Offline Mode uses only the records stored on this phone. Your online records will remain safely in the cloud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep current mode'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(goingOnline ? 'Switch Online' : 'Switch Offline'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop();
    setState(() => switchingMode = true);
    if (goingOnline) {
      showMessage(context, 'Checking internet and online billing access…');
    }
    try {
      await widget.controller.switchBillingMode(mode);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        setState(() => index = 0);
        showMessage(
          context,
          goingOnline
              ? 'Online Mode enabled. Products and Customers now use cloud data.'
              : 'Offline Mode enabled. Using records stored on this phone.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Could not enable Online Billing'),
          content: Text(_onlineError(error)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => switchingMode = false);
    }
  }

  void _selectPage(int value) => setState(() => index = value);

  Future<void> _openPage(Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

  void _scan() {
    setState(() => index = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sellKey.currentState?.startBarcodeScan();
    });
  }

  Widget _drawer(int selectedIndex) => _AppDrawer(
    controller: widget.controller,
    selectedIndex: selectedIndex,
    onSelect: (value) {
      Navigator.pop(context);
      _selectPage(value);
    },
    onCustomers: () {
      Navigator.pop(context);
      _openPage(CustomersScreen(controller: widget.controller));
    },
    onSettings: () {
      Navigator.pop(context);
      _openPage(
        widget.controller.isOnline
            ? OnlineFoundationScreen(
                title: 'Online Business Settings',
                drawer: _drawer(-1),
              )
            : SettingsScreen(controller: widget.controller),
      );
    },
    onReports: () {
      Navigator.pop(context);
      _openPage(
        widget.controller.isOnline
            ? OnlineFoundationScreen(
                title: 'Online Reports & Exports',
                drawer: _drawer(-1),
              )
            : ReportsScreen(controller: widget.controller),
      );
    },
    onCloudBackup: () {
      Navigator.pop(context);
      _openPage(CloudBackupScreen(controller: widget.controller));
    },
    onSecurity: () {
      Navigator.pop(context);
      _openPage(SecurityScreen(controller: widget.controller));
    },
    onAbout: () {
      Navigator.pop(context);
      _openPage(const AboutScreen());
    },
    onModeChanged: _changeMode,
    switchingMode: switchingMode,
  );

  @override
  Widget build(BuildContext context) {
    final online = widget.controller.isOnline;
    final pages = [
      online
          ? OnlineFoundationScreen(title: 'Online Billing', drawer: _drawer(0))
          : DashboardScreen(
              controller: widget.controller,
              revision: widget.controller.dataRevision,
              onSell: () => _selectPage(1),
              drawer: _drawer(0),
            ),
      online
          ? OnlineFoundationScreen(title: 'Online Sell', drawer: _drawer(1))
          : PosScreen(
              key: _sellKey,
              controller: widget.controller,
              drawer: _drawer(1),
            ),
      ProductsScreen(controller: widget.controller, drawer: _drawer(2)),
      online
          ? OnlineFoundationScreen(title: 'Online Invoices', drawer: _drawer(3))
          : InvoicesScreen(
              controller: widget.controller,
              revision: widget.controller.dataRevision,
              drawer: _drawer(3),
            ),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      floatingActionButton: FloatingActionButton(
        onPressed: online
            ? () => showMessage(
                context,
                'Online selling will be available in the next stage.',
              )
            : _scan,
        tooltip: 'Scan product barcode',
        child: const Icon(Icons.qr_code_scanner, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomNavigation(
        selectedIndex: index,
        onSelect: _selectPage,
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => BottomAppBar(
    color: Colors.white,
    elevation: 12,
    padding: EdgeInsets.zero,
    height: 76,
    notchMargin: 8,
    shape: const CircularNotchedRectangle(),
    child: Row(
      children: [
        Expanded(
          child: _NavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: 'Home',
            selected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
        ),
        Expanded(
          child: _NavItem(
            icon: Icons.point_of_sale_outlined,
            selectedIcon: Icons.point_of_sale,
            label: 'Sell',
            selected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
        ),
        const SizedBox(width: 64),
        Expanded(
          child: _NavItem(
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2,
            label: 'Products',
            selected: selectedIndex == 2,
            onTap: () => onSelect(2),
          ),
        ),
        Expanded(
          child: _NavItem(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
            label: 'Invoices',
            selected: selectedIndex == 3,
            onTap: () => onSelect(3),
          ),
        ),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade600;
    return InkResponse(
      onTap: onTap,
      radius: 34,
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.controller,
    required this.selectedIndex,
    required this.onSelect,
    required this.onCustomers,
    required this.onSettings,
    required this.onReports,
    required this.onCloudBackup,
    required this.onSecurity,
    required this.onAbout,
    required this.onModeChanged,
    required this.switchingMode,
  });

  final AppController controller;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCustomers;
  final VoidCallback onSettings;
  final VoidCallback onReports;
  final VoidCallback onCloudBackup;
  final VoidCallback onSecurity;
  final VoidCallback onAbout;
  final ValueChanged<BillingMode> onModeChanged;
  final bool switchingMode;

  @override
  Widget build(BuildContext context) => Drawer(
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/branding/av-smartbilling-icon-concept-3.png',
                    width: 54,
                    height: 54,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AV Smartbilling',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Version 1.0.0',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close menu',
                  icon: const Icon(Icons.menu_open),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _DrawerItem(
                  icon: Icons.home_outlined,
                  label: 'Home',
                  selected: selectedIndex == 0,
                  onTap: () => onSelect(0),
                ),
                _DrawerItem(
                  icon: Icons.point_of_sale_outlined,
                  label: 'Sell',
                  selected: selectedIndex == 1,
                  onTap: () => onSelect(1),
                ),
                _DrawerItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Products',
                  selected: selectedIndex == 2,
                  onTap: () => onSelect(2),
                ),
                _DrawerItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Invoices',
                  selected: selectedIndex == 3,
                  onTap: () => onSelect(3),
                ),
                _DrawerItem(
                  icon: Icons.people_outline,
                  label: 'Customers',
                  onTap: onCustomers,
                ),
                _DrawerItem(
                  icon: Icons.analytics_outlined,
                  label: 'Reports & Exports',
                  onTap: onReports,
                ),
                _DrawerItem(
                  icon: Icons.cloud_upload_outlined,
                  label: 'Cloud Backup',
                  onTap: onCloudBackup,
                ),
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  label: 'Business Settings',
                  onTap: onSettings,
                ),
                _DrawerItem(
                  icon: Icons.lock_outline,
                  label: 'App Lock & Security',
                  onTap: onSecurity,
                ),
                const Divider(indent: 20, endIndent: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 4,
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: controller.isOnline
                          ? const Color(0xffe6f2f0)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          controller.isOnline
                              ? Icons.cloud_done_outlined
                              : Icons.phone_android_outlined,
                          color: controller.isOnline
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                controller.isOnline
                                    ? 'Online Mode'
                                    : 'Offline Mode',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                controller.isOnline
                                    ? 'Cloud Products & Customers'
                                    : 'Saved on this phone',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: controller.isOnline,
                          onChanged: switchingMode
                              ? null
                              : (value) => onModeChanged(
                                  value
                                      ? BillingMode.online
                                      : BillingMode.offline,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                _DrawerItem(
                  icon: Icons.info_outline,
                  label: 'About App',
                  onTap: onAbout,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                controller.session!.customerName,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    child: ListTile(
      selected: selected,
      selectedTileColor: const Color(0xffe6f2f0),
      selectedColor: Theme.of(context).colorScheme.primary,
      leading: Icon(icon),
      title: Text(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    ),
  );
}
