import 'package:av_smartbilling_mobile/src/billing_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('billing calculations', () {
    test('calculates GST after discount using integer paise', () {
      final result = calculateLine(
        priceInPaise: 10000,
        quantity: 2,
        discountPercent: 10,
        taxRateBasisPoints: 1800,
      );
      expect(result.subtotal, 20000);
      expect(result.discount, 2000);
      expect(result.taxable, 18000);
      expect(result.tax, 3240);
      expect(result.total, 21240);
    });

    test('supports fractional quantities', () {
      final result = calculateLine(
        priceInPaise: 8000,
        quantity: 1.5,
        discountPercent: 0,
        taxRateBasisPoints: 500,
      );
      expect(result.subtotal, 12000);
      expect(result.tax, 600);
      expect(result.total, 12600);
    });

    test('rejects zero quantity', () {
      expect(
        () => calculateLine(
          priceInPaise: 1000,
          quantity: 0,
          discountPercent: 0,
          taxRateBasisPoints: 0,
        ),
        throwsArgumentError,
      );
    });

    test(
      'applies an overall discount after product discounts and before GST',
      () {
        final line = calculateLine(
          priceInPaise: 10000,
          quantity: 2,
          discountPercent: 10,
          taxRateBasisPoints: 1800,
        );
        final bill = calculateBill(
          lines: [(amounts: line, taxRateBasisPoints: 1800)],
          overallDiscountPercent: 10,
        );

        expect(bill.subtotal, 20000);
        expect(bill.lineDiscount, 2000);
        expect(bill.overallDiscount, 1800);
        expect(bill.tax, 2916);
        expect(bill.total, 19116);
      },
    );
  });
}
