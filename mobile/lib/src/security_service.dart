import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

String? validateNewAppPin(String? value) =>
    RegExp(r'^\d{6}$').hasMatch(value ?? '') ? null : 'Enter exactly 6 digits.';

class SecurityService {
  static const _storage = FlutterSecureStorage();
  static const _enabledKey = 'avsb_app_lock_enabled_v1';
  static const _biometricKey = 'avsb_app_lock_biometric_v1';
  static const _pinHashKey = 'avsb_app_lock_pin_hash_v1';
  static const _pinSaltKey = 'avsb_app_lock_pin_salt_v1';
  static const _pinLengthKey = 'avsb_app_lock_pin_length_v1';
  final _auth = LocalAuthentication();

  Future<bool> get enabled async =>
      await _storage.read(key: _enabledKey) == 'true';

  Future<bool> get biometricEnabled async =>
      await _storage.read(key: _biometricKey) == 'true';

  Future<int?> get configuredPinLength async =>
      int.tryParse(await _storage.read(key: _pinLengthKey) ?? '');

  Future<bool> get biometricAvailable async {
    try {
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> enable({required String pin, required bool useBiometric}) async {
    _validatePin(pin);
    await _savePin(pin);
    await Future.wait([
      _storage.write(key: _enabledKey, value: 'true'),
      _storage.write(key: _biometricKey, value: '$useBiometric'),
    ]);
  }

  Future<void> changePin(String pin) async {
    _validatePin(pin);
    await _savePin(pin);
  }

  Future<void> setBiometric(bool value) =>
      _storage.write(key: _biometricKey, value: '$value');

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _pinSaltKey);
    final expected = await _storage.read(key: _pinHashKey);
    if (salt == null || expected == null) return false;
    return Mac(base64Url.decode(await _hash(pin, base64Url.decode(salt)))) ==
        Mac(base64Url.decode(expected));
  }

  Future<bool> authenticateBiometric() async {
    if (!await biometricEnabled || !await biometricAvailable) return false;
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock AV Smartbilling',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> disable() async {
    await Future.wait([
      _storage.delete(key: _enabledKey),
      _storage.delete(key: _biometricKey),
      _storage.delete(key: _pinHashKey),
      _storage.delete(key: _pinSaltKey),
      _storage.delete(key: _pinLengthKey),
    ]);
  }

  Future<void> _savePin(String pin) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    await Future.wait([
      _storage.write(key: _pinSaltKey, value: base64UrlEncode(salt)),
      _storage.write(key: _pinHashKey, value: await _hash(pin, salt)),
      _storage.write(key: _pinLengthKey, value: '${pin.length}'),
    ]);
  }

  Future<String> _hash(String pin, List<int> salt) async {
    final key = await Pbkdf2.hmacSha256(
      iterations: 100000,
      bits: 256,
    ).deriveKeyFromPassword(password: pin, nonce: salt);
    return base64UrlEncode(await key.extractBytes());
  }

  void _validatePin(String pin) {
    final error = validateNewAppPin(pin);
    if (error != null) {
      throw Exception('PIN must contain exactly 6 digits.');
    }
  }
}
