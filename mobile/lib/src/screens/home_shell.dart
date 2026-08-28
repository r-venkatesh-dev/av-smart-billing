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
        builder: (context) => AppDialog(
          icon: Icons.cloud_off_outlined,
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
      builder: (context) => AppDialog(
        icon: Icons.swap_horiz_rounded,
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
        builder: (context) => AppDialog(
          icon: Icons.cloud_off_outlined,
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
      if (widget.controller.session?.allowReportsExports != true) {
        showDialog<void>(
          context: context,
          builder: (context) => AppDialog(
            icon: Icons.lock_outline_rounded,
            title: const Text('Reports & Exports are not included'),
            content: const Text(
              'Your current plan does not include reports or CSV, Excel, and PDF exports. Upgrade your plan and activate the new key to use this feature.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
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
      if (widget.controller.session?.allowCloudBackup != true) {
        showDialog<void>(
          context: context,
          builder: (context) => AppDialog(
            icon: Icons.cloud_off_outlined,
            title: const Text('Cloud Backup is not included'),
            content: const Text(
              'Your current plan supports offline billing only. Upgrade your plan and activate the new key to use Cloud Backup.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
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
              onInvoices: () => _selectPage(3),
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
  Widget build(BuildContext context) {
    final drawerWidth = (MediaQuery.sizeOf(context).width * 0.86)
        .clamp(304.0, 380.0)
        .toDouble();
    final safePadding = MediaQuery.paddingOf(context);

    return Drawer(
      width: drawerWidth,
      backgroundColor: const Color(0xfffffdf9),
      shape: const RoundedRectangleBorder(),
      child: Column(
        children: [
          Container(
            height: 150 + safePadding.top,
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 16 + safePadding.top, 20, 12),
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/branding/drawer-header-pattern.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/branding/app-logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AV Smartbilling',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Tooltip(
                            message:
                                controller.session?.allowOnlineBilling == true
                                ? 'Tap to switch billing mode'
                                : 'Current billing mode',
                            child: Material(
                              color: Colors.white.withValues(alpha: 0.17),
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap:
                                    switchingMode ||
                                        controller
                                                .session
                                                ?.allowOnlineBilling !=
                                            true
                                    ? null
                                    : () => onModeChanged(
                                        controller.isOnline
                                            ? BillingMode.offline
                                            : BillingMode.online,
                                      ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (switchingMode)
                                        const SizedBox.square(
                                          dimension: 10,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(
                                            color: controller.isOnline
                                                ? const Color(0xff20e369)
                                                : Colors.white70,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      Text(
                                        controller.isOnline
                                            ? 'Online Mode'
                                            : 'Offline Mode',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                FutureBuilder<Map<String, Object?>>(
                  future: controller.database.getBusiness(),
                  builder: (context, snapshot) {
                    final business = snapshot.data;
                    final savedName =
                        (business?['company_name'] as String?)?.trim() ?? '';
                    final fallbackName =
                        controller.session?.customerName.trim() ?? '';
                    final name = savedName.isNotEmpty
                        ? savedName
                        : fallbackName.isNotEmpty
                        ? fallbackName
                        : 'My Business';
                    final gstin = (business?['gstin'] as String?)?.trim() ?? '';
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onSettings,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.storefront_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (gstin.isNotEmpty)
                                      Text(
                                        'GSTIN: $gstin',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
              children: [
                // Padding(
                //   padding: const EdgeInsets.symmetric(horizontal: 16),
                //   child: FilledButton.icon(
                //     onPressed: () => onSelect(1),
                //     icon: const Icon(Icons.add_circle, size: 26),
                //     label: const Text('New Sale'),
                //     style: FilledButton.styleFrom(
                //       backgroundColor: const Color(0xff07877e),
                //       foregroundColor: Colors.white,
                //       minimumSize: const Size.fromHeight(54),
                //       textStyle: const TextStyle(
                //         fontSize: 18,
                //         fontWeight: FontWeight.w700,
                //       ),
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(7),
                //       ),
                //     ),
                //   ),
                // ),
                const _DrawerSectionLabel('OVERVIEW'),
                _DrawerItem(
                  icon: Icons.home_outlined,
                  label: 'Home',
                  selected: selectedIndex == 0,
                  onTap: () => onSelect(0),
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: Color(0xffd9dddb)),
                ),
                const _DrawerSectionLabel('TOOLS'),
                if (controller.session?.allowReportsExports == true)
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: Color(0xffd9dddb)),
                ),
                _DrawerItem(
                  icon: Icons.info_outline,
                  label: 'About App',
                  onTap: onAbout,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onAbout,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 9, 20, 10 + safePadding.bottom),
              decoration: const BoxDecoration(
                color: Color(0xfff0faf7),
                border: Border(top: BorderSide(color: Color(0xffd8ebe7))),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xffdcefeb),
                    foregroundColor: Color(0xff057c73),
                    child: Icon(Icons.person_outline),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        color: Color(0xff34413e),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 5),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xff4b504f),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
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
    padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 3),
    child: Stack(
      children: [
        ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -1),
          selected: selected,
          selectedTileColor: const Color(0xffe6f2f0),
          selectedColor: const Color(0xff057c73),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 14, 0),
          leading: CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xffdff1ee),
            foregroundColor: const Color(0xff057c73),
            child: Icon(icon, size: 20),
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onTap: onTap,
        ),
        if (selected)
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xff057c73),
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(5),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
