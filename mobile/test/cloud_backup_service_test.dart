import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:av_smartbilling_mobile/src/cloud_backup_service.dart';

void main() {
  test('fetchSummary parses last backups and record counts', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.headers['Authorization'], 'Bearer mock-token');
      expect(request.url.queryParameters.isEmpty, isTrue);

      return http.Response(
        jsonEncode({
          'ok': true,
          'lastBackups': {
            'products': {'completed_at': '2026-09-01T12:00:00.000Z'},
            'customers': {'completed_at': '2026-09-02T15:30:00.000Z'},
          },
          'counts': {
            'products': 42,
            'customers': 15,
            'invoices': 108,
          },
        }),
        200,
      );
    });

    final service = CloudBackupService(client: client);
    final summary = await service.fetchSummary('mock-token');

    expect(summary.counts['products'], 42);
    expect(summary.counts['customers'], 15);
    expect(summary.counts['invoices'], 108);
    expect(summary.lastBackups['products'], DateTime.parse('2026-09-01T12:00:00.000Z'));
  });

  test('pullRecords sends download parameters and pagination', () async {
    var callCount = 0;
    final client = MockClient((request) async {
      callCount++;
      expect(request.method, 'GET');
      expect(request.headers['Authorization'], 'Bearer mock-token');
      expect(request.url.queryParameters['download'], '1');
      expect(request.url.queryParameters['entity'], 'products');

      if (callCount == 1) {
        expect(request.url.queryParameters['offset'], '0');
        return http.Response(
          jsonEncode({
            'ok': true,
            'records': [
              {
                'localId': 'p-1',
                'updatedAt': '2026-09-01T00:00:00.000Z',
                'payload': {'id': 'p-1', 'name': 'Rice'},
              },
            ],
            'totalCount': 2,
            'hasMore': true,
          }),
          200,
        );
      } else {
        expect(request.url.queryParameters['offset'], '1');
        return http.Response(
          jsonEncode({
            'ok': true,
            'records': [
              {
                'localId': 'p-2',
                'updatedAt': '2026-09-01T00:00:00.000Z',
                'payload': {'id': 'p-2', 'name': 'Wheat'},
              },
            ],
            'totalCount': 2,
            'hasMore': false,
          }),
          200,
        );
      }
    });

    final service = CloudBackupService(client: client);
    final records = await service.pullRecords(
      token: 'mock-token',
      entity: 'products',
    );

    expect(records.length, 2);
    expect(records[0]['name'], 'Rice');
    expect(records[1]['name'], 'Wheat');
    expect(callCount, 2);
  });
}
