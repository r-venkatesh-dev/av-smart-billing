import 'dart:io';

import 'package:flutter/material.dart';
import '../billing_math.dart';
import '../input_rules.dart';
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
      required double discountPercent,
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
  late final TextEditingController discount;
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
          : formatQuantity(product.taxRateBasisPoints / 100),
    );
    discount = TextEditingController(
      text: product == null ? '0' : formatQuantity(product.discountPercent),
    );
    stock = TextEditingController(
      text: product == null ? '0' : formatQuantity(product.stockQuantity),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      name,
      sku,
      barcode,
      unit,
      price,
      tax,
      discount,
      stock,
    ]) {
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
        discountPercent: double.parse(discount.text),
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
              TextFormField(
                controller: discount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Default discount %',
                  helperText:
                      'Applied automatically when this product is billed',
                ),
                validator: (value) {
                  final number = double.tryParse(value ?? '');
                  if (number == null) return 'Enter a number';
                  if (number < 0 || number > 100) return 'Enter 0 to 100';
                  return null;
                },
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
                      decoration: const InputDecoration(
                        labelText: 'Selling unit',
                        hintText: 'Example: pcs, kg, box',
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) return 'Enter a unit';
                        if (double.tryParse(text) != null) {
                          return 'Use pcs, kg, box, etc.';
                        }
                        return null;
                      },
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
                inputFormatters: mobileNumberInputFormatters,
                decoration: const InputDecoration(labelText: 'Mobile number'),
                validator: validateOptionalMobileNumber,
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
        'low_stock_threshold',
      ])
        key: TextEditingController(
          text: key == 'low_stock_threshold'
              ? formatQuantity(widget.business[key] as num? ?? 5)
              : '${widget.business[key] ?? ''}',
        ),
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
    final phoneError = validateOptionalMobileNumber(fields['phone']!.text);
    if (phoneError != null) {
      return showMessage(context, phoneError, error: true);
    }
    final lowStockThreshold = double.tryParse(
      fields['low_stock_threshold']!.text,
    );
    if (lowStockThreshold == null || lowStockThreshold < 0) {
      return showMessage(
        context,
        'Enter a valid low stock threshold.',
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
        'low_stock_threshold': lowStockThreshold,
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
            _field(
              'low_stock_threshold',
              'Low stock notification at or below',
              type: const TextInputType.numberWithOptions(decimal: true),
            ),
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
    inputFormatters: key == 'phone' ? mobileNumberInputFormatters : null,
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
    required this.onCancel,
    this.onHold,
    this.paymentQrPath = '',
  });

  final List<CartLine> cart;
  final List<Customer> customers;
  final Future<String> Function(
    Customer? customer,
    String walkInName,
    String walkInPhone,
    String paymentMethod,
    double overallDiscountPercent,
  )
  onSave;
  final VoidCallback onCancel;
  final Future<void> Function(List<CartLine> cart)? onHold;
  final String paymentQrPath;

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(text: 'Walk-in Customer');
  final phone = TextEditingController();
  final overallDiscount = TextEditingController(text: '0');
  TextEditingController? customerSearch;
  Customer? selected;
  String payment = 'CASH';
  bool saving = false;

  double get overallDiscountValue => double.tryParse(overallDiscount.text) ?? 0;

  BillAmounts get amounts => calculateBill(
    lines: widget.cart.map((line) {
      final value = calculateLine(
        priceInPaise: line.product.priceInPaise,
        quantity: line.quantity,
        discountPercent: line.discountPercent,
        taxRateBasisPoints: line.product.taxRateBasisPoints,
      );
      return (
        amounts: value,
        taxRateBasisPoints: line.product.taxRateBasisPoints,
      );
    }),
    overallDiscountPercent: overallDiscountValue,
  );

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    overallDiscount.dispose();
    super.dispose();
  }

  Future<void> _editLineDiscount(CartLine line) async {
    final controller = TextEditingController(
      text: formatQuantity(line.discountPercent),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${line.product.name} discount'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Discount %',
            suffixText: '%',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text);
              if (parsed == null || parsed < 0 || parsed > 100) return;
              Navigator.pop(context, parsed);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && mounted) {
      setState(() => line.discountPercent = value);
    }
  }

  Future<void> _save() async {
    if (widget.cart.isEmpty || !form.currentState!.validate()) return;
    if (payment == 'UPI_QR' &&
        (widget.paymentQrPath.isEmpty ||
            !File(widget.paymentQrPath).existsSync())) {
      showMessage(
        context,
        'Upload the shop QR code in Business Settings or choose another payment method.',
        error: true,
      );
      return;
    }
    setState(() => saving = true);
    try {
      final id = await widget.onSave(
        selected,
        name.text,
        phone.text,
        payment,
        overallDiscountValue,
      );
      if (mounted) Navigator.pop(context, id);
    } catch (error) {
      if (mounted) {
        showMessage(context, errorMessage(error), error: true);
        setState(() => saving = false);
      }
    }
  }

  Future<void> _hold() async {
    final hold = widget.onHold;
    if (hold == null || widget.cart.isEmpty) return;
    setState(() => saving = true);
    try {
      await hold(widget.cart);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        showMessage(context, errorMessage(error), error: true);
        setState(() => saving = false);
      }
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this bill?'),
        content: const Text(
          'All added products will be removed. No invoice will be created and stock will not change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep bill'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cancel bill'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.onCancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final value = amounts;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + inset),
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Review bill',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...widget.cart.asMap().entries.map((entry) {
                final line = entry.value;
                return Card(
                  color: line.discountPercent > 0
                      ? const Color(0xfffff8e7)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${money(line.product.priceInPaise)} × ${formatQuantity(line.quantity)}',
                              ),
                              TextButton.icon(
                                onPressed: saving
                                    ? null
                                    : () => _editLineDiscount(line),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                                icon: const Icon(Icons.percent, size: 15),
                                label: Text(
                                  line.discountPercent > 0
                                      ? '${formatPercent(line.discountPercent)} discount'
                                      : 'Add discount',
                                ),
                              ),
                            ],
                          ),
                        ),
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
                          icon: Icon(
                            line.quantity <= 1
                                ? Icons.delete_outline
                                : Icons.remove_circle_outline,
                          ),
                        ),
                        Text(formatQuantity(line.quantity)),
                        IconButton(
                          onPressed:
                              saving ||
                                  line.quantity >= line.product.stockQuantity
                              ? null
                              : () => setState(() => line.quantity++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (widget.cart.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'All products were removed. Close this sheet to start again.',
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 8),
              TextFormField(
                controller: overallDiscount,
                enabled: !saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Overall bill discount',
                  suffixText: '%',
                  prefixIcon: Icon(Icons.discount_outlined),
                ),
                onChanged: (_) => setState(() {}),
                validator: (text) {
                  final number = double.tryParse(text ?? '');
                  if (number == null || number < 0 || number > 100) {
                    return 'Enter a value from 0 to 100';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _CheckoutAmount(label: 'Subtotal', value: value.subtotal),
              if (value.lineDiscount > 0)
                _CheckoutAmount(
                  label: 'Product discounts',
                  value: -value.lineDiscount,
                ),
              if (value.overallDiscount > 0)
                _CheckoutAmount(
                  label: 'Overall discount',
                  value: -value.overallDiscount,
                ),
              _CheckoutAmount(label: 'GST', value: value.tax),
              _CheckoutAmount(
                label: 'Grand total',
                value: value.total,
                strong: true,
              ),
              const SizedBox(height: 18),
              Autocomplete<Customer>(
                displayStringForOption: (customer) => customer.name,
                optionsBuilder: (text) {
                  final query = text.text.trim().toLowerCase();
                  return widget.customers.where(
                    (customer) =>
                        query.isEmpty ||
                        customer.name.toLowerCase().contains(query) ||
                        customer.phone.contains(query),
                  );
                },
                onSelected: (customer) => setState(() {
                  selected = customer;
                  name.text = customer.name;
                  phone.text = customer.phone;
                }),
                fieldViewBuilder:
                    (context, controller, focusNode, onSubmitted) {
                      customerSearch = controller;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: !saving,
                        decoration: InputDecoration(
                          labelText: 'Select customer',
                          hintText: 'Search by name or mobile number',
                          prefixIcon: const Icon(Icons.person_search),
                          suffixIcon: selected == null
                              ? null
                              : IconButton(
                                  tooltip: 'Use walk-in customer',
                                  onPressed: () => setState(() {
                                    selected = null;
                                    controller.clear();
                                    name.text = 'Walk-in Customer';
                                    phone.clear();
                                  }),
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                        onChanged: (text) {
                          if (selected != null && text != selected!.name) {
                            setState(() => selected = null);
                          }
                        },
                      );
                    },
                optionsViewBuilder: (context, onSelected, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 240,
                        maxWidth: 420,
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final customer = options.elementAt(index);
                          return ListTile(
                            title: Text(customer.name),
                            subtitle: customer.phone.isEmpty
                                ? null
                                : Text(customer.phone),
                            onTap: () => onSelected(customer),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              if (selected == null) ...[
                const SizedBox(height: 8),
                const Text(
                  'Walk-in customer details',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: name,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: 'Customer name'),
                  validator: (text) =>
                      selected == null && (text ?? '').trim().length < 2
                      ? 'Enter the customer name.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  enabled: !saving,
                  keyboardType: TextInputType.phone,
                  inputFormatters: mobileNumberInputFormatters,
                  decoration: const InputDecoration(labelText: 'Mobile number'),
                  validator: selected == null
                      ? validateOptionalMobileNumber
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: payment,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: const [
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(
                    value: 'UPI_QR',
                    child: Text('UPI / Shop QR code'),
                  ),
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
              if (payment == 'UPI_QR') ...[
                const SizedBox(height: 12),
                if (widget.paymentQrPath.isNotEmpty &&
                    File(widget.paymentQrPath).existsSync())
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Image.file(
                        File(widget.paymentQrPath),
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                else
                  const Card(
                    color: Color(0xfffff8e7),
                    child: ListTile(
                      leading: Icon(Icons.qr_code_2),
                      title: Text('Shop QR code is not configured'),
                      subtitle: Text(
                        'Upload it from Business Settings before accepting QR payments.',
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 18),
              if (widget.onHold != null)
                OutlinedButton.icon(
                  onPressed: saving || widget.cart.isEmpty ? null : _hold,
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('Hold bill and start next'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: saving ? null : _cancel,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel bill'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: saving || widget.cart.isEmpty ? null : _save,
                      icon: saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(saving ? 'Saving…' : 'Complete sale'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutAmount extends StatelessWidget {
  const _CheckoutAmount({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final int value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: strong
              ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
              : null,
        ),
        Text(
          value < 0 ? '- ${money(-value)}' : money(value),
          style: TextStyle(
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            fontSize: strong ? 22 : null,
            color: strong ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    ),
  );
}
