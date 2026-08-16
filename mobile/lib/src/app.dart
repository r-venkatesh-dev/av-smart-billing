import 'package:flutter/material.dart';

import 'app_database.dart';
import 'license_service.dart';
import 'models.dart';
import 'screens/activation_screen.dart';
import 'screens/home_shell.dart';

class AppController extends ChangeNotifier {
  AppController._({
    required this.database,
    required this.licenses,
    required this.session,
  });

  final AppDatabase database;
  final LicenseService licenses;
  LicenseSession? session;

  static Future<AppController> create() async {
    final database = await AppDatabase.open();
    final licenses = LicenseService();
    return AppController._(
      database: database,
      licenses: licenses,
      session: await licenses.readActiveSession(),
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
}

class AvSmartbillingApp extends StatelessWidget {
  const AvSmartbillingApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
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
        home: controller.session?.isActive == true
            ? HomeShell(controller: controller)
            : ActivationScreen(controller: controller),
      ),
    );
  }
}
