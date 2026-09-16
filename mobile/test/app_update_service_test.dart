import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:av_smartbilling_mobile/src/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppUpdateService', () {
    test('detects available update correctly', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/mobile/version');
        expect(request.url.queryParameters['platform'], 'android');

        return http.Response(
          jsonEncode({
            'ok': true,
            'platform': 'android',
            'latestVersion': '1.0.1',
            'latestBuildNumber': 10,
            'minRequiredBuild': 1,
            'releaseNotes': 'Faster invoice printing and bug fixes.',
            'updateUrl': 'https://play.google.com/store/apps/details?id=in.avsmartbilling.mobile',
          }),
          200,
        );
      });

      final service = AppUpdateService(client: mockClient);
      final result = await service.checkForUpdate(manual: true);

      expect(result, isNotNull);
      expect(result!.hasUpdate, isTrue);
      expect(result.isForceUpdate, isFalse);
      expect(result.latestVersion, '1.0.1');
      expect(result.latestBuildNumber, 10);
      expect(result.releaseNotes, 'Faster invoice printing and bug fixes.');
    });

    test('detects mandatory force update when local build is below minRequiredBuild', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'ok': true,
            'platform': 'android',
            'latestVersion': '2.0.0',
            'latestBuildNumber': 20,
            'minRequiredBuild': 15,
            'releaseNotes': 'Critical database migration update.',
            'updateUrl': 'https://play.google.com/store/apps/details?id=in.avsmartbilling.mobile',
          }),
          200,
        );
      });

      final service = AppUpdateService(client: mockClient);
      final result = await service.checkForUpdate(manual: true);

      expect(result, isNotNull);
      expect(result!.hasUpdate, isTrue);
      expect(result.isForceUpdate, isTrue);
      expect(result.minRequiredBuild, 15);
    });

    test('returns null silently on background offline failure', () async {
      final mockClient = MockClient((_) async {
        throw const SocketException('No route to host');
      });

      final service = AppUpdateService(client: mockClient);
      // Background check (manual: false) must not throw
      final result = await service.checkForUpdate(manual: false);
      expect(result, isNull);
    });

    test('throws descriptive message on manual offline failure', () async {
      final mockClient = MockClient((_) async {
        throw const SocketException('No route to host');
      });

      final service = AppUpdateService(client: mockClient);
      // Manual check must throw so UI shows user-friendly message
      expect(
        () => service.checkForUpdate(manual: true),
        throwsA(isA<Exception>()),
      );
    });
  });
}
