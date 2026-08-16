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
