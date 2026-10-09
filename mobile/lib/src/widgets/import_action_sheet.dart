import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../excel_import_export_service.dart';
import '../ui_helpers.dart';

enum ImportDataType {
  products,
  customers,
}

Future<void> showImportActionSheet({
  required BuildContext context,
  required AppController controller,
  required ImportDataType type,
  required VoidCallback onRefresh,
}) async {
  final service = ExcelImportExportService();
  final isProducts = type == ImportDataType.products;
  final label = isProducts ? 'Products' : 'Customers';

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xffe6f2f0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.table_chart_outlined,
                        color: Color(0xff004d40),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$label Excel Tools',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff004d40),
                            ),
                          ),
                          Text(
                            isProducts
                                ? 'Import, export or get sample template'
                                : 'Manage customers in bulk via Excel',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xff64748b),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xff64748b)),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Option 1: Import from Excel
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xfff0fdf4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xffbbf7d0)),
                  ),
                  child: const Icon(Icons.file_upload_outlined, color: Color(0xff16a34a)),
                ),
                title: Text(
                  'Import $label from Excel',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                subtitle: const Text(
                  'Upload .xlsx file. Existing duplicates will be replaced automatically.',
                  style: TextStyle(fontSize: 12, color: Color(0xff64748b)),
                ),
                trailing: const Icon(Icons.chevron_right, color: Color(0xff94a3b8)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _handleImport(context, controller, service, type, onRefresh);
                },
              ),

              // Option 2: Export to Excel
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xfff0f9ff),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xffbae6fd)),
                  ),
                  child: const Icon(Icons.file_download_outlined, color: Color(0xff0284c7)),
                ),
                title: Text(
                  'Export $label to Excel',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                subtitle: Text(
                  'Download all current $label as an Excel sheet.',
                  style: const TextStyle(fontSize: 12, color: Color(0xff64748b)),
                ),
                trailing: const Icon(Icons.chevron_right, color: Color(0xff94a3b8)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _handleExport(context, controller, service, type);
                },
              ),

              // Option 3: Download Template
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xfffefce8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xfffef08a)),
                  ),
                  child: const Icon(Icons.description_outlined, color: Color(0xffca8a04)),
                ),
                title: const Text(
                  'Download Excel Template',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                subtitle: Text(
                  isProducts
                      ? 'Pre-formatted sheet with Name, Price, Stock & Unit columns.'
                      : 'Pre-formatted sheet with Name, Phone, GSTIN & Address.',
                  style: const TextStyle(fontSize: 12, color: Color(0xff64748b)),
                ),
                trailing: const Icon(Icons.chevron_right, color: Color(0xff94a3b8)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _handleDownloadTemplate(context, service, type);
                },
              ),

              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xfff8fafc),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xffe2e8f0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20, color: Color(0xff004d40)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isProducts
                              ? 'Mandatory: Product Name, Price, Stock, Selling Unit. Duplicates matched by SKU or Name are updated in place.'
                              : 'Mandatory: Customer Name. Duplicates matched by Phone or Name are updated in place.',
                          style: const TextStyle(fontSize: 12, color: Color(0xff334155)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _handleImport(
  BuildContext context,
  AppController controller,
  ExcelImportExportService service,
  ImportDataType type,
  VoidCallback onRefresh,
) async {
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final filePath = file.path;
    final bytes = file.bytes ?? (filePath != null ? await File(filePath).readAsBytes() : null);

    if (bytes == null) {
      if (context.mounted) {
        showMessage(context, 'Could not read the selected file.', error: true);
      }
      return;
    }

    if (!context.mounted) return;

    // Show loading dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AppDialog(
          icon: Icons.sync,
          title: const Text('Importing Data…'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Reading Excel records and checking for duplicates…',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xff64748b)),
              ),
            ],
          ),
          actions: const [],
        ),
      ),
    );

    ImportResult importResult;
    if (type == ImportDataType.products) {
      importResult = await service.importProducts(bytes, controller);
    } else {
      importResult = await service.importCustomers(bytes, controller);
    }

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // close loading dialog
      onRefresh();

      // Show result dialog
      await showDialog<void>(
        context: context,
        builder: (_) => _ImportResultDialog(
          result: importResult,
          type: type,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst || route is! DialogRoute);
      showMessage(context, errorMessage(e), error: true);
    }
  }
}

Future<void> _handleExport(
  BuildContext context,
  AppController controller,
  ExcelImportExportService service,
  ImportDataType type,
) async {
  try {
    if (type == ImportDataType.products) {
      final products = await controller.products();
      if (products.isEmpty) {
        if (context.mounted) {
          showMessage(context, 'No products to export.', error: true);
        }
        return;
      }
      await service.exportProducts(products);
    } else {
      final customers = await controller.customers();
      if (customers.isEmpty) {
        if (context.mounted) {
          showMessage(context, 'No customers to export.', error: true);
        }
        return;
      }
      await service.exportCustomers(customers);
    }
  } catch (e) {
    if (context.mounted) {
      showMessage(context, errorMessage(e), error: true);
    }
  }
}

Future<void> _handleDownloadTemplate(
  BuildContext context,
  ExcelImportExportService service,
  ImportDataType type,
) async {
  try {
    if (type == ImportDataType.products) {
      await service.downloadProductsTemplate();
    } else {
      await service.downloadCustomersTemplate();
    }
  } catch (e) {
    if (context.mounted) {
      showMessage(context, errorMessage(e), error: true);
    }
  }
}

class _ImportResultDialog extends StatelessWidget {
  const _ImportResultDialog({
    required this.result,
    required this.type,
  });

  final ImportResult result;
  final ImportDataType type;

  @override
  Widget build(BuildContext context) {
    final label = type == ImportDataType.products ? 'Products' : 'Customers';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: result.successCount > 0 ? const Color(0xfff0fdf4) : const Color(0xfffef2f2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  result.successCount > 0 ? Icons.check_circle_outline : Icons.error_outline,
                  color: result.successCount > 0 ? const Color(0xff16a34a) : const Color(0xffdc2626),
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Import Finished',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff004d40),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Processed ${result.totalRows} $label row${result.totalRows == 1 ? '' : 's'}.',
                style: const TextStyle(fontSize: 13, color: Color(0xff64748b)),
              ),
              const SizedBox(height: 18),

              // Summary Stats Row
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      label: 'Added',
                      count: result.addedCount,
                      color: const Color(0xff16a34a),
                      bgColor: const Color(0xfff0fdf4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard(
                      label: 'Updated',
                      count: result.updatedCount,
                      color: const Color(0xff0284c7),
                      bgColor: const Color(0xfff0f9ff),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard(
                      label: 'Skipped',
                      count: result.errors.length,
                      color: result.errors.isNotEmpty ? const Color(0xffdc2626) : const Color(0xff64748b),
                      bgColor: result.errors.isNotEmpty ? const Color(0xfffef2f2) : const Color(0xfff8fafc),
                    ),
                  ),
                ],
              ),

              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Skipped Rows (${result.errors.length}):',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xffdc2626),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xfffef2f2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xfffecaca)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: result.errors.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, i) => Text(
                      '• ${result.errors[i]}',
                      style: const TextStyle(fontSize: 11, color: Color(0xff991b1b)),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff004d40),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard({
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
