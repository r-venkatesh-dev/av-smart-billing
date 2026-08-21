import 'package:av_smartbilling_mobile/src/models.dart';
import 'package:av_smartbilling_mobile/src/screens/editor_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('product editor closes without lifecycle assertions', (
    tester,
  ) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => ProductEditorDialog(
                  onSave:
                      ({
                        id,
                        required name,
                        required sku,
                        required barcode,
                        required unit,
                        required price,
                        required taxRate,
                        required discountPercent,
                        required stock,
                      }) async {
                        saved = true;
                      },
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Product name'),
      'Tea',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Selling price ₹'),
      '20',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer editor closes without lifecycle assertions', (
    tester,
  ) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => CustomerEditorDialog(
                  onSave:
                      ({
                        id,
                        required name,
                        required phone,
                        required address,
                        required gstin,
                      }) async {
                        saved = true;
                      },
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Customer name'),
      'Anand',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout sheet owns and disposes its form state safely', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final product = Product(
      id: 'p1',
      name: 'Tea',
      sku: 'TEA-1',
      barcode: '',
      unit: 'pcs',
      priceInPaise: 2000,
      taxRateBasisPoints: 500,
      discountPercent: 0,
      stockQuantity: 10,
      active: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showModalBottomSheet<String>(
                context: context,
                builder: (_) => CheckoutSheet(
                  cart: [CartLine(product: product)],
                  customers: const [],
                  onSave: (_, _, _, _, _) async => 'invoice-1',
                  onCancel: () {},
                ),
              ),
              child: const Text('Checkout'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Checkout'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Complete sale'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete sale'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout cancellation clears the draft without saving', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final product = Product(
      id: 'p1',
      name: 'Tea',
      sku: 'TEA-1',
      barcode: '',
      unit: 'pcs',
      priceInPaise: 2000,
      taxRateBasisPoints: 500,
      discountPercent: 0,
      stockQuantity: 10,
      active: true,
    );
    var cancelled = false;
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showModalBottomSheet<String>(
                context: context,
                builder: (_) => CheckoutSheet(
                  cart: [CartLine(product: product)],
                  customers: const [],
                  onSave: (_, _, _, _, _) async {
                    saved = true;
                    return 'invoice-1';
                  },
                  onCancel: () => cancelled = true,
                ),
              ),
              child: const Text('Checkout'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Checkout'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cancel bill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel bill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel bill').last);
    await tester.pumpAndSettle();

    expect(cancelled, isTrue);
    expect(saved, isFalse);
    expect(find.text('Complete bill'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
