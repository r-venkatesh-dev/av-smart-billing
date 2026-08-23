import 'dart:io';

import 'package:flutter/material.dart';

import '../app.dart';
import '../payment_qr_service.dart';
import '../ui_helpers.dart';
import 'editor_dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, Object?>? business;
  bool busy = false;
  bool qrBusy = false;
  final qrService = PaymentQrService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await widget.controller.database.getBusiness();
    if (mounted) setState(() => business = value);
  }

  Future<void> _editBusiness() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => BusinessEditorDialog(
        business: business!,
        onSave: widget.controller.database.saveBusiness,
      ),
    );
    if (mounted && saved == true) {
      await _load();
      await widget.controller.checkLowStock();
    }
  }

  Future<void> _validate() async {
    setState(() => busy = true);
    try {
      await widget.controller.validateLicense();
      if (mounted) showMessage(context, 'License validated successfully.');
    } catch (error) {
      if (mounted) {
        showMessage(context, errorMessage(error), error: true);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _changeActivationKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change activation key?'),
        content: const Text(
          'This will sign out the current license and return to the activation screen. Products, customers, invoices, held bills and business settings stored on this phone will remain safe.\n\nAny items in the current unheld sale may be cleared. Internet is required to activate the new key.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep current key'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Change key'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.controller.changeActivationKey();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _uploadQr() async {
    if (qrBusy) return;
    setState(() => qrBusy = true);
    try {
      final filePath = await qrService.pickAndStore();
      if (filePath == null) return;
      await widget.controller.database.saveBusiness({
        'payment_qr_path': filePath,
      });
      await _load();
      if (mounted) showMessage(context, 'Shop payment QR code saved.');
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => qrBusy = false);
    }
  }

  Future<void> _removeQr() async {
    final current = business!['payment_qr_path'] as String? ?? '';
    await qrService.remove(current);
    await widget.controller.database.saveBusiness({'payment_qr_path': ''});
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Business Settings')),
    body: business == null
        ? const LoadingView()
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  leading: const CircleAvatar(child: Icon(Icons.store)),
                  title: Text(
                    business!['company_name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    [
                      business!['gstin'] as String,
                      business!['phone'] as String,
                    ].where((value) => value.isNotEmpty).join(' · '),
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: _editBusiness,
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.qr_code_2, color: Color(0xff057c73)),
                          SizedBox(width: 10),
                          Text(
                            'SHOP PAYMENT QR CODE',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if ((business!['payment_qr_path'] as String? ?? '')
                              .isNotEmpty &&
                          File(
                            business!['payment_qr_path'] as String,
                          ).existsSync()) ...[
                        Center(
                          child: Image.file(
                            File(business!['payment_qr_path'] as String),
                            width: 210,
                            height: 210,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: qrBusy ? null : _uploadQr,
                                icon: const Icon(Icons.image_outlined),
                                label: Text(qrBusy ? 'Opening…' : 'Replace'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _removeQr,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Remove'),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Text(
                          'Upload the shop owner’s UPI QR code. It will be shown during QR payment checkout.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: qrBusy ? null : _uploadQr,
                          icon: const Icon(Icons.upload),
                          label: Text(
                            qrBusy ? 'Opening photos…' : 'Upload QR code',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DEVICE LICENSE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.controller.session!.planName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Licensed to ${widget.controller.session!.customerName}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Offline access until ${widget.controller.session!.validUntil.toLocal().toString().substring(0, 16)}',
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: busy ? null : _validate,
                        icon: busy
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync),
                        label: const Text('Validate license online'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: busy ? null : _changeActivationKey,
                        icon: const Icon(Icons.key_outlined),
                        label: const Text('Change activation key'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.storage, color: Color(0xff057c73)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Offline data',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Products, customers and invoices are stored only on this phone in this first release. Cloud backup will be added as the next milestone.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'AV Smartbilling Mobile · 1.0.0',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
  );
}
