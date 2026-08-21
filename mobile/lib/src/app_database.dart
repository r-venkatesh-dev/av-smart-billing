import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'billing_math.dart';
import 'input_rules.dart';
import 'models.dart';

class AppDatabase {
  AppDatabase._(this.db);
  final Database db;

  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? filePath,
  }) async {
    final selectedFactory = factory ?? databaseFactory;
    final root = await selectedFactory.getDatabasesPath();
    final database = await selectedFactory.openDatabase(
      filePath ?? path.join(root, 'av-smartbilling-mobile.sqlite'),
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute(
            '''create table business(id text primary key, company_name text not null, phone text not null default '', address text not null default '', gstin text not null default '', state_code text not null default '', invoice_prefix text not null default 'INV', next_invoice_number integer not null default 1, invoice_footer text not null default '', payment_qr_path text not null default '', low_stock_threshold real not null default 5)''',
          );
          await db.execute(
            '''create table products(id text primary key, name text not null, sku text not null unique, barcode text unique, unit text not null default 'unit', price_in_paise integer not null check(price_in_paise >= 0), tax_rate_basis_points integer not null default 0, discount_percent real not null default 0 check(discount_percent between 0 and 100), stock_quantity real not null default 0 check(stock_quantity >= 0), active integer not null default 1, created_at text not null, updated_at text not null)''',
          );
          await db.execute(
            '''create table customers(id text primary key, name text not null, phone text not null default '', address text not null default '', gstin text, created_at text not null, updated_at text not null)''',
          );
          await db.execute(
            '''create table invoices(id text primary key, invoice_number text not null unique, customer_id text references customers(id), customer_name text not null, customer_phone text not null default '', customer_address text not null default '', customer_gstin text, issued_at text not null, status text not null, subtotal_in_paise integer not null, discount_in_paise integer not null, line_discount_in_paise integer not null default 0, overall_discount_percent real not null default 0, overall_discount_in_paise integer not null default 0, tax_in_paise integer not null, total_in_paise integer not null, payment_method text not null, created_at text not null)''',
          );
          await db.execute(
            '''create table invoice_items(id text primary key, invoice_id text not null references invoices(id) on delete cascade, product_id text not null references products(id), description text not null, sku text not null, unit text not null, quantity real not null, unit_price_in_paise integer not null, tax_rate_basis_points integer not null, discount_percent real not null default 0, discount_in_paise integer not null, taxable_in_paise integer not null, tax_in_paise integer not null)''',
          );
          await _createHeldBillTables(db);
          await db.execute(
            'create index invoices_issued_idx on invoices(issued_at desc)',
          );
          await db.insert('business', {
            'id': 'local-business',
            'company_name': 'My Business',
          });
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              "alter table business add column payment_qr_path text not null default ''",
            );
            await db.execute(
              'alter table business add column low_stock_threshold real not null default 5',
            );
            await db.execute(
              'alter table products add column discount_percent real not null default 0',
            );
            await db.execute(
              'alter table invoices add column line_discount_in_paise integer not null default 0',
            );
            await db.execute(
              'alter table invoices add column overall_discount_percent real not null default 0',
            );
            await db.execute(
              'alter table invoices add column overall_discount_in_paise integer not null default 0',
            );
            await db.execute(
              'update invoices set line_discount_in_paise=discount_in_paise',
            );
            await db.execute(
              'alter table invoice_items add column discount_percent real not null default 0',
            );
            await _createHeldBillTables(db);
          }
        },
      ),
    );
    await database.execute('pragma foreign_keys = on');
    return AppDatabase._(database);
  }

  static Future<void> _createHeldBillTables(Database db) async {
    await db.execute(
      '''create table if not exists held_bills(id text primary key, label text not null, created_at text not null)''',
    );
    await db.execute(
      '''create table if not exists held_bill_items(id text primary key, held_bill_id text not null references held_bills(id) on delete cascade, product_id text not null references products(id) on delete cascade, quantity real not null check(quantity > 0), discount_percent real not null default 0)''',
    );
    await db.execute(
      'create index if not exists held_bill_items_bill_idx on held_bill_items(held_bill_id)',
    );
  }

  Future<void> initializeBusinessName(String customerName) async {
    final business = await getBusiness();
    if (business['company_name'] == 'My Business') {
      await db.update(
        'business',
        {'company_name': customerName},
        where: 'id=?',
        whereArgs: ['local-business'],
      );
    }
  }

  Future<Map<String, Object?>> getBusiness() async => (await db.query(
    'business',
    where: 'id=?',
    whereArgs: ['local-business'],
    limit: 1,
  )).single;

  Future<void> saveBusiness(Map<String, Object?> values) async {
    final phoneError = validateOptionalMobileNumber(values['phone'] as String?);
    if (phoneError != null) throw Exception(phoneError);
    await db.update(
      'business',
      values,
      where: 'id=?',
      whereArgs: ['local-business'],
    );
  }

  Future<List<Product>> products({String query = ''}) async {
    final q = query.trim();
    final rows = await db.query(
      'products',
      where: q.isEmpty ? null : '(name like ? or sku like ? or barcode like ?)',
      whereArgs: q.isEmpty ? null : ['%$q%', '%$q%', '%$q%'],
      orderBy: 'active desc, name collate nocase',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> productByBarcode(String value) async {
    final rows = await db.query(
      'products',
      where: 'active=1 and (barcode=? or sku=?)',
      whereArgs: [value, value],
      limit: 1,
    );
    return rows.isEmpty ? null : Product.fromMap(rows.single);
  }

  Future<void> saveProduct({
    String? id,
    required String name,
    required String sku,
    required String barcode,
    required String unit,
    required double price,
    required double taxRate,
    required double discountPercent,
    required double stock,
  }) async {
    final cleanUnit = unit.trim();
    if (name.trim().length < 2 ||
        sku.trim().isEmpty ||
        cleanUnit.isEmpty ||
        double.tryParse(cleanUnit) != null ||
        price < 0 ||
        stock < 0 ||
        taxRate < 0 ||
        taxRate > 100 ||
        discountPercent < 0 ||
        discountPercent > 100) {
      throw Exception('Enter valid product details.');
    }
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final row = {
      'id': id ?? const Uuid().v4(),
      'name': name.trim(),
      'sku': sku.trim().toUpperCase(),
      'barcode': barcode.trim().isEmpty ? null : barcode.trim(),
      'unit': cleanUnit,
      'price_in_paise': (price * 100).round(),
      'tax_rate_basis_points': (taxRate * 100).round(),
      'discount_percent': discountPercent,
      'stock_quantity': stock,
      'active': 1,
      'created_at': timestamp,
      'updated_at': timestamp,
    };
    try {
      if (id == null) {
        await db.insert('products', row);
      } else {
        row.remove('created_at');
        row.remove('active');
        await db.update('products', row, where: 'id=?', whereArgs: [id]);
      }
    } on DatabaseException catch (error) {
      final message = error.toString();
      if (message.contains('products.sku')) {
        throw Exception('This SKU is already used by another product.');
      }
      if (message.contains('products.barcode')) {
        throw Exception('This barcode is already used by another product.');
      }
      throw Exception('The product could not be saved. Please try again.');
    }
  }

  Future<void> setProductActive(String id, bool active) async {
    await db.update(
      'products',
      {
        'active': active ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> deleteProduct(String id) async {
    final used =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'select count(*) from invoice_items where product_id=?',
            [id],
          ),
        ) ??
        0;
    if (used > 0) {
      throw Exception(
        'This product is part of an invoice and cannot be deleted. Mark it inactive instead.',
      );
    }
    await db.delete('products', where: 'id=?', whereArgs: [id]);
  }

  Future<List<Customer>> customers() async => (await db.query(
    'customers',
    orderBy: 'name collate nocase',
  )).map(Customer.fromMap).toList();

  Future<void> saveCustomer({
    String? id,
    required String name,
    required String phone,
    required String address,
    required String gstin,
  }) async {
    if (name.trim().length < 2) throw Exception('Customer name is required.');
    final phoneError = validateOptionalMobileNumber(phone);
    if (phoneError != null) throw Exception(phoneError);
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final row = {
      'id': id ?? const Uuid().v4(),
      'name': name.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'gstin': gstin.trim().isEmpty ? null : gstin.trim().toUpperCase(),
      'created_at': timestamp,
      'updated_at': timestamp,
    };
    if (id == null) {
      await db.insert('customers', row);
    } else {
      row.remove('created_at');
      await db.update('customers', row, where: 'id=?', whereArgs: [id]);
    }
  }

  Future<void> deleteCustomer(String id) => db.transaction((txn) async {
    await txn.update(
      'invoices',
      {'customer_id': null},
      where: 'customer_id=?',
      whereArgs: [id],
    );
    await txn.delete('customers', where: 'id=?', whereArgs: [id]);
  });

  Future<void> deleteInvoice(String id) => db.transaction((txn) async {
    final items = await txn.query(
      'invoice_items',
      columns: ['product_id', 'quantity'],
      where: 'invoice_id=?',
      whereArgs: [id],
    );
    final timestamp = DateTime.now().toUtc().toIso8601String();
    for (final item in items) {
      await txn.rawUpdate(
        'update products set stock_quantity=stock_quantity+?, updated_at=? where id=?',
        [item['quantity'], timestamp, item['product_id']],
      );
    }
    await txn.delete('invoices', where: 'id=?', whereArgs: [id]);
  });

  Future<List<Product>> lowStockProducts() async {
    final business = await getBusiness();
    final threshold = (business['low_stock_threshold'] as num).toDouble();
    final rows = await db.query(
      'products',
      where: 'active=1 and stock_quantity<=?',
      whereArgs: [threshold],
      orderBy: 'stock_quantity, name collate nocase',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<String> holdBill(List<CartLine> lines) async {
    if (lines.isEmpty) {
      throw Exception('Add products before holding this bill.');
    }
    return db.transaction((txn) async {
      final id = const Uuid().v4();
      final createdAt = DateTime.now().toUtc();
      await txn.insert('held_bills', {
        'id': id,
        'label':
            'Held bill ${createdAt.toLocal().hour.toString().padLeft(2, '0')}:${createdAt.toLocal().minute.toString().padLeft(2, '0')}',
        'created_at': createdAt.toIso8601String(),
      });
      for (final line in lines) {
        await txn.insert('held_bill_items', {
          'id': const Uuid().v4(),
          'held_bill_id': id,
          'product_id': line.product.id,
          'quantity': line.quantity,
          'discount_percent': line.discountPercent,
        });
      }
      return id;
    });
  }

  Future<List<HeldBillSummary>> heldBills() async {
    final rows = await db.rawQuery(
      '''select h.id, h.label, h.created_at, count(i.id) item_count
         from held_bills h left join held_bill_items i on i.held_bill_id=h.id
         group by h.id order by h.created_at desc''',
    );
    return rows
        .map(
          (row) => HeldBillSummary(
            id: row['id'] as String,
            label: row['label'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
            itemCount: (row['item_count'] as num).toInt(),
          ),
        )
        .toList();
  }

  Future<List<CartLine>> takeHeldBill(String id) => db.transaction((txn) async {
    final rows = await txn.rawQuery(
      '''select p.*, i.quantity held_quantity, i.discount_percent held_discount
         from held_bill_items i join products p on p.id=i.product_id
         where i.held_bill_id=? and p.active=1 and p.stock_quantity>0''',
      [id],
    );
    final lines = rows
        .map((row) {
          final product = Product.fromMap(row);
          return CartLine(
            product: product,
            quantity: ((row['held_quantity'] as num).toDouble()).clamp(
              0,
              product.stockQuantity,
            ),
            discountPercent: (row['held_discount'] as num).toDouble(),
          );
        })
        .where((line) => line.quantity > 0)
        .toList();
    await txn.delete('held_bills', where: 'id=?', whereArgs: [id]);
    return lines;
  });

  Future<void> deleteHeldBill(String id) async {
    await db.delete('held_bills', where: 'id=?', whereArgs: [id]);
  }

  Future<DashboardStats> dashboard() async {
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).toUtc().toIso8601String();
    final todayRow = await db.rawQuery(
      'select coalesce(sum(total_in_paise),0) value from invoices where issued_at>=?',
      [start],
    );
    final totalRow = await db.rawQuery(
      'select coalesce(sum(total_in_paise),0) value from invoices',
    );
    final invoiceRow = await db.rawQuery('select count(*) value from invoices');
    final productRow = await db.rawQuery(
      'select count(*) value from products where active=1',
    );
    final business = await getBusiness();
    final lowStockThreshold = (business['low_stock_threshold'] as num)
        .toDouble();
    final lowRow = await db.rawQuery(
      'select count(*) value from products where active=1 and stock_quantity<=?',
      [lowStockThreshold],
    );
    return DashboardStats(
      todaySales: (todayRow.single['value'] as num).toInt(),
      totalSales: (totalRow.single['value'] as num).toInt(),
      invoiceCount: (invoiceRow.single['value'] as num).toInt(),
      productCount: (productRow.single['value'] as num).toInt(),
      lowStockCount: (lowRow.single['value'] as num).toInt(),
    );
  }

  Future<List<InvoiceSummary>> invoices() async => (await db.query(
    'invoices',
    orderBy: 'issued_at desc',
  )).map(InvoiceSummary.fromMap).toList();

  Future<SalesReport> salesReport(DateTime from, DateTime to) async {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(
      to.year,
      to.month,
      to.day,
    ).add(const Duration(days: 1));
    final rows = await db.query(
      'invoices',
      where: 'issued_at>=? and issued_at<?',
      whereArgs: [
        start.toUtc().toIso8601String(),
        end.toUtc().toIso8601String(),
      ],
      orderBy: 'issued_at desc',
    );
    return SalesReport(
      from: start,
      to: DateTime(to.year, to.month, to.day),
      invoices: rows
          .map(
            (row) => ReportInvoice(
              invoiceNumber: row['invoice_number'] as String,
              customerName: row['customer_name'] as String,
              issuedAt: DateTime.parse(row['issued_at'] as String),
              status: row['status'] as String,
              paymentMethod: row['payment_method'] as String,
              subtotalInPaise: row['subtotal_in_paise'] as int,
              discountInPaise: row['discount_in_paise'] as int,
              taxInPaise: row['tax_in_paise'] as int,
              totalInPaise: row['total_in_paise'] as int,
            ),
          )
          .toList(),
    );
  }

  Future<InvoiceDetail> invoice(String id) async {
    final invoice = (await db.query(
      'invoices',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    )).single;
    final items = await db.query(
      'invoice_items',
      where: 'invoice_id=?',
      whereArgs: [id],
    );
    return InvoiceDetail(
      invoice: invoice,
      items: items,
      business: await getBusiness(),
    );
  }

  Future<List<CloudBackupRecord>> cloudBackupRecords(String entity) async {
    switch (entity) {
      case 'products':
        final rows = await db.query('products', orderBy: 'created_at');
        return rows
            .map(
              (row) => CloudBackupRecord(
                localId: row['id'] as String,
                updatedAt: DateTime.parse(row['updated_at'] as String),
                payload: Map<String, Object?>.from(row),
              ),
            )
            .toList();
      case 'customers':
        final rows = await db.query('customers', orderBy: 'created_at');
        return rows
            .map(
              (row) => CloudBackupRecord(
                localId: row['id'] as String,
                updatedAt: DateTime.parse(row['updated_at'] as String),
                payload: Map<String, Object?>.from(row),
              ),
            )
            .toList();
      case 'invoices':
        final rows = await db.query('invoices', orderBy: 'created_at');
        final records = <CloudBackupRecord>[];
        for (final row in rows) {
          final id = row['id'] as String;
          final items = await db.query(
            'invoice_items',
            where: 'invoice_id=?',
            whereArgs: [id],
          );
          records.add(
            CloudBackupRecord(
              localId: id,
              updatedAt: DateTime.parse(row['created_at'] as String),
              payload: {
                ...Map<String, Object?>.from(row),
                'items': items.map(Map<String, Object?>.from).toList(),
              },
            ),
          );
        }
        return records;
      default:
        throw ArgumentError.value(entity, 'entity', 'Unsupported backup type');
    }
  }

  Future<String> createInvoice({
    Customer? customer,
    required String walkInName,
    required String walkInPhone,
    required List<CartLine> lines,
    required String paymentMethod,
    double overallDiscountPercent = 0,
  }) async {
    if (lines.isEmpty) throw Exception('Add at least one product.');
    if (customer == null && walkInName.trim().length < 2) {
      throw Exception('Enter the walk-in customer name.');
    }
    if (customer == null) {
      final phoneError = validateOptionalMobileNumber(walkInPhone);
      if (phoneError != null) throw Exception(phoneError);
    }
    return db.transaction((txn) async {
      final business = (await txn.query(
        'business',
        where: 'id=?',
        whereArgs: ['local-business'],
      )).single;
      final prepared =
          <({Product product, double quantity, LineAmounts amounts})>[];
      for (final line in lines) {
        final row = (await txn.query(
          'products',
          where: 'id=? and active=1',
          whereArgs: [line.product.id],
          limit: 1,
        ));
        if (row.isEmpty) {
          throw Exception('${line.product.name} is no longer available.');
        }
        final product = Product.fromMap(row.single);
        if (line.quantity <= 0 || product.stockQuantity < line.quantity) {
          throw Exception('Not enough stock for ${product.name}.');
        }
        prepared.add((
          product: product,
          quantity: line.quantity,
          amounts: calculateLine(
            priceInPaise: product.priceInPaise,
            quantity: line.quantity,
            discountPercent: line.discountPercent,
            taxRateBasisPoints: product.taxRateBasisPoints,
          ),
        ));
      }
      final subtotal = prepared.fold<int>(
        0,
        (sum, item) => sum + item.amounts.subtotal,
      );
      final bill = calculateBill(
        lines: prepared.map(
          (item) => (
            amounts: item.amounts,
            taxRateBasisPoints: item.product.taxRateBasisPoints,
          ),
        ),
        overallDiscountPercent: overallDiscountPercent,
      );
      final discount = bill.discount;
      final tax = bill.tax;
      final total = bill.total;
      final id = const Uuid().v4();
      final issuedAt = DateTime.now().toUtc().toIso8601String();
      final number = business['next_invoice_number'] as int;
      final invoiceNumber =
          '${business['invoice_prefix']}-${number.toString().padLeft(6, '0')}';
      final paid = paymentMethod != 'CREDIT';
      await txn.insert('invoices', {
        'id': id,
        'invoice_number': invoiceNumber,
        'customer_id': customer?.id,
        'customer_name': customer?.name ?? walkInName.trim(),
        'customer_phone': customer?.phone ?? walkInPhone.trim(),
        'customer_address': customer?.address ?? '',
        'customer_gstin': customer?.gstin.isEmpty == true
            ? null
            : customer?.gstin,
        'issued_at': issuedAt,
        'status': paid ? 'PAID' : 'DUE',
        'subtotal_in_paise': subtotal,
        'discount_in_paise': discount,
        'line_discount_in_paise': bill.lineDiscount,
        'overall_discount_percent': overallDiscountPercent.clamp(0, 100),
        'overall_discount_in_paise': bill.overallDiscount,
        'tax_in_paise': tax,
        'total_in_paise': total,
        'payment_method': paymentMethod,
        'created_at': issuedAt,
      });
      for (final item in prepared) {
        final allocatedOverallDiscount =
            (item.amounts.taxable * overallDiscountPercent.clamp(0, 100) / 100)
                .round();
        final taxable = item.amounts.taxable - allocatedOverallDiscount;
        final itemTax = (taxable * item.product.taxRateBasisPoints / 10000)
            .round();
        await txn.insert('invoice_items', {
          'id': const Uuid().v4(),
          'invoice_id': id,
          'product_id': item.product.id,
          'description': item.product.name,
          'sku': item.product.sku,
          'unit': item.product.unit,
          'quantity': item.quantity,
          'unit_price_in_paise': item.product.priceInPaise,
          'tax_rate_basis_points': item.product.taxRateBasisPoints,
          'discount_percent': item.amounts.subtotal == 0
              ? 0
              : item.amounts.discount * 100 / item.amounts.subtotal,
          'discount_in_paise': item.amounts.discount,
          'taxable_in_paise': taxable,
          'tax_in_paise': itemTax,
        });
        await txn.rawUpdate(
          'update products set stock_quantity=stock_quantity-?, updated_at=? where id=?',
          [item.quantity, issuedAt, item.product.id],
        );
      }
      await txn.rawUpdate(
        "update business set next_invoice_number=next_invoice_number+1 where id='local-business'",
      );
      return id;
    });
  }

  Future<void> close() => db.close();
}
