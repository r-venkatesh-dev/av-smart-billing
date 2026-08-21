import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'models.dart';

class ThermalPrinterSettings {
  const ThermalPrinterSettings({
    required this.macAddress,
    required this.name,
    required this.paperWidth,
  });

  final String macAddress;
  final String name;
  final int paperWidth;
}

class ThermalPrinterService {
  static const _storage = FlutterSecureStorage();
  static const _macKey = 'avsb_thermal_printer_mac_v1';
  static const _nameKey = 'avsb_thermal_printer_name_v1';
  static const _widthKey = 'avsb_thermal_paper_width_v1';

  Future<List<BluetoothInfo>> pairedPrinters() async {
    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      final statuses = await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ].request();
      if (statuses.values.any((status) => !status.isGranted)) {
        throw Exception(
          'Bluetooth permission is required to find paired thermal printers.',
        );
      }
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw Exception('Turn on Bluetooth and try again.');
    }
    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<ThermalPrinterSettings?> readSettings() async {
    final mac = await _storage.read(key: _macKey);
    if (mac == null || mac.isEmpty) return null;
    return ThermalPrinterSettings(
      macAddress: mac,
      name: await _storage.read(key: _nameKey) ?? 'Thermal printer',
      paperWidth: int.tryParse(await _storage.read(key: _widthKey) ?? '') ?? 80,
    );
  }

  Future<void> saveSettings(ThermalPrinterSettings settings) async {
    await Future.wait([
      _storage.write(key: _macKey, value: settings.macAddress),
      _storage.write(key: _nameKey, value: settings.name),
      _storage.write(key: _widthKey, value: '${settings.paperWidth}'),
    ]);
  }

  Future<void> printInvoice(
    InvoiceDetail detail,
    ThermalPrinterSettings settings,
  ) async {
    if (await PrintBluetoothThermal.connectionStatus) {
      await PrintBluetoothThermal.disconnect;
    }
    final connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: settings.macAddress,
    );
    if (!connected) {
      throw Exception(
        'Could not connect to ${settings.name}. Check that the printer is on and nearby.',
      );
    }
    final printed = await PrintBluetoothThermal.writeBytes(
      _ticket(detail, settings.paperWidth),
    );
    if (!printed) throw Exception('The printer did not accept the receipt.');
  }

  List<int> _ticket(InvoiceDetail detail, int paperWidth) {
    final width = paperWidth == 58 ? 32 : 48;
    final invoice = detail.invoice;
    final business = detail.business;
    final bytes = <int>[27, 64, 27, 97, 1, 27, 69, 1];
    _line(bytes, business['company_name'] as String);
    bytes.addAll([27, 69, 0]);
    if ((business['address'] as String).isNotEmpty) {
      _wrapped(bytes, business['address'] as String, width);
    }
    if ((business['phone'] as String).isNotEmpty) {
      _line(bytes, business['phone'] as String);
    }
    if ((business['gstin'] as String).isNotEmpty) {
      _line(bytes, 'GSTIN: ${business['gstin']}');
    }
    _line(bytes, _repeat('-', width));
    bytes.addAll([27, 69, 1]);
    _line(bytes, 'TAX INVOICE');
    bytes.addAll([27, 69, 0, 27, 97, 0]);
    _line(bytes, 'No: ${invoice['invoice_number']}');
    _line(
      bytes,
      'Date: ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.parse(invoice['issued_at'] as String).toLocal())}',
    );
    _line(bytes, 'Customer: ${invoice['customer_name']}');
    _line(bytes, _repeat('-', width));
    for (final item in detail.items) {
      _wrapped(bytes, item['description'] as String, width);
      final quantity = _quantity(item['quantity']);
      final rate = _money(item['unit_price_in_paise']);
      final amount = _money(
        (item['taxable_in_paise'] as int) + (item['tax_in_paise'] as int),
      );
      _line(bytes, _columns('$quantity x $rate', amount, width));
      if ((item['discount_in_paise'] as int) > 0) {
        _line(bytes, 'Discount: -${_money(item['discount_in_paise'])}');
      }
      _line(
        bytes,
        'GST ${_quantity((item['tax_rate_basis_points'] as int) / 100)}% included',
      );
    }
    _line(bytes, _repeat('-', width));
    _line(
      bytes,
      _columns('Subtotal', _money(invoice['subtotal_in_paise']), width),
    );
    if (((invoice['line_discount_in_paise'] as int?) ?? 0) > 0) {
      _line(
        bytes,
        _columns(
          'Item discount',
          '-${_money(invoice['line_discount_in_paise'])}',
          width,
        ),
      );
    }
    if (((invoice['overall_discount_in_paise'] as int?) ?? 0) > 0) {
      _line(
        bytes,
        _columns(
          'Bill discount',
          '-${_money(invoice['overall_discount_in_paise'])}',
          width,
        ),
      );
    }
    _line(bytes, _columns('GST', _money(invoice['tax_in_paise']), width));
    bytes.addAll([27, 69, 1]);
    _line(bytes, _columns('TOTAL', _money(invoice['total_in_paise']), width));
    bytes.addAll([27, 69, 0]);
    _line(bytes, _columns('Payment', '${invoice['payment_method']}', width));
    _line(bytes, _columns('Status', '${invoice['status']}', width));
    _line(bytes, _repeat('-', width));
    bytes.addAll([27, 97, 1]);
    _wrapped(
      bytes,
      (business['invoice_footer'] as String).isEmpty
          ? 'Thank you for your business.'
          : business['invoice_footer'] as String,
      width,
    );
    bytes.addAll([10, 10, 10, 29, 86, 0]);
    return bytes;
  }

  void _line(List<int> bytes, String text) {
    bytes.addAll(ascii.encode('${_ascii(text)}\n'));
  }

  void _wrapped(List<int> bytes, String text, int width) {
    final words = _ascii(text).split(RegExp(r'\s+'));
    var line = '';
    for (final word in words) {
      if (line.isNotEmpty && line.length + word.length + 1 > width) {
        _line(bytes, line);
        line = word;
      } else {
        line = line.isEmpty ? word : '$line $word';
      }
    }
    if (line.isNotEmpty) _line(bytes, line);
  }

  String _columns(String left, String right, int width) {
    final cleanLeft = _ascii(left);
    final cleanRight = _ascii(right);
    final available = (width - cleanRight.length - 1).clamp(1, width);
    final clippedLeft = cleanLeft.substring(
      0,
      cleanLeft.length.clamp(0, available),
    );
    final spaces = (width - clippedLeft.length - cleanRight.length).clamp(
      1,
      width,
    );
    return '$clippedLeft${_repeat(' ', spaces)}$cleanRight';
  }

  String _repeat(String character, int count) =>
      List<String>.filled(count, character).join();

  String _money(Object? paise) =>
      'Rs ${(((paise as num?)?.toInt() ?? 0) / 100).toStringAsFixed(2)}';

  String _ascii(String value) => value
      .replaceAll('₹', 'Rs ')
      .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ')
      .trim();

  String _quantity(Object? value) {
    final number = (value as num?)?.toDouble() ?? 0;
    if (number == number.roundToDouble()) return '${number.toInt()}';
    return number.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }
}
