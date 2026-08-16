import 'package:flutter/material.dart';

import 'app_database.dart';
import 'license_service.dart';
import 'models.dart';
import 'security_service.dart';
import 'screens/activation_screen.dart';
import 'screens/app_lock_screen.dart';
import 'screens/home_shell.dart';

class AppController extends ChangeNotifier {
  AppController._({
    required this.database,
    required this.licenses,
    required this.security,
    required this.session,
    required this.locked,
  });

  final AppDatabase database;
  final LicenseService licenses;
  final SecurityService security;
  LicenseSession? session;
  bool locked;

  static Future<AppController> create() async {
    final database = await AppDatabase.open();
    final licenses = LicenseService();
    final security = SecurityService();
    final session = await licenses.readActiveSession();
    return AppController._(
      database: database,
      licenses: licenses,
      security: security,
      session: session,
      locked: session?.isActive == true && await security.enabled,
    );
  }

  Future<void> activate(String key) async {
    session = await licenses.activate(key);
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
        theme: ThemeData(
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
        ),
        home: widget.controller.session?.isActive == true
            ? widget.controller.locked
                  ? AppLockScreen(controller: widget.controller)
                  : HomeShell(controller: widget.controller)
            : ActivationScreen(controller: widget.controller),
      ),
    );
  }
}
