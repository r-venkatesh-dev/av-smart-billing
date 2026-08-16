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
  });

  test('rolls back invoice creation when stock is insufficient', () async {
    await database.saveProduct(
      name: 'Pen',
      sku: 'PEN-1',
      barcode: '',
      unit: 'pcs',
      price: 10,
      taxRate: 0,
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
}
