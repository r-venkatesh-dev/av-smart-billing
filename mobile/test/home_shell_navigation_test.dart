import 'package:av_smartbilling_mobile/src/screens/home_shell.dart';
import 'package:av_smartbilling_mobile/src/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
