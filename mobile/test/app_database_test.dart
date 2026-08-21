import 'dart:io';

import 'package:av_smartbilling_mobile/src/app_database.dart';
import 'package:av_smartbilling_mobile/src/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      filePath: inMemoryDatabasePath,
    );
  });

  tearDown(() async => database.close());

  test('saves products and gives a useful duplicate SKU error', () async {
    await database.saveProduct(
      name: 'Tea',
      sku: 'TEA-1',
      barcode: '1001',
      unit: 'pcs',
      price: 20,
      taxRate: 5,
      discountPercent: 0,
      stock: 10,
    );
    final products = await database.products();
    expect(products.single.name, 'Tea');
    expect(products.single.priceInPaise, 2000);

    await expectLater(
      database.saveProduct(
        name: 'Coffee',
        sku: 'TEA-1',
        barcode: '1002',
        unit: 'pcs',
        price: 30,
        taxRate: 5,
        discountPercent: 0,
        stock: 10,
      ),
      throwsA(
        predicate((error) => error.toString().contains('SKU is already used')),
      ),
    );
  });

  test('creates an invoice and deducts stock atomically', () async {
    await database.saveProduct(
      name: 'Notebook',
      sku: 'BOOK-1',
      barcode: '',
      unit: 'pcs',
      price: 100,
      taxRate: 18,
      discountPercent: 0,
      stock: 5,
    );
    final product = (await database.products()).single;
    final id = await database.createInvoice(
      customer: null,
      walkInName: 'Walk-in Customer',
      walkInPhone: '',
      lines: [CartLine(product: product, quantity: 2)],
      paymentMethod: 'UPI',
    );

    final invoice = await database.invoice(id);
    expect(invoice.invoice['status'], 'PAID');
    expect(invoice.invoice['total_in_paise'], 23600);
    expect(invoice.items.single['quantity'], 2.0);
    expect((await database.products()).single.stockQuantity, 3);

    final report = await database.salesReport(
      DateTime.now().subtract(const Duration(days: 1)),
      DateTime.now().add(const Duration(days: 1)),
    );
    expect(report.invoiceCount, 1);
    expect(report.totalSales, 23600);
    expect(report.collected, 23600);
    expect(report.paymentTotals['UPI'], 23600);

    final productBackup = await database.cloudBackupRecords('products');
    expect(productBackup.single.localId, product.id);
    expect(productBackup.single.payload['stock_quantity'], 3.0);

    final invoiceBackup = await database.cloudBackupRecords('invoices');
    expect(invoiceBackup.single.localId, id);
    expect(invoiceBackup.single.payload['items'], isA<List<Object?>>());
    expect(
      invoiceBackup.single.payload['items'] as List<Object?>,
      hasLength(1),
    );
  });

  test(
    'rejects customer mobile numbers that are not exactly 10 digits',
    () async {
      await expectLater(
        database.saveCustomer(
          name: 'Invalid Phone',
          phone: '98765432101',
          address: '',
          gstin: '',
        ),
        throwsA(predicate((error) => error.toString().contains('10-digit'))),
      );
      expect(await database.customers(), isEmpty);
    },
  );

  test('rolls back invoice creation when stock is insufficient', () async {
    await database.saveProduct(
      name: 'Pen',
      sku: 'PEN-1',
      barcode: '',
      unit: 'pcs',
      price: 10,
      taxRate: 0,
      discountPercent: 0,
      stock: 1,
    );
    final product = (await database.products()).single;
    await expectLater(
      database.createInvoice(
        customer: null,
        walkInName: 'Walk-in Customer',
        walkInPhone: '',
        lines: [CartLine(product: product, quantity: 2)],
        paymentMethod: 'CASH',
      ),
      throwsA(
        predicate((error) => error.toString().contains('Not enough stock')),
      ),
    );
    expect(await database.invoices(), isEmpty);
    expect((await database.products()).single.stockQuantity, 1);
  });

  test('holds and resumes a bill without changing stock', () async {
    await database.saveProduct(
      name: 'Juice',
      sku: 'JUICE-1',
      barcode: '',
      unit: 'bottle',
      price: 50,
      taxRate: 5,
      discountPercent: 7.5,
      stock: 8,
    );
    final product = (await database.products()).single;
    await database.holdBill([
      CartLine(product: product, quantity: 3, discountPercent: 7.5),
    ]);

    final held = await database.heldBills();
    expect(held, hasLength(1));
    expect(held.single.itemCount, 1);
    expect((await database.products()).single.stockQuantity, 8);

    final resumed = await database.takeHeldBill(held.single.id);
    expect(resumed.single.quantity, 3);
    expect(resumed.single.discountPercent, 7.5);
    expect(await database.heldBills(), isEmpty);
  });

  test('deleting an invoice restores stock', () async {
    await database.saveProduct(
      name: 'Bottle',
      sku: 'BOTTLE-1',
      barcode: '',
      unit: 'pcs',
      price: 100,
      taxRate: 18,
      discountPercent: 10,
      stock: 5,
    );
    final product = (await database.products()).single;
    final invoiceId = await database.createInvoice(
      customer: null,
      walkInName: 'Walk-in Customer',
      walkInPhone: '',
      lines: [CartLine(product: product, quantity: 2, discountPercent: 10)],
      paymentMethod: 'CASH',
      overallDiscountPercent: 5,
    );
    final detail = await database.invoice(invoiceId);
    expect(detail.invoice['line_discount_in_paise'], 2000);
    expect(detail.invoice['overall_discount_in_paise'], 900);
    expect((await database.products()).single.stockQuantity, 3);

    await database.deleteInvoice(invoiceId);
    expect(await database.invoices(), isEmpty);
    expect((await database.products()).single.stockQuantity, 5);
  });

  test(
    'deleting a customer preserves its historical invoice snapshot',
    () async {
      await database.saveProduct(
        name: 'Pen',
        sku: 'PEN-CUSTOMER',
        barcode: '',
        unit: 'pcs',
        price: 10,
        taxRate: 0,
        discountPercent: 0,
        stock: 2,
      );
      await database.saveCustomer(
        name: 'Anand Stores',
        phone: '9876543210',
        address: 'Chennai',
        gstin: '',
      );
      final customer = (await database.customers()).single;
      final invoiceId = await database.createInvoice(
        customer: customer,
        walkInName: '',
        walkInPhone: '',
        lines: [CartLine(product: (await database.products()).single)],
        paymentMethod: 'CASH',
      );

      await database.deleteCustomer(customer.id);
      expect(await database.customers(), isEmpty);
      final detail = await database.invoice(invoiceId);
      expect(detail.invoice['customer_id'], isNull);
      expect(detail.invoice['customer_name'], 'Anand Stores');
    },
  );

  test('protects products used by historical invoices from deletion', () async {
    await database.saveProduct(
      name: 'Protected',
      sku: 'PROTECTED-1',
      barcode: '',
      unit: 'pcs',
      price: 20,
      taxRate: 0,
      discountPercent: 0,
      stock: 2,
    );
    final product = (await database.products()).single;
    await database.createInvoice(
      customer: null,
      walkInName: 'Walk-in Customer',
      walkInPhone: '',
      lines: [CartLine(product: product)],
      paymentMethod: 'CASH',
    );

    await expectLater(
      database.deleteProduct(product.id),
      throwsA(predicate((error) => error.toString().contains('inactive'))),
    );
    await database.setProductActive(product.id, false);
    expect((await database.products()).single.active, isFalse);
    await database.saveProduct(
      id: product.id,
      name: 'Protected updated',
      sku: product.sku,
      barcode: '',
      unit: 'pcs',
      price: 25,
      taxRate: 0,
      discountPercent: 0,
      stock: 1,
    );
    expect((await database.products()).single.active, isFalse);
  });

  test('migrates a version 1 customer database without losing data', () async {
    final directory = await Directory.systemTemp.createTemp('avsb-migration-');
    addTearDown(() => directory.delete(recursive: true));
    final filePath = '${directory.path}/billing.sqlite';
    final oldDatabase = await databaseFactoryFfi.openDatabase(
      filePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            '''create table business(id text primary key, company_name text not null, phone text not null default '', address text not null default '', gstin text not null default '', state_code text not null default '', invoice_prefix text not null default 'INV', next_invoice_number integer not null default 1, invoice_footer text not null default '')''',
          );
          await db.execute(
            '''create table products(id text primary key, name text not null, sku text not null unique, barcode text unique, unit text not null default 'unit', price_in_paise integer not null, tax_rate_basis_points integer not null default 0, stock_quantity real not null default 0, active integer not null default 1, created_at text not null, updated_at text not null)''',
          );
          await db.execute(
            '''create table invoices(id text primary key, invoice_number text not null unique, customer_id text, customer_name text not null, customer_phone text not null default '', customer_address text not null default '', customer_gstin text, issued_at text not null, status text not null, subtotal_in_paise integer not null, discount_in_paise integer not null, tax_in_paise integer not null, total_in_paise integer not null, payment_method text not null, created_at text not null)''',
          );
          await db.execute(
            '''create table invoice_items(id text primary key, invoice_id text not null, product_id text not null, description text not null, sku text not null, unit text not null, quantity real not null, unit_price_in_paise integer not null, tax_rate_basis_points integer not null, discount_in_paise integer not null, taxable_in_paise integer not null, tax_in_paise integer not null)''',
          );
          await db.insert('business', {
            'id': 'local-business',
            'company_name': 'Existing Shop',
          });
          await db.insert('products', {
            'id': 'old-product',
            'name': 'Existing Product',
            'sku': 'OLD-1',
            'unit': 'pcs',
            'price_in_paise': 1000,
            'created_at': '2026-01-01T00:00:00.000Z',
            'updated_at': '2026-01-01T00:00:00.000Z',
          });
        },
      ),
    );
    await oldDatabase.close();

    final migrated = await AppDatabase.open(
      factory: databaseFactoryFfi,
      filePath: filePath,
    );
    expect((await migrated.getBusiness())['company_name'], 'Existing Shop');
    expect((await migrated.products()).single.name, 'Existing Product');
    expect((await migrated.products()).single.discountPercent, 0);
    expect(await migrated.heldBills(), isEmpty);
    await migrated.close();
  });
}
