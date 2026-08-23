import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final pin = TextEditingController();
  bool busy = false;
  bool biometricAvailable = false;
  int minimumPinLength = 6;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  @override
  void dispose() {
    pin.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    final available =
        await widget.controller.security.biometricAvailable &&
        await widget.controller.security.biometricEnabled;
    final configuredLength =
        await widget.controller.security.configuredPinLength;
    if (!mounted) return;
    setState(() {
      biometricAvailable = available;
      minimumPinLength = configuredLength ?? 4;
    });
    if (available) await _biometric();
  }

  Future<void> _unlock() async {
    if (pin.text.length < minimumPinLength || pin.text.length > 6) {
      setState(() => error = 'Enter your complete PIN.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final valid = await widget.controller.unlockWithPin(pin.text);
    if (!mounted || valid) return;
    setState(() {
      busy = false;
      error = 'Incorrect PIN. Please try again.';
      pin.clear();
    });
  }

  Future<void> _biometric() async {
    setState(() {
      busy = true;
      error = null;
    });
    final valid = await widget.controller.unlockWithBiometric();
    if (!mounted || valid) return;
    setState(() {
      busy = false;
      error = 'Fingerprint authentication was not completed.';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/branding/app-logo.png',
                      width: 88,
                      height: 88,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'AV Smartbilling is locked',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your app PIN to continue.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: pin,
                  autofocus: !biometricAvailable,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onSubmitted: (_) => _unlock(),
                  onChanged: (_) {
                    if (error != null) setState(() => error = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'App PIN',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: busy ? null : _unlock,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Unlock'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                if (biometricAvailable) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _biometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use fingerprint'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
