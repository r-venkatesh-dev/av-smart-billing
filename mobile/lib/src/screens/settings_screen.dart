import 'dart:io';

import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import '../payment_qr_service.dart';
import '../ui_helpers.dart';
import 'editor_dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller, this.drawer});
  final AppController controller;
  final Widget? drawer;

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
      builder: (dialogContext) => AppDialog(
        icon: Icons.vpn_key_off_outlined,
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
    final navigator = Navigator.of(context);
    setState(() => busy = true);
    try {
      await widget.controller.changeActivationKey();
      if (navigator.mounted) {
        navigator.popUntil((route) => route.isFirst);
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
  Widget build(BuildContext context) {
    final session = widget.controller.session;
    if (session == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(height: 14),
              Text('Opening activation screen…'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      drawer: widget.drawer,
      appBar: AppBar(
        backgroundColor: const Color(0xff004d40),
        foregroundColor: Colors.white,
        elevation: 0,
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
          'Business Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: business == null
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                _buildStoreCard(),
                const SizedBox(height: 10),
                _buildQrCodeCard(),
                const SizedBox(height: 10),
                _buildLicenseCard(session),
                const SizedBox(height: 10),
                _buildStorageCard(),
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AV Smart Billing Mobile · v1.0.0',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Secure Offline POS & Enterprise Billing',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _buildStoreCard() {
    final companyName = (business?['company_name'] as String?)?.trim() ?? '';
    final gstin = (business?['gstin'] as String?)?.trim() ?? '';
    final phone = (business?['phone'] as String?)?.trim() ?? '';
    final address = (business?['address'] as String?)?.trim() ?? '';
    final displayName = companyName.isNotEmpty
        ? companyName
        : (widget.controller.session?.customerName.trim().isNotEmpty == true
              ? widget.controller.session!.customerName.trim()
              : 'My Store');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe2e8f0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xffe6f4f2),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: Color(0xff004d40),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff0f172a),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffdcfce7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xff86efac),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  size: 13,
                                  color: Color(0xff15803d),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'VERIFIED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xff15803d),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (gstin.isNotEmpty) ...[
                        Row(
                          children: [
                            const Text(
                              'GSTIN: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff64748b),
                              ),
                            ),
                            Text(
                              gstin,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xff334155),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (phone.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 13,
                              color: Color(0xff64748b),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              phone,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xff475569),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: Color(0xff64748b),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xff64748b),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xfff1f5f9)),
          InkWell(
            onTap: _editBusiness,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 19,
                    color: Color(0xff004d40),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Edit Store Details & Invoice Header',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff004d40),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCodeCard() {
    final qrPath = business?['payment_qr_path'] as String? ?? '';
    final hasQr = qrPath.isNotEmpty && File(qrPath).existsSync();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe2e8f0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xffe6f4f2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: Color(0xff004d40),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'SHOP PAYMENT UPI QR',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff004d40),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasQr
                      ? const Color(0xffdcfce7)
                      : const Color(0xfffef3c7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasQr
                        ? const Color(0xff86efac)
                        : const Color(0xfffde68a),
                  ),
                ),
                child: Text(
                  hasQr ? 'Active on POS' : 'Not Configured',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: hasQr
                        ? const Color(0xff15803d)
                        : const Color(0xffb45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasQr) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xfff8fafc),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(qrPath),
                    width: 190,
                    height: 190,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This QR is presented to customers during checkout for direct UPI payment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xff64748b)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: qrBusy ? null : _uploadQr,
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: Text(qrBusy ? 'Opening…' : 'Change QR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xff004d40),
                      side: const BorderSide(color: Color(0xff004d40)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _removeQr,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xffdc2626),
                      side: const BorderSide(color: Color(0xfffca5a5)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xfff8fafc),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffe2e8f0)),
              ),
              child: const Text(
                'Upload your store\'s UPI QR code (GPay, PhonePe, Paytm, BHIM, etc.). During POS checkout, customers can scan your code directly to pay.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Color(0xff475569),
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: qrBusy ? null : _uploadQr,
              icon: const Icon(Icons.upload_rounded, size: 20),
              label: Text(
                qrBusy ? 'Opening photos…' : 'Upload Shop UPI QR Code',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff004d40),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLicenseCard(LicenseSession session) {
    final validStr = session.validUntil.toLocal().toString().substring(0, 16);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe2e8f0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xfffef3c7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xffb45309),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'DEVICE LICENSE & PLAN',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff004d40),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xfffef3c7), Color(0xfffde68a)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xfff59e0b)),
                ),
                child: Text(
                  session.planName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff92400e),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xfff8fafc),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffe2e8f0)),
            ),
            child: Column(
              children: [
                _buildInfoRow('Licensed To', session.customerName),
                const SizedBox(height: 8),
                _buildInfoRow('Offline Access Until', validStr),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Cloud Backup',
                  session.allowCloudBackup ? 'Enabled' : 'Not Included in Plan',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Reports & Exports',
                  session.allowReportsExports
                      ? 'Enabled'
                      : 'Not Included in Plan',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: busy ? null : _validate,
            icon: busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xff004d40),
                    ),
                  )
                : const Icon(Icons.sync_rounded, size: 18),
            label: const Text('Validate License Online'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xff004d40),
              side: const BorderSide(color: Color(0xff004d40)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : _changeActivationKey,
            icon: const Icon(Icons.vpn_key_off_outlined, size: 18),
            label: const Text('Change Activation Key'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xffdc2626),
              side: const BorderSide(color: Color(0xfffca5a5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe2e8f0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xffe6f4f2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.storage_rounded,
              color: Color(0xff004d40),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'LOCAL ENCRYPTED STORAGE',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800,
                        color: Color(0xff004d40),
                      ),
                    ),
                    Spacer(),
                    Text(
                      '100% Offline',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff15803d),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Products, customers, billing inventory, and invoices are securely stored in your local SQLite database on this phone. Offline operation is fully autonomous.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xff64748b),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xff64748b)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xff1e293b),
            ),
          ),
        ),
      ],
    );
  }
}
