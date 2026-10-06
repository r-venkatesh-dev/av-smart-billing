
import 'package:av_smartbilling_mobile/src/app.dart';
import 'package:av_smartbilling_mobile/src/excel_import_export_service.dart';
import 'package:av_smartbilling_mobile/src/models.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAppController extends ChangeNotifier implements AppController {
  final List<Product> _products = [];
  final List<Customer> _customers = [];

  @override
  Future<List<Product>> products({String query = ''}) async => List.unmodifiable(_products);

  @override
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
    if (id != null) {
      final index = _products.indexWhere((p) => p.id == id);
      if (index != -1) {
        _products[index] = Product(
          id: id,
          name: name,
          sku: sku,
          barcode: barcode,
          unit: unit,
          priceInPaise: (price * 100).round(),
          taxRateBasisPoints: (taxRate * 100).round(),
          discountPercent: discountPercent,
          stockQuantity: stock,
          active: _products[index].active,
        );
        return;
      }
    }
    _products.add(Product(
      id: 'prod-${_products.length + 1}',
      name: name,
      sku: sku,
      barcode: barcode,
      unit: unit,
      priceInPaise: (price * 100).round(),
      taxRateBasisPoints: (taxRate * 100).round(),
      discountPercent: discountPercent,
      stockQuantity: stock,
      active: true,
    ));
  }

  @override
  Future<List<Customer>> customers() async => List.unmodifiable(_customers);

  @override
  Future<void> saveCustomer({
    String? id,
    required String name,
    required String phone,
    required String address,
    required String gstin,
  }) async {
    if (id != null) {
      final index = _customers.indexWhere((c) => c.id == id);
      if (index != -1) {
        _customers[index] = Customer(
          id: id,
          name: name,
          phone: phone,
          address: address,
          gstin: gstin,
        );
        return;
      }
    }
    _customers.add(Customer(
      id: 'cust-${_customers.length + 1}',
      name: name,
      phone: phone,
      address: address,
      gstin: gstin,
    ));
  }

  @override
  Future<void> checkLowStock() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Uint8List _createExcelBytes(List<List<CellValue>> rows) {
  final workbook = Excel.createExcel();
  final sheet = workbook['Sheet1'];
  for (final row in rows) {
    sheet.appendRow(row);
  }
  return Uint8List.fromList(workbook.save()!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ExcelImportExportService service;
  late MockAppController controller;

  setUp(() {
    service = ExcelImportExportService();
    controller = MockAppController();
  });

  group('Products Excel Import', () {
    test('imports new products from excel bytes', () async {
      final bytes = _createExcelBytes([
        [
          TextCellValue('Product Name'),
          TextCellValue('Price'),
          TextCellValue('Stock Quantity'),
          TextCellValue('Unit'),
          TextCellValue('SKU'),
        ],
        [
          TextCellValue('Basmati Rice 1kg'),
          DoubleCellValue(90.0),
          DoubleCellValue(40),
          TextCellValue('packet'),
          TextCellValue('RICE-01'),
        ],
        [
          TextCellValue('Organic Ghee 500ml'),
          DoubleCellValue(350.0),
          DoubleCellValue(15),
          TextCellValue('bottle'),
          TextCellValue('GHEE-01'),
        ],
      ]);

      final result = await service.importProducts(bytes, controller);

      expect(result.totalRows, 2);
      expect(result.addedCount, 2);
      expect(result.updatedCount, 0);
      expect(result.errors, isEmpty);

      final products = await controller.products();
      expect(products.length, 2);
      expect(products[0].name, 'Basmati Rice 1kg');
      expect(products[0].priceInPaise, 9000);
      expect(products[0].stockQuantity, 40);
      expect(products[1].name, 'Organic Ghee 500ml');
    });

    test('replaces existing products on duplicate SKU or Name', () async {
      // Pre-populate with existing product
      await controller.saveProduct(
        name: 'Basmati Rice 1kg',
        sku: 'RICE-01',
        barcode: '',
        unit: 'packet',
        price: 80.0,
        taxRate: 0,
        discountPercent: 0,
        stock: 10,
      );

      final bytes = _createExcelBytes([
        [
          TextCellValue('Product Name'),
          TextCellValue('Price'),
          TextCellValue('Stock'),
          TextCellValue('Unit'),
          TextCellValue('SKU'),
        ],
        // Duplicate SKU 'RICE-01' with updated price and stock
        [
          TextCellValue('Basmati Rice 1kg (Premium)'),
          DoubleCellValue(110.0),
          DoubleCellValue(50),
          TextCellValue('packet'),
          TextCellValue('RICE-01'),
        ],
        // New item
        [
          TextCellValue('Sugar 1kg'),
          DoubleCellValue(42.0),
          DoubleCellValue(100),
          TextCellValue('kg'),
          TextCellValue('SUGAR-01'),
        ],
      ]);

      final result = await service.importProducts(bytes, controller);

      expect(result.totalRows, 2);
      expect(result.addedCount, 1);
      expect(result.updatedCount, 1);
      expect(result.errors, isEmpty);

      final products = await controller.products();
      expect(products.length, 2);

      final updatedRice = products.firstWhere((p) => p.sku == 'RICE-01');
      expect(updatedRice.name, 'Basmati Rice 1kg (Premium)');
      expect(updatedRice.priceInPaise, 11000);
      expect(updatedRice.stockQuantity, 50);
    });

    test('skips invalid rows and reports line-by-line errors', () async {
      final bytes = _createExcelBytes([
        [
          TextCellValue('Product Name'),
          TextCellValue('Price'),
          TextCellValue('Stock'),
          TextCellValue('Unit'),
        ],
        // Valid row
        [
          TextCellValue('Wheat Flour 5kg'),
          DoubleCellValue(220.0),
          DoubleCellValue(25),
          TextCellValue('bag'),
        ],
        // Invalid: missing name
        [
          TextCellValue(''),
          DoubleCellValue(50.0),
          DoubleCellValue(10),
          TextCellValue('pcs'),
        ],
        // Invalid: negative price
        [
          TextCellValue('Invalid Price Item'),
          DoubleCellValue(-10.0),
          DoubleCellValue(5),
          TextCellValue('pcs'),
        ],
      ]);

      final result = await service.importProducts(bytes, controller);

      expect(result.totalRows, 3);
      expect(result.addedCount, 1);
      expect(result.updatedCount, 0);
      expect(result.errors.length, 2);
      expect(result.errors[0], contains('Row 3'));
      expect(result.errors[1], contains('Row 4'));

      final products = await controller.products();
      expect(products.length, 1);
      expect(products.single.name, 'Wheat Flour 5kg');
    });
  });

  group('Customers Excel Import', () {
    test('imports new customers and replaces duplicates by Phone or Name', () async {
      // Pre-populate an existing customer
      await controller.saveCustomer(
        name: 'Amit Patel',
        phone: '9876543210',
        address: 'Ahmedabad',
        gstin: '',
      );

      final bytes = _createExcelBytes([
        [
          TextCellValue('Customer Name'),
          TextCellValue('Phone Number'),
          TextCellValue('GSTIN'),
          TextCellValue('Address'),
        ],
        // Duplicate phone number -> update address & gstin
        [
          TextCellValue('Amit Patel'),
          TextCellValue('9876543210'),
          TextCellValue('24ABCDE1234F1Z5'),
          TextCellValue('Surat, Gujarat'),
        ],
        // New customer
        [
          TextCellValue('Sunita Roy'),
          TextCellValue('9123456780'),
          TextCellValue(''),
          TextCellValue('Kolkata'),
        ],
      ]);

      final result = await service.importCustomers(bytes, controller);

      expect(result.totalRows, 2);
      expect(result.addedCount, 1);
      expect(result.updatedCount, 1);
      expect(result.errors, isEmpty);

      final customers = await controller.customers();
      expect(customers.length, 2);

      final updatedAmit = customers.firstWhere((c) => c.phone == '9876543210');
      expect(updatedAmit.address, 'Surat, Gujarat');
      expect(updatedAmit.gstin, '24ABCDE1234F1Z5');
    });

    test('reports invalid mobile number on customer row', () async {
      final bytes = _createExcelBytes([
        [
          TextCellValue('Customer Name'),
          TextCellValue('Phone Number'),
        ],
        [
          TextCellValue('Invalid Phone Customer'),
          TextCellValue('12345'), // Invalid phone
        ],
      ]);

      final result = await service.importCustomers(bytes, controller);

      expect(result.totalRows, 1);
      expect(result.addedCount, 0);
      expect(result.errors.length, 1);
      expect(result.errors[0], contains('Row 2'));
    });
  });

  group('Templates & Exports Generation', () {
    test('downloadProductsTemplate creates valid excel workbook with sample rows', () async {
      Uint8List? sharedBytes;
      String? sharedName;

      final testService = ExcelImportExportService(
        shareHandler: (bytes, name, title, text) async {
          sharedBytes = bytes;
          sharedName = name;
        },
      );

      await testService.downloadProductsTemplate();

      expect(sharedBytes, isNotNull);
      expect(sharedName, 'av-smartbilling-products-template.xlsx');

      final excel = Excel.decodeBytes(sharedBytes!);
      final sheet = excel.tables['Products Template'];
      expect(sheet, isNotNull);
      expect(sheet!.rows.length, 4); // 1 header + 3 samples
      expect(sheet.rows[0][0]?.value.toString(), contains('Product Name'));
    });

    test('downloadCustomersTemplate creates valid excel workbook with sample rows', () async {
      Uint8List? sharedBytes;
      String? sharedName;

      final testService = ExcelImportExportService(
        shareHandler: (bytes, name, title, text) async {
          sharedBytes = bytes;
          sharedName = name;
        },
      );

      await testService.downloadCustomersTemplate();

      expect(sharedBytes, isNotNull);
      expect(sharedName, 'av-smartbilling-customers-template.xlsx');

      final excel = Excel.decodeBytes(sharedBytes!);
      final sheet = excel.tables['Customers Template'];
      expect(sheet, isNotNull);
      expect(sheet!.rows.length, 4);
      expect(sheet.rows[0][0]?.value.toString(), contains('Customer Name'));
    });

    test('exportProducts exports full product data to excel', () async {
      Uint8List? sharedBytes;
      String? sharedName;

      final testService = ExcelImportExportService(
        shareHandler: (bytes, name, title, text) async {
          sharedBytes = bytes;
          sharedName = name;
        },
      );

      final products = [
        const Product(
          id: 'p1',
          name: 'Coconut Oil 1L',
          sku: 'OIL-1',
          barcode: '890111',
          unit: 'bottle',
          priceInPaise: 25000,
          taxRateBasisPoints: 500,
          discountPercent: 10,
          stockQuantity: 30,
          active: true,
        ),
      ];

      await testService.exportProducts(products);

      expect(sharedBytes, isNotNull);
      expect(sharedName, startsWith('av-smartbilling-products-'));

      final excel = Excel.decodeBytes(sharedBytes!);
      final sheet = excel.tables['Products'];
      expect(sheet, isNotNull);
      expect(sheet!.rows.length, 2); // 1 header + 1 product
      expect(sheet.rows[1][0]?.value.toString(), contains('Coconut Oil 1L'));
    });

    test('exportCustomers exports full customer data to excel', () async {
      Uint8List? sharedBytes;
      String? sharedName;

      final testService = ExcelImportExportService(
        shareHandler: (bytes, name, title, text) async {
          sharedBytes = bytes;
          sharedName = name;
        },
      );

      final customers = [
        const Customer(
          id: 'c1',
          name: 'Vikram Singh',
          phone: '9888877777',
          address: 'Jaipur, Rajasthan',
          gstin: '08AAAAA0000A1Z5',
        ),
      ];

      await testService.exportCustomers(customers);

      expect(sharedBytes, isNotNull);
      expect(sharedName, startsWith('av-smartbilling-customers-'));

      final excel = Excel.decodeBytes(sharedBytes!);
      final sheet = excel.tables['Customers'];
      expect(sheet, isNotNull);
      expect(sheet!.rows.length, 2);
      expect(sheet.rows[1][0]?.value.toString(), contains('Vikram Singh'));
      expect(sheet.rows[1][1]?.value.toString(), contains('9888877777'));
    });
  });
}
