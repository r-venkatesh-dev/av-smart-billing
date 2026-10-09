import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

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
  // PRODUCTS: IMPORT WITH DUPLICATE REPLACEMENT
  // ===========================================================================

  Future<ImportResult> importProducts(Uint8List bytes, AppController controller) async {
    final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw Exception(
        'Could not read this Excel file. Please ensure it is a valid .xlsx file or try opening and re-saving it before importing.',
      );
    }

    if (excel.tables.isEmpty) {
      throw Exception('The selected Excel file contains no worksheets.');
    }

    Sheet? sheet;
    for (final entry in excel.tables.entries) {
      final name = entry.key.toLowerCase();
      if ((name.contains('product') || name.contains('item')) && entry.value.rows.isNotEmpty) {
        sheet = entry.value;
        break;
      }
    }
    sheet ??= excel.tables.values.where((s) => s.rows.isNotEmpty).firstOrNull;

    if (sheet == null || sheet.rows.isEmpty) {
      throw Exception('The Excel sheet contains no rows.');
    }

    // Find header row
    int headerRowIndex = -1;
    final headerMap = <String, int>{};

    for (var r = 0; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      final colNames = row.map(_cellString).map((s) => s.toLowerCase().trim()).toList();

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
        'Could not find valid column headers in the Excel file. Please use the downloadable template.',
      );
    }

    final existingProducts = await controller.products();
    int addedCount = 0;
    int updatedCount = 0;
    final errors = <String>[];
    int processedDataRows = 0;

    for (var r = headerRowIndex + 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      if (row.every((cell) => _cellString(cell).isEmpty)) continue;

      processedDataRows++;
      final rowNum = r + 1;

      try {
        final name = _cellString(_cellAt(row, headerMap['name']));
        if (name.length < 2) {
          errors.add('Row $rowNum: Product name is required (min 2 characters).');
          continue;
        }

        final priceVal = _cellDouble(_cellAt(row, headerMap['price']));
        if (priceVal == null || priceVal < 0) {
          errors.add('Row $rowNum ("$name"): Valid price is required (0 or greater).');
          continue;
        }

        final rawStock = _cellDouble(_cellAt(row, headerMap['stock']));
        final stockVal = rawStock ?? 0.0;
        if (stockVal < 0) {
          errors.add('Row $rowNum ("$name"): Valid stock quantity is required (0 or greater).');
          continue;
        }

        final rawUnit = _cellString(_cellAt(row, headerMap['unit']));
        final cleanUnit = readableUnit(rawUnit.isEmpty ? 'pcs' : rawUnit, quantity: 1);

        final rawSku = _cellString(_cellAt(row, headerMap['sku']));
        final rawBarcode = _cellString(_cellAt(row, headerMap['barcode']));
        final taxRateVal = _cellDouble(_cellAt(row, headerMap['tax'])) ?? 0.0;
        final discountVal = _cellDouble(_cellAt(row, headerMap['discount'])) ?? 0.0;

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
  // CUSTOMERS: IMPORT WITH DUPLICATE REPLACEMENT
  // ===========================================================================

  Future<ImportResult> importCustomers(Uint8List bytes, AppController controller) async {
    final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw Exception(
        'Could not read this Excel file. Please ensure it is a valid .xlsx file or try opening and re-saving it before importing.',
      );
    }

    if (excel.tables.isEmpty) {
      throw Exception('The selected Excel file contains no worksheets.');
    }

    Sheet? sheet;
    for (final entry in excel.tables.entries) {
      final name = entry.key.toLowerCase();
      if ((name.contains('customer') || name.contains('client')) && entry.value.rows.isNotEmpty) {
        sheet = entry.value;
        break;
      }
    }
    sheet ??= excel.tables.values.where((s) => s.rows.isNotEmpty).firstOrNull;

    if (sheet == null || sheet.rows.isEmpty) {
      throw Exception('The Excel sheet contains no rows.');
    }

    int headerRowIndex = -1;
    final headerMap = <String, int>{};

    for (var r = 0; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      final colNames = row.map(_cellString).map((s) => s.toLowerCase().trim()).toList();

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
        'Could not find valid column headers in the Excel file. Please use the downloadable template.',
      );
    }

    final existingCustomers = await controller.customers();
    int addedCount = 0;
    int updatedCount = 0;
    final errors = <String>[];
    int processedDataRows = 0;

    for (var r = headerRowIndex + 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      if (row.every((cell) => _cellString(cell).isEmpty)) continue;

      processedDataRows++;
      final rowNum = r + 1;

      try {
        final name = _cellString(_cellAt(row, headerMap['name']));
        if (name.length < 2) {
          errors.add('Row $rowNum: Customer name is required (min 2 characters).');
          continue;
        }

        final rawPhone = _cellString(_cellAt(row, headerMap['phone']));
        final phoneError = validateOptionalMobileNumber(rawPhone);
        if (phoneError != null) {
          errors.add('Row $rowNum ("$name"): $phoneError');
          continue;
        }

        final rawGstin = _cellString(_cellAt(row, headerMap['gstin'])).toUpperCase();
        final rawAddress = _cellString(_cellAt(row, headerMap['address']));

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
  // HELPERS
  // ===========================================================================

  Data? _cellAt(List<Data?> row, int? colIndex) {
    if (colIndex == null || colIndex < 0 || colIndex >= row.length) return null;
    return row[colIndex];
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

  double? _cellDouble(Data? cell) {
    if (cell == null) return null;
    try {
      final v = cell.value;
      if (v == null) return null;
      if (v is DoubleCellValue) return v.value;
      if (v is IntCellValue) return v.value.toDouble();
      final s = _cellString(cell)
          .replaceAll(',', '')
          .replaceAll('Rs.', '')
          .replaceAll('Rs', '')
          .replaceAll('₹', '')
          .replaceAll('%', '')
          .replaceAll('/', '')
          .trim();
      return double.tryParse(s);
    } catch (_) {
      return null;
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
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        fileNameOverrides: [fileName],
      ),
    );
  }
}
