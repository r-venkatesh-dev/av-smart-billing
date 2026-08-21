import 'package:av_smartbilling_mobile/src/models.dart';
import 'package:av_smartbilling_mobile/src/screens/products_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('product card remains readable on a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final product = Product(
      id: 'p1',
      name: 'Clinic Plus Shampoo With A Very Long Product Name',
      sku: 'AV-818296',
      barcode: '890000000001',
      unit: '10',
      priceInPaise: 10000,
      taxRateBasisPoints: 0,
      discountPercent: 0,
      stockQuantity: 97,
      active: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              ProductCard(
                product: product,
                onEdit: () {},
                onDelete: () {},
                onStatusChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Stock: 97 items'), findsOneWidget);
    expect(find.textContaining('97.0 10'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
