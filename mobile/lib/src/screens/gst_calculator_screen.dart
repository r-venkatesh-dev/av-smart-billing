import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui_helpers.dart';

class GstCalculatorScreen extends StatefulWidget {
  const GstCalculatorScreen({super.key, this.drawer});

  final Widget? drawer;

  @override
  State<GstCalculatorScreen> createState() => _GstCalculatorScreenState();
}

class _GstCalculatorScreenState extends State<GstCalculatorScreen> {
  final _amountController = TextEditingController(text: '1000');
  final _customRateController = TextEditingController(text: '18');

  bool _isInclusive = false;
  double _gstRate = 18.0;
  bool _isIntraState = true;

  static const List<double> _slabs = [0.0, 5.0, 12.0, 18.0, 28.0];

  @override
  void dispose() {
    _amountController.disposenatural();
    _customRateController.dispose();
    super.dispose();
  }

  void _addAmount(double add) {
    final current = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final updated = (current + add).roundToDouble();
    _amountController.text = updated.toStringAsFixed(0);
    setState(() {});
  }

  void _reset() {
    _amountController.text = '1000';
    _customRateController.text = '18';
    setState(() {
      _isInclusive = false;
      _gstRate = 18.0;
      _isIntraState = true;
    });
  }

  void _copyBreakdown(
    double base,
    double totalGst,
    double cgst,
    double sgst,
    double igst,
    double finalAmount,
  ) {
    final text = StringBuffer()
      ..writeln('GST Calculation (${_isInclusive ? "GST Inclusive" : "GST Exclusive"}):')
      ..writeln('Base / Net Amount: ₹${base.toStringAsFixed(2)}')
      ..writeln('GST Rate: ${_gstRate.toStringAsFixed(1)}%');

    if (_isIntraState) {
      text
        ..writeln('CGST (${(_gstRate / 2).toStringAsFixed(1)}%): ₹${cgst.toStringAsFixed(2)}')
        ..writeln('SGST (${(_gstRate / 2).toStringAsFixed(1)}%): ₹${sgst.toStringAsFixed(2)}');
    } else {
      text.writeln('IGST (${_gstRate.toStringAsFixed(1)}%): ₹${igst.toStringAsFixed(2)}');
    }

    text
      ..writeln('Total GST: ₹${totalGst.toStringAsFixed(2)}')
      ..writeln('Total Final Amount: ₹${finalAmount.toStringAsFixed(2)}');

    Clipboard.setData(ClipboardData(text: text.toString()));
    showMessage(context, 'Calculation breakdown copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final rate = _gstRate.clamp(0.0, 100.0);

    double baseAmount;
    double totalGst;
    double finalAmount;

    if (_isInclusive) {
      baseAmount = rate == 0 ? amount : (amount * 100.0) / (100.0 + rate);
      totalGst = amount - baseAmount;
      finalAmount = amount;
    } else {
      baseAmount = amount;
      totalGst = (amount * rate) / 100.0;
      finalAmount = baseAmount + totalGst;
    }

    final cgst = totalGst / 2.0;
    final sgst = totalGst / 2.0;
    final igst = totalGst;

    const tealHeaderColor = Color(0xff004d40);
    const primaryColor = Color(0xff004d40);

    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      drawer: widget.drawer,
      appBar: AppBar(
        backgroundColor: tealHeaderColor,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            tooltip: 'Open menu',
            onPressed: () {
              final scaffold = Scaffold.maybeOf(ctx);
              if (scaffold != null && scaffold.hasDrawer) {
                scaffold.openDrawer();
                return;
              }
              final root = ctx.findRootAncestorStateOfType<ScaffoldState>();
              if (root != null && root.hasDrawer) {
                root.openDrawer();
              }
            },
          ),
        ),
        title: const Text(
          'GST Calculator',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Reset',
            onPressed: _reset,
          ),
        ],
      ),
      body: Column(
        children: [
          // Teal top bar container containing the rounded segment toggle
          Container(
            color: tealHeaderColor,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isInclusive = false),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        decoration: BoxDecoration(
                          color: !_isInclusive ? tealHeaderColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Exclusive (+ Add GST)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: !_isInclusive ? Colors.white : const Color(0xff475569),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isInclusive = true),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isInclusive ? tealHeaderColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Inclusive (− Remove GST)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _isInclusive ? Colors.white : const Color(0xff475569),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Amount input card
                Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xffe4e7ec)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isInclusive
                        ? 'TOTAL AMOUNT (₹ WITH GST)'
                        : 'BASE PRICE / AMOUNT (₹)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xffd0d5dd)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [100.0, 500.0, 1000.0, 5000.0].map((quick) {
                      return ActionChip(
                        label: Text('+₹${quick.toInt()}'),
                        labelStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: const Color(0xfff8f9fa),
                        side: const BorderSide(color: Color(0xffe4e7ec)),
                        padding: EdgeInsets.zero,
                        onPressed: () => _addAmount(quick),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // GST Rate Slabs Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xffe4e7ec)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GST RATE SLAB (%)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _slabs.map((slab) {
                      final isSelected = _gstRate == slab;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.5),
                          child: InkWell(
                            onTap: () {
                              _customRateController.text = slab.toInt().toString();
                              setState(() => _gstRate = slab);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xffe6f2f0)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? primaryColor
                                      : const BorderSide().color.withValues(alpha: 0.2),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${slab.toInt()}%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? primaryColor : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Custom rate:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _customRateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            suffixText: '%',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final custom = double.tryParse(val) ?? 0.0;
                            setState(() => _gstRate = custom);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Tax Treatment Card (Intra vs Inter)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xffe4e7ec)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TAX TREATMENT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Intra-State (CGST + SGST)'),
                          selected: _isIntraState,
                          selectedColor: const Color(0xffe6f2f0),
                          onSelected: (_) => setState(() => _isIntraState = true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Inter-State (IGST)'),
                          selected: !_isIntraState,
                          selectedColor: const Color(0xffe6f2f0),
                          onSelected: (_) => setState(() => _isIntraState = false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Output / Result Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xffbddbd7)),
            ),
            color: const Color(0xfff7fbf9),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PRICE BREAKUP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: primaryColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffe6f2f0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_gstRate.toStringAsFixed(1)}% GST',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _BreakupRow(
                    label: 'Base / Net Price',
                    value: '₹${baseAmount.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  if (_isIntraState) ...[
                    _BreakupRow(
                      label: '  • CGST (${(_gstRate / 2).toStringAsFixed(1)}%)',
                      value: '₹${cgst.toStringAsFixed(2)}',
                      isSubRow: true,
                    ),
                    const SizedBox(height: 6),
                    _BreakupRow(
                      label: '  • SGST (${(_gstRate / 2).toStringAsFixed(1)}%)',
                      value: '₹${sgst.toStringAsFixed(2)}',
                      isSubRow: true,
                    ),
                  ] else ...[
                    _BreakupRow(
                      label: '  • IGST (${_gstRate.toStringAsFixed(1)}%)',
                      value: '₹${igst.toStringAsFixed(2)}',
                      isSubRow: true,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _BreakupRow(
                    label: 'Total GST Amount',
                    value: '+ ₹${totalGst.toStringAsFixed(2)}',
                    isHighlight: true,
                    valueColor: primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xffbddbd7)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FINAL PAYABLE AMOUNT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${finalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xff171b36),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _isInclusive ? 'GST Included' : 'GST Added',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _copyBreakdown(
                      baseAmount,
                      totalGst,
                      cgst,
                      sgst,
                      igst,
                      finalAmount,
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Calculation Breakdown'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      foregroundColor: const Color(0xff171b36),
                      side: const BorderSide(color: Color(0xffd0d5dd)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  ],
),
    );
  }
}

class _BreakupRow extends StatelessWidget {
  const _BreakupRow({
    required this.label,
    required this.value,
    this.isSubRow = false,
    this.isHighlight = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isSubRow;
  final bool isHighlight;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSubRow ? 12 : 13.5,
            color: isSubRow ? Colors.grey.shade700 : Colors.black87,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isSubRow ? 12 : 13.5,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? (isSubRow ? Colors.grey.shade700 : Colors.black87),
          ),
        ),
      ],
    );
  }
}

extension on TextEditingController {
  void disposenatural() {
    dispose();
  }
}
