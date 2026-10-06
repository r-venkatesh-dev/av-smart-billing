import 'package:av_smartbilling_mobile/src/screens/gst_calculator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GstCalculatorScreen renders and computes Exclusive & Inclusive GST', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: GstCalculatorScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Default amount is 1000 with 18% GST Exclusive
    // Base: 1000.00, GST: 180.00, Final: 1180.00
    expect(find.text('GST Calculator'), findsOneWidget);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xff004d40));
    expect(appBar.centerTitle, true);
    expect(find.byIcon(Icons.menu), findsOneWidget);

    expect(find.text('PRICE BREAKUP'), findsOneWidget);
    expect(find.text('₹1000.00'), findsOneWidget);
    expect(find.text('+ ₹180.00'), findsOneWidget);
    expect(find.text('₹1180.00'), findsOneWidget);

    // Switch to Inclusive
    await tester.tap(find.text('Inclusive (− Remove GST)'));
    await tester.pumpAndSettle();

    // With 1000 total including 18% GST:
    // Base: 1000 / 1.18 = 847.46, GST: 152.54, Final: 1000.00
    expect(find.text('₹847.46'), findsOneWidget);
    expect(find.text('+ ₹152.54'), findsOneWidget);
    expect(find.text('₹1000.00'), findsWidgets);
  });

  testWidgets('GstCalculatorScreen opens side drawer when hamburger button is tapped', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GstCalculatorScreen(
          drawer: Drawer(child: Text('Sidebar Calculator Drawer Content')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sidebar Calculator Drawer Content'), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Sidebar Calculator Drawer Content'), findsOneWidget);
  });
}
