import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../models.dart';
import '../report_export_service.dart';
import '../ui_helpers.dart';

enum DatePreset {
  today,
  sevenDays,
  thirtyDays,
  thisMonth,
  custom,
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.controller,
    this.drawer,
  });

  final AppController controller;
  final Widget? drawer;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final exporter = ReportExportService();
  late DateTime from;
  late DateTime to;
  late Future<SalesReport> report;
  DatePreset _activePreset = DatePreset.thirtyDays;
  String? exporting;

  @override
  void initState() {
    super.initState();
    to = DateTime.now();
    from = to.subtract(const Duration(days: 29));
    report = _load();
  }

  Future<SalesReport> _load() =>
      widget.controller.database.salesReport(from, to);

  void _applyPreset(DatePreset preset) {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    setState(() {
      _activePreset = preset;
      switch (preset) {
        case DatePreset.today:
          from = DateTime(now.year, now.month, now.day);
          to = todayEnd;
          break;
        case DatePreset.sevenDays:
          from = DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 6));
          to = todayEnd;
          break;
        case DatePreset.thirtyDays:
          from = DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 29));
          to = todayEnd;
          break;
        case DatePreset.thisMonth:
          from = DateTime(now.year, now.month, 1);
          to = todayEnd;
          break;
        case DatePreset.custom:
          _pickDateRange();
          return;
      }
      report = _load();
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: from, end: to),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xff004d40),
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      _activePreset = DatePreset.custom;
      from = picked.start;
      to = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
      );
      report = _load();
    });
  }

  Future<void> _export(
    String type,
    SalesReport value,
    Future<void> Function(SalesReport) action,
  ) async {
    if (widget.controller.session?.allowReportsExports != true) {
      if (mounted) {
        showMessage(
          context,
          'Reports & Exports are not included in your current plan.',
          error: true,
        );
      }
      return;
    }
    setState(() => exporting = type);
    try {
      await action(value);
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => exporting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    const tealHeaderColor = Color(0xff004d40);

    if (widget.controller.session?.allowReportsExports != true) {
      return Scaffold(
        drawer: widget.drawer,
        appBar: AppBar(
          backgroundColor: tealHeaderColor,
          foregroundColor: Colors.white,
          leading: widget.drawer != null
              ? Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    tooltip: 'Open menu',
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                )
              : null,
          title: const Text(
            'Reports & Exports',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Reports & Exports are not included in your current plan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xff64748b)),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      drawer: widget.drawer,
      appBar: AppBar(
        backgroundColor: tealHeaderColor,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: widget.drawer != null
            ? Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  tooltip: 'Open menu',
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              )
            : null,
        title: const Text(
          'Reports & Exports',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_rounded, color: Colors.white),
            tooltip: 'Select date range',
            onPressed: _pickDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          // Teal top bar with Date Range selector pill and quick preset chips
          Container(
            color: tealHeaderColor,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date Range display pill
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pickDateRange,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: Color(0xff004d40),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${DateFormat('dd MMM yyyy').format(from)}  ➔  ${DateFormat('dd MMM yyyy').format(to)}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff1e293b),
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_drop_down_rounded,
                            color: Color(0xff64748b),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick Preset Chips (Smooth, not eye-hitting)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _PresetChip(
                        label: 'Today',
                        isSelected: _activePreset == DatePreset.today,
                        onTap: () => _applyPreset(DatePreset.today),
                      ),
                      const SizedBox(width: 8),
                      _PresetChip(
                        label: '7 Days',
                        isSelected: _activePreset == DatePreset.sevenDays,
                        onTap: () => _applyPreset(DatePreset.sevenDays),
                      ),
                      const SizedBox(width: 8),
                      _PresetChip(
                        label: '30 Days',
                        isSelected: _activePreset == DatePreset.thirtyDays,
                        onTap: () => _applyPreset(DatePreset.thirtyDays),
                      ),
                      const SizedBox(width: 8),
                      _PresetChip(
                        label: 'This Month',
                        isSelected: _activePreset == DatePreset.thisMonth,
                        onTap: () => _applyPreset(DatePreset.thisMonth),
                      ),
                      const SizedBox(width: 8),
                      _PresetChip(
                        label: 'Custom',
                        isSelected: _activePreset == DatePreset.custom,
                        onTap: () => _applyPreset(DatePreset.custom),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Scrollable Content
          Expanded(
            child: FutureBuilder<SalesReport>(
              future: report,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorState(
                    message: errorMessage(snapshot.error!),
                    onRetry: () async => setState(() => report = _load()),
                  );
                }
                if (!snapshot.hasData) return const LoadingView();

                final value = snapshot.data!;
                final totalSales = value.totalSales;
                final collected = value.collected;
                final outstanding = value.outstanding;

                final collectedRatio = totalSales > 0
                    ? (collected / totalSales).clamp(0.0, 1.0)
                    : 0.0;
                final collectedPercent = (collectedRatio * 100).round();
                final pendingPercent = 100 - collectedPercent;

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                  children: [
                    // Hybrid Hero Financial Card with Dual-Progress Bar
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xffe2e8f0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Total Revenue',
                                style: TextStyle(
                                  color: Color(0xff64748b),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xffe6f2f0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${value.invoiceCount} ${value.invoiceCount == 1 ? 'Invoice' : 'Invoices'}',
                                  style: const TextStyle(
                                    color: Color(0xff004d40),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            money(totalSales),
                            style: const TextStyle(
                              color: Color(0xff0f172a),
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Dual-tone Collection Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              height: 8,
                              child: Row(
                                children: [
                                  if (collectedRatio > 0)
                                    Expanded(
                                      flex: (collectedRatio * 1000).toInt(),
                                      child: Container(
                                        color: const Color(0xff16a34a),
                                      ),
                                    ),
                                  if (collectedRatio < 1.0 && totalSales > 0)
                                    Expanded(
                                      flex: ((1.0 - collectedRatio) * 1000)
                                          .toInt(),
                                      child: Container(
                                        color: const Color(0xffd97706),
                                      ),
                                    ),
                                  if (totalSales == 0)
                                    Expanded(
                                      child: Container(
                                        color: const Color(0xffe2e8f0),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Legend Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xff16a34a),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Collected: $collectedPercent%',
                                    style: const TextStyle(
                                      color: Color(0xff16a34a),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xffd97706),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pending: $pendingPercent%',
                                    style: const TextStyle(
                                      color: Color(0xffd97706),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2x2 Metric Grid (Smooth, subtle tint cards)
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            label: 'Collected',
                            value: money(collected),
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: const Color(0xff16a34a),
                            iconBgColor: const Color(0xffecfdf5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricCard(
                            label: 'Outstanding',
                            value: money(outstanding),
                            icon: Icons.pending_actions_rounded,
                            iconColor: const Color(0xffd97706),
                            iconBgColor: const Color(0xfffffbeb),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            label: 'Total Invoices',
                            value: '${value.invoiceCount}',
                            icon: Icons.receipt_long_outlined,
                            iconColor: const Color(0xff0284c7),
                            iconBgColor: const Color(0xfff0f9ff),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricCard(
                            label: 'Avg. Bill Value',
                            value: money(
                              value.invoiceCount > 0
                                  ? (totalSales / value.invoiceCount).round()
                                  : 0,
                            ),
                            icon: Icons.analytics_outlined,
                            iconColor: const Color(0xff004d40),
                            iconBgColor: const Color(0xffe6f2f0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Modern Instant Export Hub Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xffe2e8f0),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.file_download_outlined,
                                size: 18,
                                color: Color(0xff004d40),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Instant Export Reports',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff004d40),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${value.invoices.length} records',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xff64748b),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _ExportActionTile(
                                  label: 'Excel',
                                  extension: '.xlsx',
                                  icon: Icons.table_chart_rounded,
                                  accentColor: const Color(0xff16a34a),
                                  bgColor: const Color(0xffecfdf5),
                                  busy: exporting == 'Excel',
                                  enabled: value.invoices.isNotEmpty &&
                                      exporting == null,
                                  onPressed: () => _export(
                                    'Excel',
                                    value,
                                    exporter.shareExcel,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ExportActionTile(
                                  label: 'PDF',
                                  extension: '.pdf',
                                  icon: Icons.picture_as_pdf_rounded,
                                  accentColor: const Color(0xffdc2626),
                                  bgColor: const Color(0xfffef2f2),
                                  busy: exporting == 'PDF',
                                  enabled: value.invoices.isNotEmpty &&
                                      exporting == null,
                                  onPressed: () => _export(
                                    'PDF',
                                    value,
                                    exporter.sharePdf,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ExportActionTile(
                                  label: 'CSV',
                                  extension: '.csv',
                                  icon: Icons.table_rows_rounded,
                                  accentColor: const Color(0xff0284c7),
                                  bgColor: const Color(0xfff0f9ff),
                                  busy: exporting == 'CSV',
                                  enabled: value.invoices.isNotEmpty &&
                                      exporting == null,
                                  onPressed: () => _export(
                                    'CSV',
                                    value,
                                    exporter.shareCsv,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Payment Breakdown Section
                    const Text(
                      'Payment Breakdown',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff1e293b),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xffe2e8f0),
                          width: 1,
                        ),
                      ),
                      child: value.paymentTotals.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  'No sales recorded in this date range.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xff94a3b8),
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                for (final entry
                                    in value.paymentTotals.entries) ...[
                                  _PaymentModeRow(
                                    modeName: entry.key,
                                    amount: entry.value,
                                    totalSales: totalSales,
                                  ),
                                  if (entry.key !=
                                      value.paymentTotals.keys.last)
                                    const Divider(
                                      height: 14,
                                      color: Color(0xfff1f5f9),
                                    ),
                                ],
                              ],
                            ),
                    ),
                    const SizedBox(height: 18),

                    // Invoices in Period Section
                    Row(
                      children: [
                        const Text(
                          'Invoices',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff1e293b),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Showing ${value.invoices.length > 50 ? '50 of ' : ''}${value.invoices.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xff64748b),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (value.invoices.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xffe2e8f0),
                            width: 1,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'No invoices found for this date range.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xff94a3b8),
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: value.invoices.take(50).length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final invoice = value.invoices[index];
                          return Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: Color(0xffe2e8f0),
                                width: 1,
                              ),
                            ),
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            invoice.invoiceNumber,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: Color(0xff004d40),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${invoice.customerName.isEmpty ? 'Walk-in Customer' : invoice.customerName} · ${DateFormat('dd MMM yyyy').format(invoice.issuedAt.toLocal())}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xff64748b),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      money(invoice.totalInPaise),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: Color(0xff0f172a),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : const Color(0x26ffffff),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.white : const Color(0x3fffffff),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xff004d40) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xffe2e8f0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xff0f172a),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xff64748b),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportActionTile extends StatelessWidget {
  const _ExportActionTile({
    required this.label,
    required this.extension,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    required this.busy,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final String extension;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: enabled ? bgColor : const Color(0xfff8fafc),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? accentColor.withOpacity(0.3)
                  : const Color(0xffe2e8f0),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                )
              else
                Icon(
                  icon,
                  size: 24,
                  color: enabled ? accentColor : const Color(0xff94a3b8),
                ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: enabled ? const Color(0xff1e293b) : const Color(0xff94a3b8),
                ),
              ),
              Text(
                extension,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: enabled ? accentColor : const Color(0xff94a3b8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentModeRow extends StatelessWidget {
  const _PaymentModeRow({
    required this.modeName,
    required this.amount,
    required this.totalSales,
  });

  final String modeName;
  final int amount;
  final int totalSales;

  @override
  Widget build(BuildContext context) {
    final cleanName = modeName.replaceAll('_', ' ').toUpperCase();
    final percent = totalSales > 0 ? ((amount / totalSales) * 100).round() : 0;

    IconData modeIcon;
    Color iconColor;
    if (cleanName.contains('CASH')) {
      modeIcon = Icons.payments_outlined;
      iconColor = const Color(0xff16a34a);
    } else if (cleanName.contains('UPI')) {
      modeIcon = Icons.qr_code_2_rounded;
      iconColor = const Color(0xff0284c7);
    } else if (cleanName.contains('CARD')) {
      modeIcon = Icons.credit_card_rounded;
      iconColor = const Color(0xff7c3aed);
    } else {
      modeIcon = Icons.account_balance_outlined;
      iconColor = const Color(0xff004d40);
    }

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(modeIcon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cleanName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff1e293b),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$percent% of total sales',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xff64748b),
                ),
              ),
            ],
          ),
        ),
        Text(
          money(amount),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xff0f172a),
          ),
        ),
      ],
    );
  }
}
