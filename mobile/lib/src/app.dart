import 'dart:async';

import 'package:flutter/material.dart';

import 'app_database.dart';
import 'billing_mode_service.dart';
import 'license_service.dart';
import 'low_stock_notification_service.dart';
import 'models.dart';
import 'online_billing_service.dart';
import 'security_service.dart';
import 'screens/activation_screen.dart';
import 'screens/app_lock_screen.dart';
import 'screens/home_shell.dart';

ThemeData buildAppTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xff057c73),
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: const Color(0xfff7f8f7),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Color(0xff202623),
    surfaceTintColor: Colors.transparent,
  ),
  cardTheme: const CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
    filled: true,
    fillColor: Colors.white,
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Color(0xffd5eeeb),
    height: 68,
  ),
  useMaterial3: true,
);

class AppController extends ChangeNotifier {
  AppController._({
    required this.database,
    required this.licenses,
    required this.security,
    required this.lowStockNotifications,
    required this.billingModes,
    required this.onlineBilling,
    required this.billingMode,
    required this.session,
    required this.locked,
  });

  final AppDatabase database;
  final LicenseService licenses;
  final SecurityService security;
  final LowStockNotificationService lowStockNotifications;
  final BillingModeService billingModes;
  final OnlineBillingService onlineBilling;
  BillingMode billingMode;
  OnlineBillingStatus? onlineStatus;
  LicenseSession? session;
  bool locked;
  int dataRevision = 0;

  static Future<AppController> create() async {
    final database = await AppDatabase.open();
    final licenses = LicenseService();
    final security = SecurityService();
    final lowStockNotifications = LowStockNotificationService();
    const billingModes = BillingModeService();
    final onlineBilling = OnlineBillingService();
    final session = await licenses.readActiveSession();
    final billingMode = await billingModes.read();
    final controller = AppController._(
      database: database,
      licenses: licenses,
      security: security,
      lowStockNotifications: lowStockNotifications,
      billingModes: billingModes,
      onlineBilling: onlineBilling,
      billingMode: billingMode,
      session: session,
      locked: session?.isActive == true && await security.enabled,
    );
    unawaited(controller.checkLowStock());
    return controller;
  }

  Future<void> checkLowStock() async {
    try {
      if (isOnline) {
        final threshold = onlineStatus?.lowStockThreshold ?? 5;
        final lowStock = (await products())
            .where(
              (product) => product.active && product.stockQuantity <= threshold,
            )
            .toList();
        await lowStockNotifications.update(lowStock);
      } else {
        await lowStockNotifications.update(await database.lowStockProducts());
      }
    } catch (_) {
      // A notification failure must never block billing.
    }
  }

  void markDataChanged() {
    dataRevision++;
    notifyListeners();
  }

  bool get isOnline => billingMode == BillingMode.online;

  Future<void> ensureOnlineReady() async {
    final current = session;
    if (current == null) {
      throw Exception('Activate the app before going online.');
    }
    onlineStatus = await onlineBilling.status(current.token);
  }

  Future<void> switchBillingMode(BillingMode mode) async {
    if (mode == billingMode) {
      if (mode == BillingMode.online) await ensureOnlineReady();
      return;
    }
    if (mode == BillingMode.online) {
      await validateLicense();
      await ensureOnlineReady();
    }
    await billingModes.save(mode);
    billingMode = mode;
    dataRevision++;
    notifyListeners();
    unawaited(checkLowStock());
  }

  Future<List<Product>> products({String query = ''}) => isOnline
      ? onlineBilling.products(session!.token, query: query)
      : database.products(query: query);

  Future<void> saveProduct({
    String? id,
    required String name,
    required String sku,
    required String barcode,
    required String unit,
    required double price,
    required double taxRate,
    required double discountPercent,
    required double stock,
  }) => isOnline
      ? onlineBilling.saveProduct(
          session!.token,
          id: id,
          name: name,
          sku: sku,
          barcode: barcode,
          unit: unit,
          price: price,
          taxRate: taxRate,
          discountPercent: discountPercent,
          stock: stock,
        )
      : database.saveProduct(
          id: id,
          name: name,
          sku: sku,
          barcode: barcode,
          unit: unit,
          price: price,
          taxRate: taxRate,
          discountPercent: discountPercent,
          stock: stock,
        );

  Future<void> setProductActive(String id, bool active) => isOnline
      ? onlineBilling.setProductActive(session!.token, id, active)
      : database.setProductActive(id, active);

  Future<void> deleteProduct(String id) => isOnline
      ? onlineBilling.deleteProduct(session!.token, id)
      : database.deleteProduct(id);

  Future<List<Customer>> customers() =>
      isOnline ? onlineBilling.customers(session!.token) : database.customers();

  Future<void> saveCustomer({
    String? id,
    required String name,
    required String phone,
    required String address,
    required String gstin,
  }) => isOnline
      ? onlineBilling.saveCustomer(
          session!.token,
          id: id,
          name: name,
          phone: phone,
          address: address,
          gstin: gstin,
        )
      : database.saveCustomer(
          id: id,
          name: name,
          phone: phone,
          address: address,
          gstin: gstin,
        );

  Future<void> deleteCustomer(String id) => isOnline
      ? onlineBilling.deleteCustomer(session!.token, id)
      : database.deleteCustomer(id);

  Future<void> activate(String key) async {
    session = await licenses.activate(key);
    billingMode = BillingMode.offline;
    await billingModes.save(billingMode);
    await database.initializeBusinessName(session!.customerName);
    notifyListeners();
  }

  Future<void> validateLicense() async {
    final current = session;
    if (current == null) throw Exception('No activation is stored.');
    session = await licenses.validate(current);
  }

  Future<bool> unlockWithPin(String pin) async {
    if (!await security.verifyPin(pin)) return false;
    locked = false;
    notifyListeners();
    return true;
  }

  Future<bool> unlockWithBiometric() async {
    if (!await security.authenticateBiometric()) return false;
    locked = false;
    notifyListeners();
    return true;
  }

  Future<void> lockIfEnabled() async {
    if (session?.isActive == true && await security.enabled && !locked) {
      locked = true;
      notifyListeners();
    }
  }

  void lockNow() {
    locked = true;
    notifyListeners();
  }
}

class AvSmartbillingApp extends StatefulWidget {
  const AvSmartbillingApp({super.key, required this.controller});
  final AppController controller;

  @override
  State<AvSmartbillingApp> createState() => _AvSmartbillingAppState();
}

class _AvSmartbillingAppState extends State<AvSmartbillingApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      widget.controller.lockIfEnabled();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => MaterialApp(
        title: 'AV Smartbilling',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: widget.controller.session?.isActive == true
            ? widget.controller.locked
                  ? AppLockScreen(controller: widget.controller)
                  : HomeShell(controller: widget.controller)
            : ActivationScreen(controller: widget.controller),
      ),
    );
  }
}
