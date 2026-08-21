class LineAmounts {
  const LineAmounts({
    required this.subtotal,
    required this.discount,
    required this.taxable,
    required this.tax,
  });
  final int subtotal;
  final int discount;
  final int taxable;
  final int tax;
  int get total => taxable + tax;
}

class BillAmounts {
  const BillAmounts({
    required this.subtotal,
    required this.lineDiscount,
    required this.overallDiscount,
    required this.tax,
  });

  final int subtotal;
  final int lineDiscount;
  final int overallDiscount;
  final int tax;

  int get discount => lineDiscount + overallDiscount;
  int get taxable => subtotal - discount;
  int get total => taxable + tax;
}

LineAmounts calculateLine({
  required int priceInPaise,
  required double quantity,
  required double discountPercent,
  required int taxRateBasisPoints,
}) {
  if (priceInPaise < 0 || quantity <= 0) {
    throw ArgumentError('Price and quantity must be valid.');
  }
  final safeDiscount = discountPercent.clamp(0, 100).toDouble();
  final subtotal = (priceInPaise * quantity).round();
  final discount = (subtotal * safeDiscount / 100).round();
  final taxable = subtotal - discount;
  final tax = (taxable * taxRateBasisPoints / 10000).round();
  return LineAmounts(
    subtotal: subtotal,
    discount: discount,
    taxable: taxable,
    tax: tax,
  );
}

BillAmounts calculateBill({
  required Iterable<({LineAmounts amounts, int taxRateBasisPoints})> lines,
  double overallDiscountPercent = 0,
}) {
  final values = lines.toList();
  final safeOverallDiscount = overallDiscountPercent.clamp(0, 100).toDouble();
  final subtotal = values.fold<int>(
    0,
    (sum, line) => sum + line.amounts.subtotal,
  );
  final lineDiscount = values.fold<int>(
    0,
    (sum, line) => sum + line.amounts.discount,
  );
  var overallDiscount = 0;
  var tax = 0;
  for (final line in values) {
    final allocated = (line.amounts.taxable * safeOverallDiscount / 100)
        .round();
    overallDiscount += allocated;
    final taxable = line.amounts.taxable - allocated;
    tax += (taxable * line.taxRateBasisPoints / 10000).round();
  }
  return BillAmounts(
    subtotal: subtotal,
    lineDiscount: lineDiscount,
    overallDiscount: overallDiscount,
    tax: tax,
  );
}
