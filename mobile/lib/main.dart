import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<AppController> controller;

  @override
  void initState() {
    super.initState();
    controller = _initialize();
  }

  Future<AppController> _initialize() async {
    final initializing = AppController.create();
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    return initializing;
  }

  void _retry() => setState(() => controller = _initialize());

  @override
  Widget build(BuildContext context) => FutureBuilder<AppController>(
    future: controller,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return AvSmartbillingApp(controller: snapshot.data!);
      }
      return MaterialApp(
        title: 'AV Smartbilling',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: AnimatedSplashScreen(
          error: snapshot.hasError,
          onRetry: snapshot.hasError ? _retry : null,
        ),
      );
    },
  );
}
