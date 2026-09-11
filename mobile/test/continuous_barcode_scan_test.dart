import 'package:av_smartbilling_mobile/src/screens/barcode_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('in.avsmartbilling.mobile/sound'),
      (MethodCall methodCall) async => true,
    );
  });

  testWidgets('BarcodeScannerScreen displays continuous title and custom bottom summary', (
    WidgetTester tester,
  ) async {
    bool finished = false;

    await tester.pumpWidget(
      MaterialApp(
        home: BarcodeScannerScreen(
          title: 'Scan products',
          onContinuousScan: (code) async {
            if (code == '123') {
              return const BarcodeScanFeedback(
                success: true,
                title: 'Added Item A',
                subtitle: 'Qty: 1  •  ₹100.00',
              );
            }
            return BarcodeScanFeedback(
              success: false,
              title: 'No matching product',
              subtitle: 'Barcode: $code',
            );
          },
          bottomSummary: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                finished = true;
                Navigator.pop(context);
              },
              child: const Text('Finish Test'),
            ),
          ),
        ),
      ),
    );

    // Verify title and finish button
    expect(find.text('Scan products'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Finish Test'), findsOneWidget);

    // Tap Finish Test
    await tester.tap(find.text('Finish Test'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });

  testWidgets('BarcodeScannerScreen in single scan mode displays default instructions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BarcodeScannerScreen(),
      ),
    );

    expect(find.text('Scan barcode'), findsOneWidget);
    expect(find.text('Place product barcode inside the box'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
  });
}
