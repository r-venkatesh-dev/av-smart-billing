import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:av_smartbilling_mobile/src/app.dart';
import 'package:av_smartbilling_mobile/src/excel_import_export_service.dart';
import 'package:av_smartbilling_mobile/src/models.dart';

int colIndexFromRef(String ref) {
  int col = 0;
  for (int i = 0; i < ref.length; i++) {
    final code = ref.codeUnitAt(i);
    if (code >= 65 && code <= 90) {
      col = col * 26 + (code - 64);
    } else if (code >= 97 && code <= 122) {
      col = col * 26 + (code - 96);
    } else {
      break;
    }
  }
  return col > 0 ? col - 1 : 0;
}

List<List<String>> parseCsv(String raw) {
  String text = raw;
  if (text.startsWith('\uFEFF')) {
    text = text.substring(1);
  }

  // Detect delimiter: comma, semicolon, or tab
  String delimiter = ',';
  final firstLine = text.split('\n').firstOrNull ?? '';
  final commaCount = ','.allMatches(firstLine).length;
  final semicolonCount = ';'.allMatches(firstLine).length;
  final tabCount = '\t'.allMatches(firstLine).length;
  if (semicolonCount > commaCount && semicolonCount > tabCount) {
    delimiter = ';';
  } else if (tabCount > commaCount && tabCount > semicolonCount) {
    delimiter = '\t';
  }

  final rows = <List<String>>[];
  final currentRow = <String>[];
  final currentField = StringBuffer();
  bool inQuotes = false;
  int i = 0;

  while (i < text.length) {
    final char = text[i];

    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          currentField.write('"');
          i += 2;
          continue;
        } else {
          inQuotes = false;
          i++;
          continue;
        }
      } else {
        currentField.write(char);
        i++;
        continue;
      }
    } else {
      if (char == '"') {
        inQuotes = true;
        i++;
        continue;
      } else if (char == delimiter) {
        currentRow.add(currentField.toString().trim());
        currentField.clear();
        i++;
        continue;
      } else if (char == '\r') {
        if (i + 1 < text.length && text[i + 1] == '\n') {
          i++;
        }
        currentRow.add(currentField.toString().trim());
        currentField.clear();
        rows.add(List<String>.from(currentRow));
        currentRow.clear();
        i++;
        continue;
      } else if (char == '\n') {
        currentRow.add(currentField.toString().trim());
        currentField.clear();
        rows.add(List<String>.from(currentRow));
        currentRow.clear();
        i++;
        continue;
      } else {
        currentField.write(char);
        i++;
      }
    }
  }

  if (currentField.isNotEmpty || currentRow.isNotEmpty) {
    currentRow.add(currentField.toString().trim());
    rows.add(List<String>.from(currentRow));
  }

  return rows;
}

List<List<String>> decodeXlsxArchive(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final sharedStrings = <String>[];
  final ssFile = archive.findFile('xl/sharedStrings.xml');
  if (ssFile != null) {
    final rawBytes = ssFile.content as List<int>;
    final content = utf8.decode(rawBytes, allowMalformed: true);
    final doc = XmlDocument.parse(content);
    for (final si in doc.findAllElements('si')) {
      final buffer = StringBuffer();
      for (final t in si.findAllElements('t')) {
        buffer.write(t.innerText);
      }
      sharedStrings.add(buffer.toString());
    }
  }

  ArchiveFile? sheetFile;
  for (final f in archive.files) {
    if (f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')) {
      sheetFile = f;
      break;
    }
  }
  if (sheetFile == null) {
    throw Exception('The selected Excel file contains no readable worksheets.');
  }

  final sheetRaw = sheetFile.content as List<int>;
  final sheetContent = utf8.decode(sheetRaw, allowMalformed: true);
  final sheetDoc = XmlDocument.parse(sheetContent);
  final rows = <List<String>>[];

  for (final rowElem in sheetDoc.findAllElements('row')) {
    final rowList = <String>[];
    for (final cellElem in rowElem.findElements('c')) {
      final cellRef = cellElem.getAttribute('r') ?? '';
      final colIdx = colIndexFromRef(cellRef);
      final type = cellElem.getAttribute('t');

      String cellVal = '';
      if (type == 's') {
        final vElem = cellElem.findElements('v').firstOrNull;
        if (vElem != null) {
          final idx = int.tryParse(vElem.innerText.trim());
          if (idx != null && idx >= 0 && idx < sharedStrings.length) {
            cellVal = sharedStrings[idx];
          }
        }
      } else if (type == 'inlineStr') {
        final tElem = cellElem.findAllElements('t').firstOrNull;
        cellVal = tElem?.innerText ?? '';
      } else {
        final vElem = cellElem.findElements('v').firstOrNull;
        cellVal = vElem?.innerText.trim() ?? '';
      }

      while (rowList.length <= colIdx) {
        rowList.add('');
      }
      rowList[colIdx] = cellVal;
    }
    if (rowList.isNotEmpty) {
      rows.add(rowList);
    }
  }
  return rows;
}

void main() {
  test('colIndexFromRef correctly converts Excel cell coordinates', () {
    expect(colIndexFromRef('A1'), equals(0));
    expect(colIndexFromRef('B1'), equals(1));
    expect(colIndexFromRef('Z5'), equals(25));
    expect(colIndexFromRef('AA10'), equals(26));
    expect(colIndexFromRef('AB2'), equals(27));
  });

  test('parseCsv handles standard comma-separated with quotes and escaped quotes', () {
    const csvData = '''Product Name,Price,Stock,Unit,GST Rate
"Milk, 1L",55.5,100,pcs,5%
"Bread ""Special""",40,50,pcs,0%
Sugar,45,200,kg,5%''';

    final result = parseCsv(csvData);
    expect(result.length, equals(4));
    expect(result[0], equals(['Product Name', 'Price', 'Stock', 'Unit', 'GST Rate']));
    expect(result[1][0], equals('Milk, 1L'));
    expect(result[1][1], equals('55.5'));
    expect(result[2][0], equals('Bread "Special"'));
    expect(result[3][0], equals('Sugar'));
  });

  test('parseCsv handles semicolon-separated and UTF-8 BOM', () {
    const csvData = '\uFEFFProduct Name;Price;Stock;Unit\nWheat;30;500;kg\nRice;60;300;kg';
    final result = parseCsv(csvData);
    expect(result.length, equals(3));
    expect(result[0], equals(['Product Name', 'Price', 'Stock', 'Unit']));
    expect(result[1], equals(['Wheat', '30', '500', 'kg']));
  });

  test('decodeXlsxArchive extracts rows and values without crashing on style attributes', () {
    final archive = Archive();
    const sharedStringsXml = '<?xml version="1.0" encoding="UTF-8"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><si><t>Product Name</t></si><si><t>Price</t></si><si><t>Stock</t></si><si><t>Basmati Rice</t></si></sst>';
    archive.addFile(ArchiveFile('xl/sharedStrings.xml', sharedStringsXml.length, utf8.encode(sharedStringsXml)));

    const sheetXml = '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c></row><row r="2"><c r="A2" t="s"><v>3</v></c><c r="B2"><v>120.50</v></c><c r="C2"><v>25</v></c></row></sheetData></worksheet>';
    archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetXml.length, utf8.encode(sheetXml)));

    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
    final rows = decodeXlsxArchive(zipBytes);

    expect(rows.length, equals(2));
    expect(rows[0], equals(['Product Name', 'Price', 'Stock']));
    expect(rows[1][0], equals('Basmati Rice'));
    expect(rows[1][1], equals('120.50'));
    expect(rows[1][2], equals('25'));
  });

  test('ExcelImportExportService.importProducts imports products from CSV bytes cleanly', () async {
    final service = ExcelImportExportService();
    final controller = TestMockController();

    const csvContent = '''Product Name,Price,Stock,Unit,Item Code / SKU,Barcode,GST Rate (%),Discount (%)
Basmati Rice 1kg,120,50,kg,SKU-RICE-01,8901234567890,5%,0%
Sunflower Oil 1L,145.5,30,L,SKU-OIL-01,,5%,2%
Atta Whole Wheat 5kg,240,40,bag,SKU-ATTA-05,,0%,0%''';

    final bytes = Uint8List.fromList(utf8.encode(csvContent));
    final result = await service.importProducts(bytes, controller, fileName: 'products.csv');

    expect(result.addedCount, equals(3));
    expect(result.updatedCount, equals(0));
    expect(result.errors, isEmpty);

    final saved = await controller.products();
    expect(saved.length, equals(3));
    expect(saved[0].name, equals('Basmati Rice 1kg'));
    expect(saved[0].priceInPaise, equals(12000));
    expect(saved[0].unit, equals('kg'));
  });

  test('ExcelImportExportService.importCustomers imports customers from CSV bytes cleanly', () async {
    final service = ExcelImportExportService();
    final controller = TestMockController();

    const csvContent = '''Customer Name,Phone Number,GSTIN,Address
Ramesh Kumar,9876543210,33AAAAA0000A1Z5,"Shop #4, Main Bazaar, City"
Priya Sharma,9123456780,,"12 Green Avenue, Gandhi Nagar"''';

    final bytes = Uint8List.fromList(utf8.encode(csvContent));
    final result = await service.importCustomers(bytes, controller, fileName: 'customers.csv');

    expect(result.addedCount, equals(2));
    expect(result.updatedCount, equals(0));
    expect(result.errors, isEmpty);

    final saved = await controller.customers();
    expect(saved.length, equals(2));
    expect(saved[0].name, equals('Ramesh Kumar'));
    expect(saved[0].phone, equals('9876543210'));
  });
}

class TestMockController extends ChangeNotifier implements AppController {
  final List<Product> _products = [];
  final List<Customer> _customers = [];

  @override
  Future<List<Product>> products({String query = ''}) async => List.unmodifiable(_products);

  @override
  Future<List<Customer>> customers({String query = ''}) async => List.unmodifiable(_customers);

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
    _products.add(Product(
      id: id ?? 'prod-${_products.length + 1}',
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
  Future<void> saveCustomer({
    String? id,
    required String name,
    required String phone,
    required String address,
    required String gstin,
  }) async {
    _customers.add(Customer(
      id: id ?? 'cust-${_customers.length + 1}',
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
