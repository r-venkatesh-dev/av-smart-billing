import 'package:flutter/material.dart';

import '../app_update_service.dart';
import '../ui_helpers.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final _updateService = AppUpdateService();
  AppVersionInfo? _versionInfo;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await _updateService.getCurrentVersionInfo();
    if (mounted) {
      setState(() => _versionInfo = info);
    }
  }

  Future<void> _manualCheckForUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);

    try {
      final result = await _updateService.checkForUpdate(manual: true);
      if (!mounted) return;

      if (result != null && result.hasUpdate) {
        await _updateService.showUpdateDialog(context, result);
      } else {
        final version = result?.currentVersion ?? _versionInfo?.versionName ?? '1.0.0';
        showMessage(
          context,
          "You're already using the latest version (v$version).",
        );
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, errorMessage(e), error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('About App')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              'assets/branding/app-logo.png',
              width: 112,
              height: 112,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'AV Smartbilling',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          _versionInfo != null
              ? 'Version ${_versionInfo!.versionName} (${_versionInfo!.buildNumber})'
              : 'Version 1.0.0',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 14),
        Center(
          child: OutlinedButton.icon(
            onPressed: _checking ? null : _manualCheckForUpdate,
            icon: _checking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(_checking ? 'Checking...' : 'Check for Updates'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Simple billing, even without internet',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'AV Smartbilling is an offline-first billing app for creating invoices, managing products and customers, and tracking everyday sales from your Android phone.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.cloud_off_outlined),
                title: Text('Offline-first'),
                subtitle: Text(
                  'Keep billing when the internet is unavailable.',
                ),
              ),
              Divider(height: 1, indent: 72),
              ListTile(
                leading: Icon(Icons.qr_code_scanner),
                title: Text('Fast barcode scanning'),
                subtitle: Text('Scan products directly into a new bill.'),
              ),
              Divider(height: 1, indent: 72),
              ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Data stays on this phone'),
                subtitle: Text(
                  'Product, customer and invoice data is stored locally.',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
