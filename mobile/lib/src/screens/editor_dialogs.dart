import 'package:flutter/material.dart';

import '../billing_math.dart';
import '../models.dart';
import '../ui_helpers.dart';
import 'barcode_scanner_screen.dart';

typedef ProductSaver =
    Future<void> Function({
      String? id,
      required String name,
      required String sku,
      required String barcode,
      required String unit,
      required double price,
      required double taxRate,
      required double stock,
    });

class ProductEditorDialog extends StatefulWidget {
  const ProductEditorDialog({super.key, this.product, required this.onSave});
  final Product? product;
  final ProductSaver onSave;

  @override
  State<ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<ProductEditorDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController sku;
  late final TextEditingController barcode;
  late final TextEditingController unit;
  late final TextEditingController price;
  late final TextEditingController tax;
  late final TextEditingController stock;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    name = TextEditingController(text: product?.name);
    sku = TextEditingController(
      text:
          product?.sku ??
          'AV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    barcode = TextEditingController(text: product?.barcode);
    unit = TextEditingController(text: product?.unit ?? 'pcs');
    price = TextEditingController(
      text: product == null
          ? ''
          : (product.priceInPaise / 100).toStringAsFixed(2),
    );
    tax = TextEditingController(
      text: product == null
          ? '0'
          : (product.taxRateBasisPoints / 100).toString(),
    );
    stock = TextEditingController(
      text: product?.stockQuantity.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    for (final controller in [name, sku, barcode, unit, price, tax, stock]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _number(String? value) =>
      double.tryParse(value ?? '') == null ? 'Enter a number' : null;

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await widget.onSave(
        id: widget.product?.id,
        name: name.text,
        sku: sku.text,
        barcode: barcode.text,
        unit: unit.text,
        price: double.parse(price.text),
        taxRate: double.parse(tax.text),
        stock: double.parse(stock.text),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showMessage(context, errorMessage(error), error: true);
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.product == null ? 'Add product' : 'Edit product'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Product name'),
                validator: (value) =>
                    (value ?? '').trim().length < 2 ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: sku,
                decoration: const InputDecoration(labelText: 'SKU'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: barcode,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Barcode (optional)',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      final value = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BarcodeScannerScreen(),
                        ),
                      );
                      if (mounted && value != null) barcode.text = value;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Selling price ₹',
                      ),
                      validator: _number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: tax,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'GST %'),
                      validator: _number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: stock,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Current stock',
                      ),
                      validator: _number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
}

typedef CustomerSaver =
    Future<void> Function({
      String? id,
      required String name,
      required String phone,
      required String address,
      required String gstin,
    });

class CustomerEditorDialog extends StatefulWidget {
  const CustomerEditorDialog({super.key, this.customer, required this.onSave});
  final Customer? customer;
  final CustomerSaver onSave;

  @override
  State<CustomerEditorDialog> createState() => _CustomerEditorDialogState();
}

class _CustomerEditorDialogState extends State<CustomerEditorDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController phone;
  late final TextEditingController address;
  late final TextEditingController gstin;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.customer?.name);
    phone = TextEditingController(text: widget.customer?.phone);
    address = TextEditingController(text: widget.customer?.address);
    gstin = TextEditingController(text: widget.customer?.gstin);
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    gstin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await widget.onSave(
        id: widget.customer?.id,
        name: name.text,
        phone: phone.text,
        address: address.text,
        gstin: gstin.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showMessage(context, errorMessage(error), error: true);
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.customer == null ? 'Add customer' : 'Edit customer'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Customer name'),
                validator: (value) =>
                    (value ?? '').trim().length < 2 ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile number'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: gstin,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'GSTIN (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: address,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
}

typedef BusinessSaver = Future<void> Function(Map<String, Object?> values);

class BusinessEditorDialog extends StatefulWidget {
  const BusinessEditorDialog({
    super.key,
    required this.business,
    required this.onSave,
  });
  final Map<String, Object?> business;
  final BusinessSaver onSave;

  @override
  State<BusinessEditorDialog> createState() => _BusinessEditorDialogState();
}

class _BusinessEditorDialogState extends State<BusinessEditorDialog> {
  late final Map<String, TextEditingController> fields;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    fields = {
      for (final key in [
        'company_name',
        'phone',
        'address',
        'gstin',
        'state_code',
        'invoice_prefix',
        'invoice_footer',
      ])
        key: TextEditingController(text: widget.business[key] as String),
    };
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (fields['company_name']!.text.trim().length < 2 ||
        fields['invoice_prefix']!.text.trim().isEmpty) {
      return showMessage(
        context,
        'Business name and invoice prefix are required.',
        error: true,
      );
    }
    setState(() => saving = true);
    try {
      await widget.onSave({
        'company_name': fields['company_name']!.text.trim(),
        'phone': fields['phone']!.text.trim(),
        'address': fields['address']!.text.trim(),
        'gstin': fields['gstin']!.text.trim().toUpperCase(),
        'state_code': fields['state_code']!.text.trim(),
        'invoice_prefix': fields['invoice_prefix']!.text.trim().toUpperCase(),
        'invoice_footer': fields['invoice_footer']!.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showMessage(context, errorMessage(error), error: true);
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Business settings'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field('company_name', 'Business name'),
            const SizedBox(height: 12),
            _field('phone', 'Phone', type: TextInputType.phone),
            const SizedBox(height: 12),
            _field('gstin', 'GSTIN', capitals: true),
            const SizedBox(height: 12),
            _field('state_code', 'State code', type: TextInputType.number),
            const SizedBox(height: 12),
            _field('invoice_prefix', 'Invoice prefix', capitals: true),
            const SizedBox(height: 12),
            _field('address', 'Address', lines: 3),
            const SizedBox(height: 12),
            _field('invoice_footer', 'Invoice footer', lines: 2),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Saving…' : 'Save'),
      ),
    ],
  );

  Widget _field(
    String key,
    String label, {
    TextInputType? type,
    bool capitals = false,
    int lines = 1,
  }) => TextField(
    controller: fields[key],
    keyboardType: type,
    textCapitalization: capitals
        ? TextCapitalization.characters
        : TextCapitalization.none,
    maxLines: lines,
    decoration: InputDecoration(labelText: label),
  );
}

class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({
    super.key,
    required this.cart,
    required this.customers,
    required this.onSave,
  });
  final List<CartLine> cart;
  final List<Customer> customers;
  final Future<String> Function(
    Customer? customer,
    String walkInName,
    String walkInPhone,
    String paymentMethod,
  )
  onSave;

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  final name = TextEditingController(text: 'Walk-in Customer');
  final phone = TextEditingController();
  Customer? selected;
  String payment = 'CASH';
  bool saving = false;

  int get total => widget.cart.fold(
    0,
    (sum, line) =>
        sum +
        calculateLine(
          priceInPaise: line.product.priceInPaise,
          quantity: line.quantity,
          discountPercent: line.discountPercent,
          taxRateBasisPoints: line.product.taxRateBasisPoints,
        ).total,
  );

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.cart.isEmpty) return;
    setState(() => saving = true);
    try {
      final id = await widget.onSave(selected, name.text, phone.text, payment);
      if (mounted) Navigator.pop(context, id);
    } catch (error) {
      if (mounted) {
        showMessage(context, errorMessage(error), error: true);
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + inset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Complete bill',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            ...widget.cart.asMap().entries.map((entry) {
              final line = entry.value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(line.product.name),
                subtitle: Text(
                  '${money(line.product.priceInPaise)} × ${line.quantity}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: saving
                          ? null
                          : () => setState(() {
                              if (line.quantity <= 1) {
                                widget.cart.removeAt(entry.key);
                              } else {
                                line.quantity--;
                              }
                            }),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('${line.quantity}'),
                    IconButton(
                      onPressed:
                          saving || line.quantity >= line.product.stockQuantity
                          ? null
                          : () => setState(() => line.quantity++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              );
            }),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grand total',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  money(total),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<Customer?>(
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'Customer'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Walk-in customer'),
                ),
                ...widget.customers.map(
                  (customer) => DropdownMenuItem(
                    value: customer,
                    child: Text(customer.name),
                  ),
                ),
              ],
              onChanged: saving
                  ? null
                  : (value) => setState(() => selected = value),
            ),
            if (selected == null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: name,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'Customer name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                enabled: !saving,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile number'),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: payment,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: const [
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                DropdownMenuItem(value: 'CARD', child: Text('Card')),
                DropdownMenuItem(
                  value: 'CREDIT',
                  child: Text('Credit / Pay later'),
                ),
              ],
              onChanged: saving
                  ? null
                  : (value) => setState(() => payment = value!),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: saving || widget.cart.isEmpty ? null : _save,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(saving ? 'Saving bill…' : 'Complete sale'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
