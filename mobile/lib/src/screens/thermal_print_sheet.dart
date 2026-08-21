import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../models.dart';
import '../thermal_printer_service.dart';
import '../ui_helpers.dart';

class ThermalReceiptPreviewSheet extends StatefulWidget {
  const ThermalReceiptPreviewSheet({super.key, required this.invoice});

  final InvoiceDetail invoice;

  @override
  State<ThermalReceiptPreviewSheet> createState() =>
      _ThermalReceiptPreviewSheetState();
}

class _ThermalReceiptPreviewSheetState
    extends State<ThermalReceiptPreviewSheet> {
  int paperWidth = 80;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Thermal Receipt Preview',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 58, label: Text('58 mm')),
              ButtonSegment(value: 80, label: Text('80 mm')),
            ],
            selected: {paperWidth},
            onSelectionChanged: (value) =>
                setState(() => paperWidth = value.first),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Center(
                child: _ThermalReceiptPaper(
                  detail: widget.invoice,
                  paperWidth: paperWidth,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ThermalReceiptPaper extends StatelessWidget {
  const _ThermalReceiptPaper({required this.detail, required this.paperWidth});

  final InvoiceDetail detail;
  final int paperWidth;

  @override
  Widget build(BuildContext context) {
    final business = detail.business;
    final invoice = detail.invoice;
    final narrow = paperWidth == 58;
    return Container(
      width: narrow ? 280 : 360,
      padding: EdgeInsets.all(narrow ? 14 : 20),
      color: Colors.white,
      child: DefaultTextStyle(
        style: TextStyle(
          color: Colors.black87,
          fontFamily: 'monospace',
          fontSize: narrow ? 11 : 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              business['company_name'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if ((business['address'] as String).isNotEmpty)
              Text(business['address'] as String, textAlign: TextAlign.center),
            if ((business['phone'] as String).isNotEmpty)
              Text('Phone: ${business['phone']}', textAlign: TextAlign.center),
            if ((business['gstin'] as String).isNotEmpty)
              Text('GSTIN: ${business['gstin']}', textAlign: TextAlign.center),
            const Divider(),
            const Text(
              'TAX INVOICE',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('No: ${invoice['invoice_number']}'),
            Text('Customer: ${invoice['customer_name']}'),
            if ((invoice['customer_phone'] as String).isNotEmpty)
              Text('Mobile: ${invoice['customer_phone']}'),
            const Divider(),
            ...detail.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item['description'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${formatQuantity(item['quantity'] as num)} × ${money(item['unit_price_in_paise'] as int)}',
                        ),
                        Text(
                          money(
                            (item['taxable_in_paise'] as int) +
                                (item['tax_in_paise'] as int),
                          ),
                        ),
                      ],
                    ),
                    if ((item['discount_in_paise'] as int) > 0)
                      Text(
                        'Discount: ${money(item['discount_in_paise'] as int)}',
                      ),
                  ],
                ),
              ),
            ),
            const Divider(),
            _PreviewAmount(
              label: 'Subtotal',
              value: invoice['subtotal_in_paise'] as int,
            ),
            if (((invoice['line_discount_in_paise'] as int?) ?? 0) > 0)
              _PreviewAmount(
                label: 'Product discounts',
                value: -(invoice['line_discount_in_paise'] as int),
              ),
            if (((invoice['overall_discount_in_paise'] as int?) ?? 0) > 0)
              _PreviewAmount(
                label: 'Overall discount',
                value: -(invoice['overall_discount_in_paise'] as int),
              ),
            _PreviewAmount(label: 'GST', value: invoice['tax_in_paise'] as int),
            _PreviewAmount(
              label: 'TOTAL',
              value: invoice['total_in_paise'] as int,
              strong: true,
            ),
            Text('Payment: ${invoice['payment_method']}'),
            const Divider(),
            Text(
              (business['invoice_footer'] as String).isEmpty
                  ? 'Thank you for your business.'
                  : business['invoice_footer'] as String,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewAmount extends StatelessWidget {
  const _PreviewAmount({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final int value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: strong ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      Text(
        value < 0 ? '-${money(-value)}' : money(value),
        style: strong ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
    ],
  );
}

class ThermalPrintSheet extends StatefulWidget {
  const ThermalPrintSheet({super.key, required this.invoice});

  final InvoiceDetail invoice;

  @override
  State<ThermalPrintSheet> createState() => _ThermalPrintSheetState();
}

class _ThermalPrintSheetState extends State<ThermalPrintSheet> {
  final service = ThermalPrinterService();
  List<BluetoothInfo> printers = [];
  String? selectedMac;
  int paperWidth = 80;
  bool loading = true;
  bool printing = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final saved = await service.readSettings();
      final available = await service.pairedPrinters();
      if (!mounted) return;
      setState(() {
        printers = available;
        selectedMac =
            available.any((printer) => printer.macAdress == saved?.macAddress)
            ? saved!.macAddress
            : available.firstOrNull?.macAdress;
        paperWidth = saved?.paperWidth ?? 80;
        loading = false;
      });
    } catch (value) {
      if (!mounted) return;
      setState(() {
        error = errorMessage(value);
        loading = false;
      });
    }
  }

  Future<void> _print() async {
    final printer = printers
        .where((item) => item.macAdress == selectedMac)
        .firstOrNull;
    if (printer == null) return;
    setState(() => printing = true);
    try {
      final settings = ThermalPrinterSettings(
        macAddress: printer.macAdress,
        name: printer.name,
        paperWidth: paperWidth,
      );
      await service.saveSettings(settings);
      await service.printInvoice(widget.invoice, settings);
      if (!mounted) return;
      showMessage(context, 'Thermal receipt sent to ${printer.name}.');
      Navigator.pop(context);
    } catch (value) {
      if (mounted) showMessage(context, errorMessage(value), error: true);
    } finally {
      if (mounted) setState(() => printing = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bluetooth Thermal Print',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pair the printer in Android Bluetooth settings before selecting it here.',
          ),
          const SizedBox(height: 18),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            Card(
              color: Colors.orange.shade50,
              child: ListTile(
                leading: const Icon(Icons.bluetooth_disabled),
                title: Text(error!),
                trailing: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            )
          else if (printers.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.print_disabled_outlined),
                title: Text('No paired Bluetooth printers found'),
                subtitle: Text(
                  'Open Android settings, pair your thermal printer, then refresh.',
                ),
              ),
            )
          else ...[
            DropdownButtonFormField<String>(
              initialValue: selectedMac,
              decoration: const InputDecoration(
                labelText: 'Paired printer',
                prefixIcon: Icon(Icons.bluetooth),
              ),
              items: printers
                  .map(
                    (printer) => DropdownMenuItem(
                      value: printer.macAdress,
                      child: Text(printer.name),
                    ),
                  )
                  .toList(),
              onChanged: printing
                  ? null
                  : (value) => setState(() => selectedMac = value),
            ),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 58, label: Text('58 mm')),
                ButtonSegment(value: 80, label: Text('80 mm')),
              ],
              selected: {paperWidth},
              onSelectionChanged: printing
                  ? null
                  : (value) => setState(() => paperWidth = value.first),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: printing ? null : _print,
              icon: printing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print),
              label: Text(printing ? 'Printing…' : 'Print thermal receipt'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
