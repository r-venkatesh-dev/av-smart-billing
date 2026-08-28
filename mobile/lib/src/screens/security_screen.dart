import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../security_service.dart';
import '../ui_helpers.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool loading = true;
  bool enabled = false;
  bool biometricAvailable = false;
  bool biometricEnabled = false;
  bool legacyPin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabledValue = await widget.controller.security.enabled;
    final biometricAvailableValue =
        await widget.controller.security.biometricAvailable;
    final biometricEnabledValue =
        await widget.controller.security.biometricEnabled;
    final configuredPinLength =
        await widget.controller.security.configuredPinLength;
    if (!mounted) return;
    setState(() {
      enabled = enabledValue;
      biometricAvailable = biometricAvailableValue;
      biometricEnabled = biometricEnabledValue;
      legacyPin = enabledValue && configuredPinLength == null;
      loading = false;
    });
  }

  Future<String?> _askPin({
    required String title,
    bool confirm = false,
    bool allowLegacy = false,
  }) => showDialog<String>(
    context: context,
    builder: (_) =>
        AppPinDialog(title: title, confirm: confirm, allowLegacy: allowLegacy),
  );

  Future<void> _enable() async {
    final pin = await _askPin(title: 'Create App PIN', confirm: true);
    if (pin == null || !mounted) return;
    await widget.controller.security.enable(
      pin: pin,
      useBiometric: biometricAvailable,
    );
    if (!mounted) return;
    setState(() {
      enabled = true;
      biometricEnabled = biometricAvailable;
      legacyPin = false;
    });
    showMessage(context, 'App lock enabled.');
  }

  Future<void> _disable() async {
    final pin = await _askPin(
      title: 'Enter current PIN',
      allowLegacy: legacyPin,
    );
    if (pin == null || !mounted) return;
    if (!await widget.controller.security.verifyPin(pin)) {
      if (mounted) showMessage(context, 'Incorrect PIN.', error: true);
      return;
    }
    await widget.controller.security.disable();
    if (!mounted) return;
    setState(() {
      enabled = false;
      biometricEnabled = false;
      legacyPin = false;
    });
    showMessage(context, 'App lock disabled.');
  }

  Future<void> _changePin() async {
    final current = await _askPin(
      title: 'Enter current PIN',
      allowLegacy: legacyPin,
    );
    if (current == null || !mounted) return;
    if (!await widget.controller.security.verifyPin(current)) {
      if (mounted) showMessage(context, 'Incorrect PIN.', error: true);
      return;
    }
    if (!mounted) return;
    final next = await _askPin(title: 'Create New PIN', confirm: true);
    if (next == null || !mounted) return;
    await widget.controller.security.changePin(next);
    if (mounted) {
      setState(() => legacyPin = false);
      showMessage(context, 'App PIN changed.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('App Lock & Security')),
    body: loading
        ? const LoadingView()
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: SwitchListTile(
                  value: enabled,
                  onChanged: (value) => value ? _enable() : _disable(),
                  secondary: const Icon(Icons.lock_outline),
                  title: const Text('App lock'),
                  subtitle: const Text(
                    'Require a PIN when AV Smartbilling is opened.',
                  ),
                ),
              ),
              if (enabled) ...[
                if (legacyPin) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Color(0xfffff7e6),
                    child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Update your PIN'),
                      subtitle: Text(
                        'Change the PIN once to apply the new mandatory 6-digit security rule.',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: biometricEnabled,
                        onChanged: biometricAvailable
                            ? (value) async {
                                await widget.controller.security.setBiometric(
                                  value,
                                );
                                if (mounted) {
                                  setState(() => biometricEnabled = value);
                                }
                              }
                            : null,
                        secondary: const Icon(Icons.fingerprint),
                        title: const Text('Fingerprint unlock'),
                        subtitle: Text(
                          biometricAvailable
                              ? 'Use enrolled biometrics for quick unlock.'
                              : 'No enrolled fingerprint or biometric found.',
                        ),
                      ),
                      const Divider(height: 1, indent: 72),
                      ListTile(
                        leading: const Icon(Icons.password_outlined),
                        title: const Text('Change PIN'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _changePin,
                      ),
                      const Divider(height: 1, indent: 72),
                      ListTile(
                        leading: const Icon(Icons.lock_clock_outlined),
                        title: const Text('Lock now'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(context);
                          widget.controller.lockNow();
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xff057c73)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your PIN is stored as a salted one-way hash in Android secure storage. AV Smartbilling never stores the readable PIN.',
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

class AppPinDialog extends StatefulWidget {
  const AppPinDialog({
    super.key,
    required this.title,
    required this.confirm,
    required this.allowLegacy,
  });

  final String title;
  final bool confirm;
  final bool allowLegacy;

  @override
  State<AppPinDialog> createState() => _AppPinDialogState();
}

class _AppPinDialogState extends State<AppPinDialog> {
  final first = TextEditingController();
  final second = TextEditingController();
  final form = GlobalKey<FormState>();
  String? mismatchError;

  @override
  void dispose() {
    first.dispose();
    second.dispose();
    super.dispose();
  }

  void _continue() {
    setState(() => mismatchError = null);
    if (!form.currentState!.validate()) return;
    if (widget.confirm && first.text != second.text) {
      setState(() => mismatchError = 'PIN confirmation does not match.');
      return;
    }
    Navigator.pop(context, first.text);
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    icon: Icons.lock_outline_rounded,
    title: Text(widget.title),
    content: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PinField(
            controller: first,
            label: widget.confirm ? 'New 6-digit PIN' : 'PIN',
            allowLegacy: widget.allowLegacy,
          ),
          if (widget.confirm) ...[
            const SizedBox(height: 12),
            _PinField(controller: second, label: 'Confirm 6-digit PIN'),
          ],
          if (mismatchError != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                mismatchError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _continue, child: const Text('Continue')),
    ],
  );
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.label,
    this.allowLegacy = false,
  });
  final TextEditingController controller;
  final String label;
  final bool allowLegacy;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: true,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(6),
    ],
    decoration: InputDecoration(labelText: label),
    validator: (value) => allowLegacy
        ? RegExp(r'^\d{4,6}$').hasMatch(value ?? '')
              ? null
              : 'Enter your existing PIN.'
        : validateNewAppPin(value),
  );
}
