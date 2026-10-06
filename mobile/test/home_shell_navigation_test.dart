import 'package:av_smartbilling_mobile/src/screens/about_screen.dart';
import 'package:av_smartbilling_mobile/src/screens/home_shell.dart';
import 'package:av_smartbilling_mobile/src/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _aboutScreenTest();
  test('FixedCenterDockedFloatingActionButtonLocation stays anchored to contentBottom', () {
    const location = FixedCenterDockedFloatingActionButtonLocation();

    // Mock geometry
    final scaffoldGeometry = ScaffoldPrelayoutGeometry(
      bottomSheetSize: const Size(400, 0),
      contentBottom: 700,
      contentTop: 80,
      floatingActionButtonSize: const Size(56, 56),
      minInsets: EdgeInsets.zero,
      minViewPadding: EdgeInsets.zero,
      materialBannerSize: Size.zero,
      textDirection: TextDirection.ltr,
      scaffoldSize: const Size(400, 800),
      snackBarSize: const Size(360, 60),
    );

    final offset = location.getOffset(scaffoldGeometry);

    // fabX should be (400 - 56) / 2 = 172
    expect(offset.dx, 172.0);

    // fabY should be 700 - (56 / 2) = 672, ignoring snackBarSize (60)
    expect(offset.dy, 672.0);
  });

  testWidgets('showMessage creates floating snackbar with bottom clearance', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showMessage(context, 'Test notice'),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    final snackBarFinder = find.byType(SnackBar);
    expect(snackBarFinder, findsOneWidget);

    final SnackBar snackBar = tester.widget(snackBarFinder);
    expect(snackBar.behavior, SnackBarBehavior.floating);
    final margin = snackBar.margin as EdgeInsets?;
    expect(margin?.bottom, greaterThanOrEqualTo(80));
  });

  testWidgets('Screen with drawer renders hamburger icon and opens drawer on tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          drawer: Drawer(child: Text('Sidebar Drawer Content')),
          body: Builder(
            builder: _testBuilder,
          ),
        ),
      ),
    );

    // Initial state: drawer closed
    expect(find.text('Sidebar Drawer Content'), findsNothing);

    // Tap menu icon
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // Drawer is now open
    expect(find.text('Sidebar Drawer Content'), findsOneWidget);
  });

  testWidgets('Drawer item selection pops drawer and updates page index', (
    WidgetTester tester,
  ) async {
    int selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              appBar: AppBar(
                leading: Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              ),
              drawer: Drawer(
                child: ListView(
                  children: [
                    ListTile(
                      title: const Text('Products Drawer Item'),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => selected = 2);
                      },
                    ),
                    ListTile(
                      title: const Text('Invoices Drawer Item'),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => selected = 3);
                      },
                    ),
                  ],
                ),
              ),
              body: Center(child: Text('Current Page: $selected')),
            );
          },
        ),
      ),
    );

    expect(find.text('Current Page: 0'), findsOneWidget);

    // Open drawer
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Products Drawer Item'), findsOneWidget);

    // Tap Products drawer item
    await tester.tap(find.text('Products Drawer Item'));
    await tester.pumpAndSettle();

    // Drawer must be closed and page switched to 2
    expect(find.text('Products Drawer Item'), findsNothing);
    expect(find.text('Current Page: 2'), findsOneWidget);

    // Open drawer again and tap Invoices drawer item
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Invoices Drawer Item'), findsOneWidget);

    await tester.tap(find.text('Invoices Drawer Item'));
    await tester.pumpAndSettle();

    // Drawer must be closed and page switched to 3
    expect(find.text('Invoices Drawer Item'), findsNothing);
    expect(find.text('Current Page: 3'), findsOneWidget);
  });
}

Widget _testBuilder(BuildContext context) {
  return Scaffold(
    drawer: const Drawer(child: Text('Sidebar Drawer Content')),
    appBar: AppBar(
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open menu',
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
    ),
  );
}

void _aboutScreenTest() {
  testWidgets('AboutScreen renders hamburger icon and opens drawer when drawer provided', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AboutScreen(
          drawer: Drawer(child: Text('About Drawer Item')),
        ),
      ),
    );

    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.text('About Drawer Item'), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('About Drawer Item'), findsOneWidget);
  });
}
