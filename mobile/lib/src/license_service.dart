import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'models.dart';

class LicenseService {
  LicenseService({http.Client? client}) : _client = client ?? http.Client();

  static const _storage = FlutterSecureStorage();
  static const _sessionKey = 'avsb_mobile_license_v1';
  static const _installationKey = 'avsb_mobile_installation_v1';
  static const _apiUrl = String.fromEnvironment(
    'AVSB_API_URL',
    defaultValue: 'https://av-smart-billing.vercel.app',
  );
  final http.Client _client;

  Future<LicenseSession?> readActiveSession() async {
    final value = await _storage.read(key: _sessionKey);
    if (value == null) return null;
    try {
      final session = LicenseSession.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
      await _verify(session);
      return session.isActive ? session : null;
    } catch (_) {
      return null;
    }
  }

  Future<String> _fingerprint() async {
    var id = await _storage.read(key: _installationKey);
    if (id == null) {
      id = const Uuid().v4();
      await _storage.write(key: _installationKey, value: id);
    }
    return 'avsb-mobile-installation:$id';
  }

  Future<String> _deviceName() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return '${info.manufacturer} ${info.model}'.trim();
    } catch (_) {
      return 'Android phone';
    }
  }

  Future<LicenseSession> activate(String licenseKey) async {
    final response = await _post('/api/license/activate', {
      'licenseKey': licenseKey.trim().toUpperCase(),
      'deviceFingerprint': await _fingerprint(),
      'deviceName': await _deviceName(),
      'client': 'MOBILE',
    });
    return _saveResponse(response);
  }

  Future<LicenseSession> validate(LicenseSession current) async {
    final response = await _post('/api/license/validate', {
      'deviceId': current.deviceId,
      'deviceFingerprint': await _fingerprint(),
      'client': 'MOBILE',
    });
    return _saveResponse(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$_apiUrl$path'),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'AV-Smartbilling-Mobile',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['ok'] != true) {
      throw Exception(
        payload['message'] ??
            'The activation server could not complete this request.',
      );
    }
    return payload;
  }

  Future<LicenseSession> _saveResponse(Map<String, dynamic> response) async {
    final grant = response['grant'] as Map<String, dynamic>;
    final signed = response['signed'] as Map<String, dynamic>;
    final session = LicenseSession(
      token: signed['token'] as String,
      publicKey: signed['publicKey'] as String,
      issuer: signed['issuer'] as String,
      deviceId: grant['deviceId'] as String,
      customerName: grant['customerName'] as String,
      planName: grant['planName'] as String,
      expiresAt: DateTime.parse(grant['expiresAt'] as String),
      validUntil: DateTime.parse(signed['validUntil'] as String),
    );
    await _verify(session);
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
    return session;
  }

  Future<void> _verify(LicenseSession session) async {
    final parts = session.token.split('.');
    if (parts.length != 3) {
      throw const FormatException('Invalid signed license grant.');
    }
    final header =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))))
            as Map<String, dynamic>;
    final payload =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
            as Map<String, dynamic>;
    if (header['alg'] != 'EdDSA' ||
        payload['type'] != 'av-smartbilling-license' ||
        payload['iss'] != session.issuer ||
        payload['aud'] != 'av-smartbilling-mobile' ||
        payload['deviceId'] != session.deviceId) {
      throw const FormatException(
        'License grant does not belong to this mobile application.',
      );
    }
    final spki = base64Url.decode(base64Url.normalize(session.publicKey));
    if (spki.length < 32) {
      throw const FormatException('Invalid license public key.');
    }
    final publicKey = SimplePublicKey(
      spki.sublist(spki.length - 32),
      type: KeyPairType.ed25519,
    );
    final signature = Signature(
      base64Url.decode(base64Url.normalize(parts[2])),
      publicKey: publicKey,
    );
    final valid = await Ed25519().verify(
      utf8.encode('${parts[0]}.${parts[1]}'),
      signature: signature,
    );
    final expiration = DateTime.fromMillisecondsSinceEpoch(
      (payload['exp'] as num).toInt() * 1000,
    );
    if (!valid || DateTime.now().isAfter(expiration)) {
      throw const FormatException('License grant has expired or is invalid.');
    }
  }
}
