class LicenseSession {
  const LicenseSession({
    required this.token,
    required this.publicKey,
    required this.issuer,
    required this.deviceId,
    required this.customerName,
    required this.planName,
    required this.expiresAt,
    required this.validUntil,
    required this.allowOnlineBilling,
    required this.allowCloudBackup,
    required this.allowReportsExports,
  });

  final String token;
  final String publicKey;
  final String issuer;
  final String deviceId;
  final String customerName;
  final String planName;
  final DateTime expiresAt;
  final DateTime validUntil;
  final bool allowOnlineBilling;
  final bool allowCloudBackup;
  final bool allowReportsExports;

  bool get isActive => DateTime.now().isBefore(validUntil);
  Map<String, Object?> toJson() => {
    'token': token,
    'publicKey': publicKey,
    'issuer': issuer,
    'deviceId': deviceId,
    'customerName': customerName,
    'planName': planName,
    'expiresAt': expiresAt.toIso8601String(),
    'validUntil': validUntil.toIso8601String(),
    'allowOnlineBilling': allowOnlineBilling,
    'allowCloudBackup': allowCloudBackup,
    'allowReportsExports': allowReportsExports,
  };
  factory LicenseSession.fromJson(Map<String, dynamic> json) => LicenseSession(
    token: json['token'] as String,
    publicKey: json['publicKey'] as String,
    issuer: json['issuer'] as String,
    deviceId: json['deviceId'] as String,
    customerName: json['customerName'] as String,
    planName: json['planName'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    validUntil: DateTime.parse(json['validUntil'] as String),
    allowOnlineBilling: json['allowOnlineBilling'] as bool? ?? true,
    allowCloudBackup: json['allowCloudBackup'] as bool? ?? true,
    allowReportsExports: json['allowReportsExports'] as bool? ?? true,
  );
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.unit,
    required this.priceInPaise,
    required this.taxRateBasisPoints,
    required this.discountPercent,
    required this.stockQuantity,
    required this.active,
  });
  final String id;
  final String name;
  final String sku;
  final String barcode;
  final String unit;
  final int priceInPaise;
  final int taxRateBasisPoints;
  final double discountPercent;
  final double stockQuantity;
  final bool active;
  factory Product.fromMap(Map<String, Object?> row) => Product(
    id: row['id'] as String,
    name: row['name'] as String,
    sku: row['sku'] as String,
    barcode: (row['barcode'] as String?) ?? '',
    unit: row['unit'] as String,
    priceInPaise: row['price_in_paise'] as int,
    taxRateBasisPoints: row['tax_rate_basis_points'] as int,
    discountPercent: (row['discount_percent'] as num?)?.toDouble() ?? 0,
    stockQuantity: (row['stock_quantity'] as num).toDouble(),
    active: row['active'] == 1,
  );
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.gstin,
  });
  final String id;
  final String name;
  final String phone;
  final String address;
  final String gstin;
  factory Customer.fromMap(Map<String, Object?> row) => Customer(
    id: row['id'] as String,
    name: row['name'] as String,
    phone: row['phone'] as String,
    address: row['address'] as String,
    gstin: (row['gstin'] as String?) ?? '',
  );
}

class CartLine {
  CartLine({
    required this.product,
    this.quantity = 1,
    this.discountPercent = 0,
  });
  final Product product;
  double quantity;
  double discountPercent;
}

class HeldBillSummary {
  const HeldBillSummary({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.itemCount,
  });

  final String id;
  final String label;
  final DateTime createdAt;
  final int itemCount;
}

class InvoiceSummary {
  const InvoiceSummary({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.issuedAt,
    required this.totalInPaise,
    required this.status,
  });
  final String id;
  final String invoiceNumber;
  final String customerName;
  final DateTime issuedAt;
  final int totalInPaise;
  final String status;
  factory InvoiceSummary.fromMap(Map<String, Object?> row) => InvoiceSummary(
    id: row['id'] as String,
    invoiceNumber: row['invoice_number'] as String,
    customerName: row['customer_name'] as String,
    issuedAt: DateTime.parse(row['issued_at'] as String),
    totalInPaise: row['total_in_paise'] as int,
    status: row['status'] as String,
  );
}

class InvoiceDetail {
  const InvoiceDetail({
    required this.invoice,
    required this.items,
    required this.business,
  });
  final Map<String, Object?> invoice;
  final List<Map<String, Object?>> items;
  final Map<String, Object?> business;
}

class DashboardStats {
  const DashboardStats({
    required this.todaySales,
    required this.totalSales,
    required this.invoiceCount,
    required this.productCount,
    required this.lowStockCount,
  });
  final int todaySales;
  final int totalSales;
  final int invoiceCount;
  final int productCount;
  final int lowStockCount;
}

class CloudBackupRecord {
  const CloudBackupRecord({
    required this.localId,
    required this.updatedAt,
    required this.payload,
  });

  final String localId;
  final DateTime updatedAt;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {
    'localId': localId,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'payload': payload,
  };
}

class ReportInvoice {
  const ReportInvoice({
    required this.invoiceNumber,
    required this.customerName,
    required this.issuedAt,
    required this.status,
    required this.paymentMethod,
    required this.subtotalInPaise,
    required this.discountInPaise,
    required this.taxInPaise,
    required this.totalInPaise,
  });

  final String invoiceNumber;
  final String customerName;
  final DateTime issuedAt;
  final String status;
  final String paymentMethod;
  final int subtotalInPaise;
  final int discountInPaise;
  final int taxInPaise;
  final int totalInPaise;
}

class SalesReport {
  const SalesReport({
    required this.from,
    required this.to,
    required this.invoices,
  });

  final DateTime from;
  final DateTime to;
  final List<ReportInvoice> invoices;

  int get invoiceCount => invoices.length;
  int get totalSales => invoices.fold(0, (sum, row) => sum + row.totalInPaise);
  int get totalTax => invoices.fold(0, (sum, row) => sum + row.taxInPaise);
  int get totalDiscount =>
      invoices.fold(0, (sum, row) => sum + row.discountInPaise);
  int get collected => invoices
      .where((row) => row.status == 'PAID')
      .fold(0, (sum, row) => sum + row.totalInPaise);
  int get outstanding => invoices
      .where((row) => row.status != 'PAID')
      .fold(0, (sum, row) => sum + row.totalInPaise);

  Map<String, int> get paymentTotals {
    final totals = <String, int>{};
    for (final invoice in invoices) {
      totals.update(
        invoice.paymentMethod,
        (value) => value + invoice.totalInPaise,
        ifAbsent: () => invoice.totalInPaise,
      );
    }
    return totals;
  }
}
