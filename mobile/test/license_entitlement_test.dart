import 'package:flutter_test/flutter_test.dart';
import 'package:av_smartbilling_mobile/src/models.dart';

void main() {
  Map<String, Object?> storedSession() => {
    'token': 'header.payload.signature',
    'publicKey': 'public-key',
    'issuer': 'https://licenses.example.test',
    'deviceId': 'device-id',
    'customerName': 'Test Shop',
    'planName': 'Test Plan',
    'expiresAt': '2027-01-01T00:00:00.000Z',
    'validUntil': '2027-01-01T00:00:00.000Z',
    'allowOnlineBilling': false,
    'allowCloudBackup': false,
  };

  test('older stored sessions retain reports access by default', () {
    final session = LicenseSession.fromJson(storedSession());

    expect(session.allowReportsExports, isTrue);
  });

  test('reports entitlement is persisted when disabled', () {
    final session = LicenseSession.fromJson({
      ...storedSession(),
      'allowReportsExports': false,
    });

    expect(session.allowReportsExports, isFalse);
    expect(session.toJson()['allowReportsExports'], isFalse);
  });
}
