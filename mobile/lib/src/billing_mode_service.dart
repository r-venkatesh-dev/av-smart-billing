import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum BillingMode { offline, online }

class BillingModeService {
  const BillingModeService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'avsb_mobile_billing_mode_v1';
  final FlutterSecureStorage _storage;

  Future<BillingMode> read() async {
    final value = await _storage.read(key: _key);
    return value == BillingMode.online.name
        ? BillingMode.online
        : BillingMode.offline;
  }

  Future<void> save(BillingMode mode) =>
      _storage.write(key: _key, value: mode.name);
}
