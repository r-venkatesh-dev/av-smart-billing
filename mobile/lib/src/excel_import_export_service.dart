import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xml/xml.dart';

import 'app.dart';
import 'input_rules.dart';
import 'models.dart';
import 'ui_helpers.dart';

class ImportResult {
  const ImportResult({
    required this.totalRows,
    required this.addedCount,
    required this.updatedCount,
    required this.errors,
  });

  final int totalRows;
  final int addedCount;
  final int updatedCount;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
  int get successCount => addedCount + updatedCount;
}

class ExcelImportExportService {
  ExcelImportExportService({this.shareHandler});

  final Future<void> Function(Uint8List bytes, String fileName, String title, String text)? shareHandler;
  static final _dateFormat = DateFormat('yyyyMMdd');

  // ===========================================================================
  // PRODUCTS: TEMPLATE & EXPORT
  // ===========================================================================

  Future<void> downloadProductsTemplate() async {
    final workbook = Excel.createExcel();
    final sheet = workbook['Products Template'];
    workbook.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('Product Name *'),
      TextCellValue('Price (Rs) *'),
      TextCellValue('Stock Quantity *'),
      TextCellValue('Selling Unit *'),
      TextCellValue('SKU'),
      TextCellValue('Barcode'),
      TextCellValue('GST Rate (%)'),
      TextCellValue('Discount (%)'),
    ]);

    // Sample rows for user guidance
    sheet.appendRow([
      TextCellValue('Apple Shimla'),
      DoubleCellValue(120.00),
      DoubleCellValue(50),
      TextCellValue('kg'),
      TextCellValue('APP-001'),
      TextCellValue('8901234567890'),
      DoubleCellValue(0),
      DoubleCellValue(5),
    ]);
    sheet.appendRow([
      TextCellValue('Full Cream Milk 500ml'),
      DoubleCellValue(34.00),
      DoubleCellValue(100),
      TextCellValue('packet'),
      TextCellValue('MLK-002'),
      TextCellValue(''),
      DoubleCellValue(0),
      DoubleCellValue(0),
    ]);
    sheet.appendRow([
      TextCellValue('Ballpoint Blue Pen'),
      DoubleCellValue(10.00),
      DoubleCellValue(200),
      TextCellValue('pcs'),
      TextCellValue('PEN-003'),
      TextCellValue('8909876543210'),
      DoubleCellValue(18),
      DoubleCellValue(0),
    ]);

    final bytes = workbook.save();
    if (bytes == null) throw Exception('Could not generate Products Excel template.');

    await _share(
      Uint8List.fromList(bytes),
      'av-smartbilling-products-template.xlsx',
      'AV Smartbilling Products Template',
      'Use this template to import products into AV Smartbilling. Fields with * are mandatory.',
    );
  }

  Future<void> exportProducts(List<Product> products) async {
    final workbook = Excel.createExcel();
    final sheet = workbook['Products'];
    workbook.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('Product Name'),
      TextCellValue('Price (Rs)'),
      TextCellValue('Stock Quantity'),
      TextCellValue('Selling Unit'),
      TextCellValue('SKU'),
      TextCellValue('Barcode'),
      TextCellValue('GST Rate (%)'),
      TextCellValue('Discount (%)'),
      TextCellValue('Status'),
    ]);

    for (final p in products) {
      sheet.appendRow([
        TextCellValue(p.name),
        DoubleCellValue(p.priceInPaise / 100),
        DoubleCellValue(p.stockQuantity),
        TextCellValue(p.unit),
        TextCellValue(p.sku),
        TextCellValue(p.barcode),
        DoubleCellValue(p.taxRateBasisPoints / 100),
        DoubleCellValue(p.discountPercent),
        TextCellValue(p.active ? 'Active' : 'Inactive'),
      ]);
    }

    final bytes = workbook.save();
    if (bytes == null) throw Exception('Could not export products to Excel.');

    final dateStr = _dateFormat.format(DateTime.now());
    await _share(
      Uint8List.fromList(bytes),
      'av-smartbilling-products-$dateStr.xlsx',
      'AV Smartbilling Products Export',
      'Exported products from AV Smartbilling.',
    );
  }

  // ===========================================================================
  // CUSTOMERS: TEMPLATE & EXPORT
  // ===========================================================================

  Future<void> downloadCustomersTemplate() async {
    final workbook = Excel.createExcel();
    final sheet = workbook['Customers Template'];
    workbook.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('Customer Name *'),
      TextCellValue('Phone Number'),
      TextCellValue('GSTIN'),
      TextCellValue('Address'),
    ]);

    // Sample rows
    sheet.appendRow([
      TextCellValue('Rajesh Kumar'),
      TextCellValue('9876543210'),
      TextCellValue('33AAAAA0000A1Z5'),
      TextCellValue('123 MG Road, Bengaluru'),
    ]);
    sheet.appendRow([
      TextCellValue('Priya Sharma'),
      TextCellValue('9123456780'),
      TextCellValue(''),
      TextCellValue('45 Park Street, Chennai'),
    ]);
    sheet.appendRow([
      TextCellValue('Sai Traders'),
      TextCellValue('8765432109'),
      TextCellValue('27BBBBB1111B2Z6'),
      TextCellValue('Shop 4, Market Complex, Pune'),
    ]);

    final bytes = workbook.save();
    if (bytes == null) throw Exception('Could not generate Customers Excel template.');

    await _share(
      Uint8List.fromList(bytes),
      'av-smartbilling-customers-template.xlsx',
      'AV Smartbilling Customers Template',
      'Use this template to import customers into AV Smartbilling. Customer Name is mandatory.',
    );
  }

  Future<void> exportCustomers(List<Customer> customers) async {
    final workbook = Excel.createExcel();
    final sheet = workbook['Customers'];
    workbook.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('Customer Name'),
      TextCellValue('Phone Number'),
      TextCellValue('GSTIN'),
      TextCellValue('Address'),
    ]);

    for (final c in customers) {
      sheet.appendRow([
        TextCellValue(c.name),
        TextCellValue(c.phone),
        TextCellValue(c.gstin),
        TextCellValue(c.address),
      ]);
    }

    final bytes = workbook.save();
    if (bytes == null) throw Exception('Could not export customers to Excel.');

    final dateStr = _dateFormat.format(DateTime.now());
    await _share(
      Uint8List.fromList(bytes),
      'av-smartbilling-customers-$dateStr.xlsx',
      'AV Smartbilling Customers Export',
      'Exported customers from AV Smartbilling.',
    );
  }

  // ===========================================================================
  // SAMPLE CSV TEMPLATES
  // ===========================================================================

  Future<void> exportSampleProductsCsv() async {
    const csvContent = '''Product Name,Price,Stock,Unit,Item Code / SKU,Barcode,GST Rate (%),Discount (%)
Basmati Rice 1kg,120,50,kg,SKU-RICE-01,8901234567890,5%,0%
Sunflower Oil 1L,145.5,30,L,SKU-OIL-01,,5%,2%
Atta Whole Wheat 5kg,240,40,bag,SKU-ATTA-05,,0%,0%
Toor Dal 1kg,160,25,kg,SKU-DAL-01,,5%,0%
Tea Powder 250g,95,60,pcs,SKU-TEA-250,,12%,5%''';

    await _share(
      Uint8List.fromList(utf8.encode('\uFEFF$csvContent')),
      'av-smartbilling-products-template.csv',
      'AV Smartbilling Products CSV Template',
      'Template CSV file for importing products into AV Smartbilling.',
    );
  }

  Future<void> exportSampleCustomersCsv() async {
    const csvContent = '''Customer Name,Phone Number,GSTIN,Address
Ramesh Kumar,9876543210,33AAAAA0000A1Z5,"Shop #4, Main Bazaar, City"
Priya Sharma,9123456780,,"12 Green Avenue, Gandhi Nagar"
Super Bazaar Wholesalers,9811223344,29BBBBB1111B2Z6,"Plot 45, Industrial Area Phase 2"''';

    await _share(
      Uint8List.fromList(utf8.encode('\uFEFF$csvContent')),
      'av-smartbilling-customers-template.csv',
      'AV Smartbilling Customers CSV Template',
      'Template CSV file for importing customers into AV Smartbilling.',
    );
  }

  // ===========================================================================
  // PRODUCTS: IMPORT WITH DUPLICATE REPLACEMENT (XLSX & CSV SUPPORT)
  // ===========================================================================

  Future<ImportResult> importProducts(
    Uint8List bytes,
    AppController controller, {
    String? fileName,
  }) async {
    final rows = _decodeTableRows(bytes, fileName: fileName, targetType: 'product');
    if (rows.isEmpty) {
      throw Exception('The spreadsheet contains no rows.');
    }

    // Find header row
    int headerRowIndex = -1;
    final headerMap = <String, int>{};

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final colNames = row.map((s) => s.toLowerCase().trim()).toList();

      if (colNames.any((c) => c.contains('product') || c.contains('name') || c.contains('item'))) {
        headerRowIndex = r;
        for (var c = 0; c < colNames.length; c++) {
          final col = colNames[c];
          if (col.isEmpty) continue;
          if (col.contains('name') || col == 'product' || col == 'item' || col.contains('title')) {
            headerMap['name'] ??= c;
          } else if (col.contains('price') || col.contains('rate') || col.contains('mrp')) {
            headerMap['price'] ??= c;
          } else if (col.contains('stock') || col.contains('qty') || col.contains('quantity')) {
            headerMap['stock'] ??= c;
          } else if (col.contains('unit') || col == 'uom') {
            headerMap['unit'] ??= c;
          } else if (col.contains('sku') || col == 'code' || col.contains('item code')) {
            headerMap['sku'] ??= c;
          } else if (col.contains('barcode') || col.contains('bar code') || col == 'upc' || col == 'ean') {
            headerMap['barcode'] ??= c;
          } else if (col.contains('gst') || col.contains('tax')) {
            headerMap['tax'] ??= c;
          } else if (col.contains('discount') || col.contains('disc')) {
            headerMap['discount'] ??= c;
          }
        }
        break;
      }
    }

    if (headerRowIndex == -1 || !headerMap.containsKey('name')) {
      throw Exception(
        'Could not find valid column headers in the file. Please ensure column headers include "Product Name", "Price", "Stock", and "Unit".',
      );
    }

    final existingProducts = await controller.products();
    int addedCount = 0;
    int updatedCount = 0;
    final errors = <String>[];
    int processedDataRows = 0;

    for (var r = headerRowIndex + 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.every((cell) => cell.trim().isEmpty)) continue;

      processedDataRows++;
      final rowNum = r + 1;

      try {
        final name = _strAt(row, headerMap['name']);
        if (name.length < 2) {
          errors.add('Row $rowNum: Product name is required (min 2 characters).');
          continue;
        }

        final priceVal = _doubleAt(row, headerMap['price']);
        if (priceVal == null || priceVal < 0) {
          errors.add('Row $rowNum ("$name"): Valid price is required (0 or greater).');
          continue;
        }

        final rawStock = _doubleAt(row, headerMap['stock']);
        final stockVal = rawStock ?? 0.0;
        if (stockVal < 0) {
          errors.add('Row $rowNum ("$name"): Valid stock quantity is required (0 or greater).');
          continue;
        }

        final rawUnit = _strAt(row, headerMap['unit']);
        final cleanUnit = readableUnit(rawUnit.isEmpty ? 'pcs' : rawUnit, quantity: 1);

        final rawSku = _strAt(row, headerMap['sku']);
        final rawBarcode = _strAt(row, headerMap['barcode']);
        final taxRateVal = _doubleAt(row, headerMap['tax']) ?? 0.0;
        final discountVal = _doubleAt(row, headerMap['discount']) ?? 0.0;

        if (taxRateVal < 0 || taxRateVal > 100) {
          errors.add('Row $rowNum ("$name"): GST Rate must be between 0% and 100%.');
          continue;
        }
        if (discountVal < 0 || discountVal > 100) {
          errors.add('Row $rowNum ("$name"): Discount must be between 0% and 100%.');
          continue;
        }

        Product? existing;
        if (rawSku.isNotEmpty) {
          existing = existingProducts.where((p) => p.sku.toLowerCase() == rawSku.toLowerCase()).firstOrNull;
        }
        if (existing == null && rawBarcode.isNotEmpty) {
          existing = existingProducts.where((p) => p.barcode.isNotEmpty && p.barcode == rawBarcode).firstOrNull;
        }
        existing ??= existingProducts.where((p) => p.name.trim().toLowerCase() == name.toLowerCase()).firstOrNull;

        if (existing != null) {
          await controller.saveProduct(
            id: existing.id,
            name: name,
            sku: rawSku.isNotEmpty ? rawSku.toUpperCase() : existing.sku,
            barcode: rawBarcode.isNotEmpty ? rawBarcode : existing.barcode,
            unit: cleanUnit,
            price: priceVal,
            taxRate: taxRateVal,
            discountPercent: discountVal,
            stock: stockVal,
          );
          updatedCount++;
        } else {
          final finalSku = rawSku.isNotEmpty
              ? rawSku.toUpperCase()
              : 'AV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}-${addedCount + 1}';
          await controller.saveProduct(
            id: null,
            name: name,
            sku: finalSku,
            barcode: rawBarcode,
            unit: cleanUnit,
            price: priceVal,
            taxRate: taxRateVal,
            discountPercent: discountVal,
            stock: stockVal,
          );
          addedCount++;
        }
      } catch (e) {
        errors.add('Row $rowNum: ${errorMessage(e)}');
      }
    }

    await controller.checkLowStock();

    return ImportResult(
      totalRows: processedDataRows,
      addedCount: addedCount,
      updatedCount: updatedCount,
      errors: errors,
    );
  }

  // ===========================================================================
  // CUSTOMERS: IMPORT WITH DUPLICATE REPLACEMENT (XLSX & CSV SUPPORT)
  // ===========================================================================

  Future<ImportResult> importCustomers(
    Uint8List bytes,
    AppController controller, {
    String? fileName,
  }) async {
    final rows = _decodeTableRows(bytes, fileName: fileName, targetType: 'customer');
    if (rows.isEmpty) {
      throw Exception('The spreadsheet contains no rows.');
    }

    int headerRowIndex = -1;
    final headerMap = <String, int>{};

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final colNames = row.map((s) => s.toLowerCase().trim()).toList();

      if (colNames.any((c) => c.contains('customer') || c.contains('name') || c.contains('client'))) {
        headerRowIndex = r;
        for (var c = 0; c < colNames.length; c++) {
          final col = colNames[c];
          if (col.isEmpty) continue;
          if (col.contains('name') || col == 'customer' || col == 'client') {
            headerMap['name'] ??= c;
          } else if (col.contains('phone') || col.contains('mobile') || col.contains('contact')) {
            headerMap['phone'] ??= c;
          } else if (col.contains('gstin') || col == 'gst' || col.contains('tax number')) {
            headerMap['gstin'] ??= c;
          } else if (col.contains('address') || col.contains('city') || col.contains('location')) {
            headerMap['address'] ??= c;
          }
        }
        break;
      }
    }

    if (headerRowIndex == -1 || !headerMap.containsKey('name')) {
      throw Exception(
        'Could not find valid column headers in the file. Please ensure column headers include "Customer Name", "Phone", "GSTIN", and "Address".',
      );
    }

    final existingCustomers = await controller.customers();
    int addedCount = 0;
    int updatedCount = 0;
    final errors = <String>[];
    int processedDataRows = 0;

    for (var r = headerRowIndex + 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.every((cell) => cell.trim().isEmpty)) continue;

      processedDataRows++;
      final rowNum = r + 1;

      try {
        final name = _strAt(row, headerMap['name']);
        if (name.length < 2) {
          errors.add('Row $rowNum: Customer name is required (min 2 characters).');
          continue;
        }

        final rawPhone = _strAt(row, headerMap['phone']);
        final phoneError = validateOptionalMobileNumber(rawPhone);
        if (phoneError != null) {
          errors.add('Row $rowNum ("$name"): $phoneError');
          continue;
        }

        final rawGstin = _strAt(row, headerMap['gstin']).toUpperCase();
        final rawAddress = _strAt(row, headerMap['address']);

        Customer? existing;
        if (rawPhone.isNotEmpty) {
          existing = existingCustomers.where((c) => c.phone.isNotEmpty && c.phone == rawPhone).firstOrNull;
        }
        existing ??= existingCustomers.where((c) => c.name.trim().toLowerCase() == name.toLowerCase()).firstOrNull;

        if (existing != null) {
          await controller.saveCustomer(
            id: existing.id,
            name: name,
            phone: rawPhone.isNotEmpty ? rawPhone : existing.phone,
            address: rawAddress.isNotEmpty ? rawAddress : existing.address,
            gstin: rawGstin.isNotEmpty ? rawGstin : existing.gstin,
          );
          updatedCount++;
        } else {
          await controller.saveCustomer(
            id: null,
            name: name,
            phone: rawPhone,
            address: rawAddress,
            gstin: rawGstin,
          );
          addedCount++;
        }
      } catch (e) {
        errors.add('Row $rowNum: ${errorMessage(e)}');
      }
    }

    return ImportResult(
      totalRows: processedDataRows,
      addedCount: addedCount,
      updatedCount: updatedCount,
      errors: errors,
    );
  }

  // ===========================================================================
  // TABLE DECODING (STANDARD EXCEL + RAW XML FALLBACK + CSV)
  // ===========================================================================

  List<List<String>> _decodeTableRows(
    Uint8List bytes, {
    String? fileName,
    String? targetType,
  }) {
    if (bytes.isEmpty) {
      throw Exception('The selected file is empty.');
    }

    final isZip = bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
    final isCsvNamed = fileName != null &&
        (fileName.toLowerCase().endsWith('.csv') ||
            fileName.toLowerCase().endsWith('.txt') ||
            fileName.toLowerCase().endsWith('.tsv'));

    if (!isZip || isCsvNamed) {
      try {
        final rows = _parseCsv(bytes);
        if (rows.isNotEmpty) return rows;
      } catch (_) {
        if (isCsvNamed) rethrow;
      }
    }

    if (isZip) {
      // 1. Try standard Excel decoder
      try {
        final excel = Excel.decodeBytes(bytes);
        if (excel.tables.isNotEmpty) {
          Sheet? sheet;
          final target = targetType?.toLowerCase();
          if (target != null) {
            for (final entry in excel.tables.entries) {
              final name = entry.key.toLowerCase();
              if (name.contains(target) && entry.value.rows.isNotEmpty) {
                sheet = entry.value;
                break;
              }
            }
          }
          sheet ??= excel.tables.values.where((s) => s.rows.isNotEmpty).firstOrNull;
          if (sheet != null && sheet.rows.isNotEmpty) {
            final rows = <List<String>>[];
            for (final r in sheet.rows) {
              rows.add(r.map(_cellString).toList());
            }
            if (rows.isNotEmpty) return rows;
          }
        }
      } catch (_) {
        // Standard Excel library failed (e.g. Null check operator on styles).
        // Fall back to robust raw XML parser below.
      }

      // 2. Fall back to robust raw XML archive parser
      try {
        final rows = _decodeXlsxArchive(bytes);
        if (rows.isNotEmpty) return rows;
      } catch (_) {
        // Fall through to CSV attempt
      }
    }

    // 3. Fall back to CSV decoding
    try {
      final rows = _parseCsv(bytes);
      if (rows.isNotEmpty) return rows;
    } catch (_) {}

    throw Exception(
      'Could not read this spreadsheet file. Please ensure it is a valid .xlsx or .csv file.',
    );
  }

  int _colIndexFromRef(String ref) {
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

  List<List<String>> _decodeXlsxArchive(Uint8List bytes) {
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

    final sheetFiles = archive.files
        .where((f) => f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml'))
        .toList();
    if (sheetFiles.isEmpty) {
      throw Exception('The selected Excel file contains no worksheets.');
    }

    sheetFiles.sort((a, b) => a.name.compareTo(b.name));
    final sheetFile = sheetFiles.first;

    final sheetRaw = sheetFile.content as List<int>;
    final sheetContent = utf8.decode(sheetRaw, allowMalformed: true);
    final sheetDoc = XmlDocument.parse(sheetContent);
    final rows = <List<String>>[];

    for (final rowElem in sheetDoc.findAllElements('row')) {
      final rowList = <String>[];
      for (final cellElem in rowElem.findElements('c')) {
        final cellRef = cellElem.getAttribute('r') ?? '';
        final colIdx = _colIndexFromRef(cellRef);
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
      if (rowList.any((c) => c.trim().isNotEmpty)) {
        rows.add(rowList);
      }
    }
    return rows;
  }

  List<List<String>> _parseCsv(Uint8List bytes) {
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      try {
        text = latin1.decode(bytes);
      } catch (_) {
        throw Exception('Could not decode CSV text content.');
      }
    }

    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }

    String delimiter = ',';
    final firstLine = text.split(RegExp(r'\r\n|\r|\n')).firstOrNull ?? '';
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
          if (currentRow.any((c) => c.isNotEmpty)) {
            rows.add(List<String>.from(currentRow));
          }
          currentRow.clear();
          i++;
          continue;
        } else if (char == '\n') {
          currentRow.add(currentField.toString().trim());
          currentField.clear();
          if (currentRow.any((c) => c.isNotEmpty)) {
            rows.add(List<String>.from(currentRow));
          }
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
      if (currentRow.any((c) => c.isNotEmpty)) {
        rows.add(List<String>.from(currentRow));
      }
    }

    return rows;
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  String _strAt(List<String> row, int? colIndex) {
    if (colIndex == null || colIndex < 0 || colIndex >= row.length) return '';
    return row[colIndex].trim();
  }

  double? _doubleAt(List<String> row, int? colIndex) {
    if (colIndex == null || colIndex < 0 || colIndex >= row.length) return null;
    final s = row[colIndex]
        .replaceAll(',', '')
        .replaceAll('Rs.', '')
        .replaceAll('Rs', '')
        .replaceAll('₹', '')
        .replaceAll('%', '')
        .replaceAll('/', '')
        .trim();
    return double.tryParse(s);
  }

  String _cellString(Data? cell) {
    if (cell == null) return '';
    try {
      final v = cell.value;
      if (v == null) return '';
      if (v is TextCellValue) {
        return v.value.text?.trim() ?? v.value.toString().trim();
      }
      if (v is IntCellValue) return v.value.toString();
      if (v is DoubleCellValue) {
        if (v.value == v.value.roundToDouble()) {
          return v.value.toInt().toString();
        }
        return v.value.toString();
      }
      if (v is DateCellValue) {
        try {
          return v.asDateTimeLocal().toIso8601String();
        } catch (_) {
          return v.toString().trim();
        }
      }
      if (v is DateTimeCellValue) {
        try {
          return v.asDateTimeLocal().toIso8601String();
        } catch (_) {
          return v.toString().trim();
        }
      }
      if (v is BoolCellValue) return v.value ? 'true' : 'false';
      if (v is FormulaCellValue) return v.formula.trim();
      return v.toString().trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> _share(Uint8List bytes, String fileName, String title, String text) async {
    if (shareHandler != null) {
      await shareHandler!(bytes, fileName, title, text);
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        title: title,
        text: text,
        files: [
          XFile.fromData(
            bytes,
            mimeType: fileName.endsWith('.csv')
                ? 'text/csv'
                : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        fileNameOverrides: [fileName],
      ),
    );
  }
}
