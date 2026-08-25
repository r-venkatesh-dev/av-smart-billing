import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../models.dart';
import '../report_export_service.dart';
import '../ui_helpers.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final exporter = ReportExportService();
  late DateTime from;
  late DateTime to;
  late Future<SalesReport> report;
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

  Future<void> _pickDate(bool start) async {
    final current = start ? from : to;
    final value = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (value == null || !mounted) return;
    if (start && value.isAfter(to)) {
      showMessage(context, 'From date cannot be after To date.', error: true);
      return;
    }
    if (!start && value.isBefore(from)) {
      showMessage(context, 'To date cannot be before From date.', error: true);
      return;
    }
    setState(() {
      if (start) {
        from = value;
      } else {
        to = value;
      }
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
    if (widget.controller.session?.allowReportsExports != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reports & Exports')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Reports & Exports are not included in your current plan.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Exports')),
      body: FutureBuilder<SalesReport>(
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DateButton(
                      label: 'From',
                      date: from,
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateButton(
                      label: 'To',
                      date: to,
                      onTap: () => _pickDate(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.45,
                children: [
                  _ReportMetric(
                    label: 'Total sales',
                    value: money(value.totalSales),
                  ),
                  _ReportMetric(
                    label: 'Invoices',
                    value: '${value.invoiceCount}',
                  ),
                  _ReportMetric(
                    label: 'Collected',
                    value: money(value.collected),
                  ),
                  _ReportMetric(
                    label: 'Outstanding',
                    value: money(value.outstanding),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EXPORT REPORT',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ExportButton(
                              label: 'CSV',
                              icon: Icons.table_rows_outlined,
                              busy: exporting == 'CSV',
                              enabled:
                                  value.invoices.isNotEmpty &&
                                  exporting == null,
                              onPressed: () =>
                                  _export('CSV', value, exporter.shareCsv),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ExportButton(
                              label: 'Excel',
                              icon: Icons.grid_on_outlined,
                              busy: exporting == 'Excel',
                              enabled:
                                  value.invoices.isNotEmpty &&
                                  exporting == null,
                              onPressed: () =>
                                  _export('Excel', value, exporter.shareExcel),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ExportButton(
                              label: 'PDF',
                              icon: Icons.picture_as_pdf_outlined,
                              busy: exporting == 'PDF',
                              enabled:
                                  value.invoices.isNotEmpty &&
                                  exporting == null,
                              onPressed: () =>
                                  _export('PDF', value, exporter.sharePdf),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Payment summary',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: value.paymentTotals.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('No sales in this date range.'),
                      )
                    : Column(
                        children: value.paymentTotals.entries
                            .map(
                              (entry) => ListTile(
                                title: Text(entry.key.replaceAll('_', ' ')),
                                trailing: Text(
                                  money(entry.value),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                'Invoices',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (value.invoices.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No invoices found for this date range.'),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: value.invoices
                        .take(100)
                        .map(
                          (invoice) => ListTile(
                            title: Text(invoice.invoiceNumber),
                            subtitle: Text(
                              '${invoice.customerName} · ${DateFormat('dd MMM yyyy').format(invoice.issuedAt.toLocal())}',
                            ),
                            trailing: Text(
                              money(invoice.totalInPaise),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(14)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(Icons.calendar_month_outlined, size: 18),
            const SizedBox(width: 7),
            Text(DateFormat('dd MMM yyyy').format(date)),
          ],
        ),
      ],
    ),
  );
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    ),
  );
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.enabled,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: enabled ? onPressed : null,
    icon: busy
        ? const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 18),
    label: Text(label),
  );
}
