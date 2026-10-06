import 'package:av_smartbilling_mobile/src/ui_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats quantities without confusing trailing zeroes', () {
    expect(formatQuantity(97.0), '97');
    expect(formatQuantity(1.25), '1.25');
    expect(stockLabel(97, '10'), 'Stock: 97 items');
    expect(stockLabel(2.5, 'kg'), 'Stock: 2.5 kg');
    expect(stockLabel(10, '1pcs'), 'Stock: 10 pcs');
    expect(stockLabel(10, '1 pcs'), 'Stock: 10 pcs');
    expect(stockLabel(10, '1'), 'Stock: 10 pcs');
    expect(stockLabel(1, 'pcs'), 'Stock: 1 pc');
  });
}
