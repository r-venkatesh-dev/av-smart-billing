import 'package:av_smartbilling_mobile/src/app.dart';
import 'package:av_smartbilling_mobile/src/app_database.dart';
import 'package:av_smartbilling_mobile/src/models.dart';
import 'package:av_smartbilling_mobile/src/screens/pos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDb extends Fake implements AppDatabase {
  @override
  Future<List<Product>> products({String query = ''}) async => [];

  @override
  Future<List<HeldBillSummary>> heldBills() async => [];
}

class _FakeController extends ChangeNotifier implements AppController {
  @override
  final AppDatabase database = _FakeDb();

  @override
  bool get isOnline => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('PosScreen renders teal top header and matching search bar UI', (tester) async {
    final controller = _FakeController();

    await tester.pumpWidget(
      MaterialApp(
        home: PosScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    // Check AppBar styling
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xff004d40));
    expect(appBar.centerTitle, true);
    expect(find.text('Quick Sell'), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsWidgets);

    // Check search input hint
    expect(find.text('Search products by name, SKU or barcode...'), findsOneWidget);
  });

  testWidgets('PosScreen opens side drawer when hamburger button is tapped', (tester) async {
    final controller = _FakeController();

    await tester.pumpWidget(
      MaterialApp(
        home: PosScreen(
          controller: controller,
          drawer: const Drawer(child: Text('Sidebar POS Drawer Content')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sidebar POS Drawer Content'), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Sidebar POS Drawer Content'), findsOneWidget);
  });
}
