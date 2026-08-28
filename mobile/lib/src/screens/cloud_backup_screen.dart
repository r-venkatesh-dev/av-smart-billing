import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../cloud_backup_service.dart';
import '../ui_helpers.dart';

class CloudBackupScreen extends StatefulWidget {
  const CloudBackupScreen({super.key, required this.controller});

  final AppController controller;

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
    appBar: AppBar(
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
            MaterialPageRoute<void>(builder: (_) => const CloudRestoreScreen()),
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

class CloudRestoreScreen extends StatelessWidget {
  const CloudRestoreScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Get Data from Cloud')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xfffff7e6),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.construction_outlined,
                  size: 40,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(height: 12),
                Text(
                  'Cloud restore is coming soon',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Selecting Products, Customers or Invoices and restoring by date range will be available in an upcoming phase.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const DropdownMenu<String>(
          enabled: false,
          expandedInsets: EdgeInsets.zero,
          label: Text('Data type'),
          dropdownMenuEntries: [
            DropdownMenuEntry(value: 'products', label: 'Products'),
            DropdownMenuEntry(value: 'customers', label: 'Customers'),
            DropdownMenuEntry(value: 'invoices', label: 'Invoices'),
          ],
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(
              child: TextField(
                enabled: false,
                decoration: InputDecoration(labelText: 'From date'),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: TextField(
                enabled: false,
                decoration: InputDecoration(labelText: 'To date'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
