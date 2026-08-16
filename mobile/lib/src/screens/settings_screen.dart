import 'package:flutter/material.dart';

import '../app.dart';
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
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
