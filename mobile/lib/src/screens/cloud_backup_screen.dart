import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../cloud_backup_service.dart';
import '../models.dart';
import '../ui_helpers.dart';

class CloudBackupScreen extends StatefulWidget {
  const CloudBackupScreen({
    super.key,
    required this.controller,
    this.drawer,
  });

  final AppController controller;
  final Widget? drawer;

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  final service = CloudBackupService();
  Map<String, DateTime> lastBackups = {};
  String? busyEntity;
  String? availabilityMessage;
  bool checking = true;
  bool online = false;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    setState(() {
      checking = true;
      availabilityMessage = null;
    });
    if (widget.controller.session?.allowCloudBackup != true) {
      setState(() {
        checking = false;
        online = false;
        availabilityMessage =
            'Cloud backup is not included in your current plan. Upgrade your plan and activate the new key to use this feature.';
      });
      return;
    }
    try {
      final status = await service.status(widget.controller.session!.token);
      if (!mounted) return;
      setState(() {
        online = true;
        checking = false;
        lastBackups = status;
      });
    } on SocketException catch (_) {
      _offline();
    } on TimeoutException catch (_) {
      _offline();
    } on CloudConnectionException catch (_) {
      _offline();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        online = false;
        checking = false;
        availabilityMessage = errorMessage(error);
      });
    }
  }

  void _offline() {
    if (!mounted) return;
    setState(() {
      online = false;
      checking = false;
      availabilityMessage =
          'Cloud backup requires internet. Please connect to the internet and try again.';
    });
  }

  Future<void> _backup(String entity, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: Icons.cloud_upload_outlined,
        title: Text('Back up $label?'),
        content: Text(
          'Are you sure you want to save your $label data to cloud backup?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Back up now'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busyEntity = entity);
    try {
      final records = await widget.controller.database.cloudBackupRecords(
        entity,
      );
      final result = await service.push(
        token: widget.controller.session!.token,
        entity: entity,
        records: records,
      );
      if (!mounted) return;
      setState(() => lastBackups[entity] = result.backedUpAt);
      showMessage(
        context,
        '$label backed up: ${result.inserted} new, ${result.updated} updated, ${result.unchanged} already current.',
      );
    } on SocketException catch (_) {
      _offline();
    } on TimeoutException catch (_) {
      _offline();
    } on CloudConnectionException catch (_) {
      _offline();
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => busyEntity = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: widget.drawer,
    appBar: AppBar(
      leading: widget.drawer != null
          ? Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Open menu',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            )
          : null,
      title: const Text('Cloud Backup'),
      actions: [
        IconButton(
          onPressed: checking ? null : _checkAvailability,
          tooltip: 'Check internet again',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ConnectionCard(
          checking: checking,
          online: online,
          message: availabilityMessage,
          onRetry: _checkAvailability,
        ),
        const SizedBox(height: 16),
        Text(
          'Choose data to back up',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Only new or changed records are saved. Existing cloud records are not duplicated.',
        ),
        const SizedBox(height: 14),
        _BackupTile(
          icon: Icons.inventory_2_outlined,
          label: 'Products',
          lastBackup: lastBackups['products'],
          busy: busyEntity == 'products',
          enabled: online && busyEntity == null,
          onBackup: () => _backup('products', 'Products'),
        ),
        const SizedBox(height: 10),
        _BackupTile(
          icon: Icons.people_outline,
          label: 'Customers',
          lastBackup: lastBackups['customers'],
          busy: busyEntity == 'customers',
          enabled: online && busyEntity == null,
          onBackup: () => _backup('customers', 'Customers'),
        ),
        const SizedBox(height: 10),
        _BackupTile(
          icon: Icons.receipt_long_outlined,
          label: 'Invoices',
          lastBackup: lastBackups['invoices'],
          busy: busyEntity == 'invoices',
          enabled: online && busyEntity == null,
          onBackup: () => _backup('invoices', 'Invoices'),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => CloudRestoreScreen(controller: widget.controller),
            ),
          ),
          icon: const Icon(Icons.cloud_download_outlined),
          label: const Text('Get Data from Cloud'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      ],
    ),
  );
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.checking,
    required this.online,
    required this.message,
    required this.onRetry,
  });

  final bool checking;
  final bool online;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: online ? const Color(0xffeaf7ef) : Colors.orange.shade50,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          if (checking)
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              color: online ? Colors.green.shade700 : Colors.orange.shade800,
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              checking
                  ? 'Checking internet and cloud service…'
                  : online
                  ? 'Internet connected. Cloud backup is ready.'
                  : message ?? 'Cloud backup is currently unavailable.',
            ),
          ),
          if (!checking && !online)
            IconButton(
              onPressed: onRetry,
              tooltip: 'Try again',
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
    ),
  );
}

class _BackupTile extends StatelessWidget {
  const _BackupTile({
    required this.icon,
    required this.label,
    required this.lastBackup,
    required this.busy,
    required this.enabled,
    required this.onBackup,
  });

  final IconData icon;
  final String label;
  final DateTime? lastBackup;
  final bool busy;
  final bool enabled;
  final VoidCallback onBackup;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(child: Icon(icon)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  lastBackup == null
                      ? 'Not backed up yet'
                      : 'Last backup: ${DateFormat('dd MMM yyyy, hh:mm a').format(lastBackup!.toLocal())}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: enabled ? onBackup : null,
            child: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Back up'),
          ),
        ],
      ),
    ),
  );
}

class CloudRestoreScreen extends StatefulWidget {
  const CloudRestoreScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CloudRestoreScreen> createState() => _CloudRestoreScreenState();
}

class _CloudRestoreScreenState extends State<CloudRestoreScreen> {
  final service = CloudBackupService();
  bool loading = true;
  bool restoring = false;
  String? restoringStatus;
  String? errorMessageText;
  CloudBackupSummary? summary;
  String selectedType = 'all';
  DateTime? fromDate;
  DateTime? toDate;

  final dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      loading = true;
      errorMessageText = null;
    });
    if (widget.controller.session?.token == null) {
      setState(() {
        loading = false;
        errorMessageText = 'License session is not active.';
      });
      return;
    }
    try {
      final res = await service.fetchSummary(widget.controller.session!.token);
      if (!mounted) return;
      setState(() {
        summary = res;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessageText = errorMessage(e);
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (fromDate ?? now.subtract(const Duration(days: 30)))
          : (toDate ?? now),
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isFrom) {
          fromDate = DateTime(picked.year, picked.month, picked.day);
        } else {
          toDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      });
    }
  }

  Future<void> _restore() async {
    if (widget.controller.session?.token == null) return;
    final typeLabel = switch (selectedType) {
      'all' => 'All Cloud Data (Products, Customers & Invoices)',
      'products' => 'Products',
      'customers' => 'Customers',
      'invoices' => 'Invoices',
      _ => 'Data',
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: Icons.cloud_download_outlined,
        title: Text('Restore $typeLabel?'),
        content: const Text(
          'This will download and restore your cloud records into this device. Existing records will be safely updated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore now'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      restoring = true;
      restoringStatus = 'Connecting to cloud...';
    });

    try {
      final token = widget.controller.session!.token;
      final results = <RestoreReport>[];
      final entities = selectedType == 'all'
          ? ['customers', 'products', 'invoices']
          : [selectedType];

      for (final entity in entities) {
        if (!mounted) return;
        final label = entity[0].toUpperCase() + entity.substring(1);
        setState(() {
          restoringStatus = 'Downloading $label from cloud...';
        });

        final records = await service.pullRecords(
          token: token,
          entity: entity,
          fromDate: selectedType == 'invoices' || selectedType == 'all'
              ? fromDate
              : null,
          toDate: selectedType == 'invoices' || selectedType == 'all'
              ? toDate
              : null,
        );

        if (!mounted) return;
        setState(() {
          restoringStatus =
              'Restoring ${records.length} $entity into local database...';
        });

        final report = await widget.controller.database.restoreCloudRecords(
          entity,
          records,
        );
        results.add(report);
      }

      if (!mounted) return;
      setState(() {
        restoring = false;
        restoringStatus = null;
      });

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AppDialog(
          icon: Icons.check_circle_outline,
          title: const Text('Restore Complete!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The data has been successfully restored:'),
              const SizedBox(height: 12),
              for (final r in results)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    '• ${r.entity[0].toUpperCase()}${r.entity.substring(1)}: ${r.total} records (${r.inserted} new, ${r.updated} updated)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      _loadSummary();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        restoring = false;
        restoringStatus = null;
      });
      showMessage(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = summary?.counts ?? {};
    final totalCloudRecords = (counts['products'] ?? 0) +
        (counts['customers'] ?? 0) +
        (counts['invoices'] ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Data from Cloud'),
        actions: [
          IconButton(
            onPressed: loading || restoring ? null : _loadSummary,
            tooltip: 'Refresh cloud status',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (loading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Checking available cloud records…'),
                  ],
                ),
              ),
            )
          else if (errorMessageText != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessageText!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: _loadSummary,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Card(
              color: const Color(0xfff0f7f4),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud_done, color: Colors.teal.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Cloud Records Found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SummaryRow(
                      icon: Icons.inventory_2_outlined,
                      label: 'Products',
                      count: counts['products'] ?? 0,
                      lastBackup: summary?.lastBackups['products'],
                    ),
                    const Divider(height: 16),
                    _SummaryRow(
                      icon: Icons.people_outline,
                      label: 'Customers',
                      count: counts['customers'] ?? 0,
                      lastBackup: summary?.lastBackups['customers'],
                    ),
                    const Divider(height: 16),
                    _SummaryRow(
                      icon: Icons.receipt_long_outlined,
                      label: 'Invoices',
                      count: counts['invoices'] ?? 0,
                      lastBackup: summary?.lastBackups['invoices'],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select What to Restore',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Data type',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All Data (Products, Customers & Invoices)'),
                ),
                DropdownMenuItem(
                  value: 'products',
                  child: Text('Products only'),
                ),
                DropdownMenuItem(
                  value: 'customers',
                  child: Text('Customers only'),
                ),
                DropdownMenuItem(
                  value: 'invoices',
                  child: Text('Invoices only'),
                ),
              ],
              onChanged: restoring
                  ? null
                  : (value) {
                      if (value != null) setState(() => selectedType = value);
                    },
            ),
            const SizedBox(height: 16),
            if (selectedType == 'invoices' || selectedType == 'all') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          restoring ? null : () => _pickDate(isFrom: true),
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text(
                        fromDate == null
                            ? 'From date: All'
                            : dateFormat.format(fromDate!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          restoring ? null : () => _pickDate(isFrom: false),
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text(
                        toDate == null
                            ? 'To date: All'
                            : dateFormat.format(toDate!),
                      ),
                    ),
                  ),
                ],
              ),
              if (fromDate != null || toDate != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: restoring
                        ? null
                        : () => setState(() {
                              fromDate = null;
                              toDate = null;
                            }),
                    child: const Text('Clear date filters'),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            if (restoring) ...[
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 14),
                      Text(
                        restoringStatus ?? 'Restoring data…',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: totalCloudRecords == 0 ? null : _restore,
                icon: const Icon(Icons.cloud_download),
                label: Text(
                  totalCloudRecords == 0
                      ? 'No Cloud Records to Restore'
                      : 'Restore Data from Cloud',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.count,
    this.lastBackup,
  });

  final IconData icon;
  final String label;
  final int count;
  final DateTime? lastBackup;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (lastBackup != null)
                Text(
                  'Backup: ${DateFormat('dd MMM, hh:mm a').format(lastBackup!.toLocal())}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: count > 0 ? Colors.teal.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: count > 0 ? Colors.teal.shade200 : Colors.grey.shade300,
            ),
          ),
          child: Text(
            '$count records',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: count > 0 ? Colors.teal.shade800 : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }
}
