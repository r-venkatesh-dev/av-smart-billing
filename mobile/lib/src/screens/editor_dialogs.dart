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

  String _cleanUnit(String value) {
    var clean = value.trim();
    final match = RegExp(r'^\d+[\s\-_]*(.*)$').firstMatch(clean);
    final groupVal = match?.group(1);
    if (groupVal != null && groupVal.trim().isNotEmpty) {
      clean = groupVal.trim();
    }
    final lower = clean.toLowerCase();
    if (lower == '1' ||
        lower == 'pc' ||
        lower == 'pcs' ||
        lower == 'piece' ||
        lower == 'pieces') {
      return 'pcs';
    }
    return clean.isEmpty ? 'pcs' : clean;
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await widget.onSave(
        id: widget.product?.id,
        name: name.text,
        sku: sku.text,
        barcode: barcode.text,
        unit: _cleanUnit(unit.text),
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
  Widget build(BuildContext context) => AppDialog(
    icon: Icons.inventory_2_outlined,
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
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final item in const [
                      'pcs',
                      'kg',
                      'box',
                      'packet',
                      'litre',
                      'meter',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(
                            item,
                            style: const TextStyle(fontSize: 12),
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() => unit.text = item);
                          },
                        ),
                      ),
                  ],
                ),
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
  Widget build(BuildContext context) => AppDialog(
    icon: Icons.person_add_alt_1_outlined,
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
  Widget build(BuildContext context) => AppDialog(
    icon: Icons.storefront_outlined,
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

class LineDiscountDialog extends StatefulWidget {
  const LineDiscountDialog({
    super.key,
    required this.productName,
    required this.initialPercent,
  });

  final String productName;
  final double initialPercent;

  @override
  State<LineDiscountDialog> createState() => _LineDiscountDialogState();
}

class _LineDiscountDialogState extends State<LineDiscountDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: formatQuantity(widget.initialPercent),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _apply() {
    final parsed = double.tryParse(controller.text);
    if (parsed == null || parsed < 0 || parsed > 100) return;
    Navigator.pop(context, parsed);
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    icon: Icons.percent_rounded,
    title: Text('${widget.productName} discount'),
    content: TextField(
      controller: controller,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Discount %',
        suffixText: '%',
      ),
      onSubmitted: (_) => _apply(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _apply,
        child: const Text('Apply'),
      ),
    ],
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
    bool saveWalkInCustomer,
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
  bool saveWalkInCustomer = false;

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
    final value = await showDialog<double>(
      context: context,
      builder: (context) => LineDiscountDialog(
        productName: line.product.name,
        initialPercent: line.discountPercent,
      ),
    );
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
        saveWalkInCustomer,
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
      builder: (context) => AppDialog(
        icon: Icons.delete_sweep_outlined,
        danger: true,
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
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'Review bill',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${widget.cart.length} items',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancel bill',
                    icon: const Icon(Icons.close),
                    onPressed: saving ? null : _cancel,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: Form(
                key: form,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.35),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withOpacity(0.6),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Added Products',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    '${widget.cart.fold<double>(0, (sum, l) => sum + l.quantity).toStringAsFixed(widget.cart.any((l) => l.quantity % 1 != 0) ? 2 : 0)} units',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: widget.cart.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Text(
                                        'All products were removed. Close this sheet to start again.',
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      itemCount: widget.cart.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(
                                            height: 1,
                                            indent: 12,
                                            endIndent: 12,
                                          ),
                                      itemBuilder: (context, index) {
                                        final line = widget.cart[index];
                                        final lineVal = calculateLine(
                                          priceInPaise:
                                              line.product.priceInPaise,
                                          quantity: line.quantity,
                                          discountPercent: line.discountPercent,
                                          taxRateBasisPoints:
                                              line.product.taxRateBasisPoints,
                                        );
                                        return Container(
                                          color: line.discountPercent > 0
                                              ? const Color(0xfffff8e7)
                                              : null,
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            6,
                                            8,
                                            6,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      line.product.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${money(line.product.priceInPaise)} × ${formatQuantity(line.quantity)}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .grey
                                                            .shade700,
                                                      ),
                                                    ),
                                                    if (line.discountPercent >
                                                        0)
                                                      Text(
                                                        '${formatPercent(line.discountPercent)} disc (-${money(lineVal.discount)})',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .orange
                                                              .shade800,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                tooltip: 'Line discount',
                                                icon: Icon(
                                                  Icons.percent,
                                                  size: 16,
                                                  color:
                                                      line.discountPercent > 0
                                                      ? Colors.orange.shade800
                                                      : null,
                                                ),
                                                onPressed: saving
                                                    ? null
                                                    : () => _editLineDiscount(
                                                        line,
                                                      ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    padding: EdgeInsets.zero,
                                                    iconSize: 20,
                                                    onPressed: saving
                                                        ? null
                                                        : () => setState(() {
                                                            if (line.quantity <=
                                                                1) {
                                                              widget.cart
                                                                  .removeAt(
                                                                    index,
                                                                  );
                                                            } else {
                                                              line.quantity--;
                                                            }
                                                          }),
                                                    icon: Icon(
                                                      line.quantity <= 1
                                                          ? Icons.delete_outline
                                                          : Icons
                                                                .remove_circle_outline,
                                                      color: line.quantity <= 1
                                                          ? Colors.red.shade400
                                                          : null,
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 4,
                                                        ),
                                                    child: Text(
                                                      formatQuantity(
                                                        line.quantity,
                                                      ),
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    padding: EdgeInsets.zero,
                                                    iconSize: 20,
                                                    onPressed:
                                                        saving ||
                                                            line.quantity >=
                                                                line
                                                                    .product
                                                                    .stockQuantity
                                                        ? null
                                                        : () => setState(
                                                            () =>
                                                                line.quantity++,
                                                          ),
                                                    icon: const Icon(
                                                      Icons.add_circle_outline,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
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
                          saveWalkInCustomer = false;
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
                                            saveWalkInCustomer = false;
                                            controller.clear();
                                            name.text = 'Walk-in Customer';
                                            phone.clear();
                                          }),
                                          icon: const Icon(Icons.close),
                                        ),
                                ),
                                onChanged: (text) {
                                  if (selected != null &&
                                      text != selected!.name) {
                                    setState(() {
                                      selected = null;
                                      saveWalkInCustomer = false;
                                    });
                                  }
                                },
                              );
                            },
                        optionsViewBuilder: (context, onSelected, options) =>
                            Align(
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
                          'Customer details',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: name,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'Customer name',
                          ),
                          validator: (text) {
                            final val = (text ?? '').trim();
                            if (selected == null && val.length < 2) {
                              return 'Enter the customer name.';
                            }
                            if (saveWalkInCustomer &&
                                val.toLowerCase() == 'walk-in customer') {
                              return 'Enter the actual customer name.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phone,
                          enabled: !saving,
                          keyboardType: TextInputType.phone,
                          inputFormatters: mobileNumberInputFormatters,
                          decoration: const InputDecoration(
                            labelText: 'Mobile number',
                            hintText: 'Optional for walk-in / food delivery',
                          ),
                          validator: selected == null
                              ? (text) => validateOptionalMobileNumber(text)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xffeaf7f5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CheckboxListTile(
                            value: saveWalkInCustomer,
                            enabled: !saving,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            title: const Text(
                              'Save this customer for future bills',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),

                            onChanged: saving
                                ? null
                                : (v) => setState(
                                    () => saveWalkInCustomer = v ?? false,
                                  ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: payment,
                        decoration: const InputDecoration(
                          labelText: 'Payment method',
                        ),
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
                            : (v) => setState(() => payment = v!),
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
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
                border: Border(
                  top: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Payable',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          money(value.total),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onHold != null) ...[
                    IconButton.outlined(
                      tooltip: 'Hold bill',
                      onPressed: saving || widget.cart.isEmpty ? null : _hold,
                      icon: const Icon(Icons.pause_circle_outline),
                    ),
                    const SizedBox(width: 4),
                  ],
                  TextButton(
                    onPressed: saving ? null : _cancel,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('Cancel bill'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: saving || widget.cart.isEmpty ? null : _save,
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(saving ? 'Saving…' : 'Complete sale'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
