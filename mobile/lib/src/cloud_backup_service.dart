import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

class CloudConnectionException implements Exception {
  const CloudConnectionException();
}

class CloudBackupResult {
  const CloudBackupResult({
    required this.received,
    required this.inserted,
    required this.updated,
    required this.unchanged,
    required this.backedUpAt,
  });

  final int received;
  final int inserted;
  final int updated;
  final int unchanged;
  final DateTime backedUpAt;
}

class CloudBackupSummary {
  const CloudBackupSummary({
    required this.lastBackups,
    required this.counts,
  });

  final Map<String, DateTime> lastBackups;
  final Map<String, int> counts;
}

class CloudBackupService {
  CloudBackupService({http.Client? client}) : _client = client ?? http.Client();

  static const _apiUrl = String.fromEnvironment(
    'AVSB_API_URL',
    defaultValue: 'https://av-smart-billing.vercel.app',
  );
  final http.Client _client;

  Future<CloudBackupSummary> fetchSummary(String token) async {
    final payload = await _request('GET', token);
    final statuses = payload['lastBackups'] as Map<String, dynamic>? ?? {};
    final rawCounts = payload['counts'] as Map<String, dynamic>? ?? {};
    final lastBackups = statuses.map(
      (key, value) => MapEntry(
        key,
        DateTime.parse(
          (value as Map<String, dynamic>)['completed_at'] as String,
        ),
      ),
    );
    final counts = rawCounts.map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );
    return CloudBackupSummary(lastBackups: lastBackups, counts: counts);
  }

  Future<Map<String, DateTime>> status(String token) async {
    final summary = await fetchSummary(token);
    return summary.lastBackups;
  }

  Future<List<Map<String, dynamic>>> pullRecords({
    required String token,
    required String entity,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final allRecords = <Map<String, dynamic>>[];
    var offset = 0;
    const limit = 500;
    var hasMore = true;

    while (hasMore) {
      final queryParams = <String, String>{
        'download': '1',
        'entity': entity,
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (fromDate != null) {
        queryParams['fromDate'] = fromDate.toUtc().toIso8601String();
      }
      if (toDate != null) {
        queryParams['toDate'] = toDate.toUtc().toIso8601String();
      }

      final payload = await _request(
        'GET',
        token,
        queryParams: queryParams,
      );

      final rawList = payload['records'] as List<dynamic>? ?? [];
      for (final item in rawList) {
        final map = item as Map<String, dynamic>;
        final payloadData = map['payload'] as Map<String, dynamic>;
        allRecords.add(payloadData);
      }

      hasMore = payload['hasMore'] as bool? ?? false;
      offset += rawList.length;
      if (rawList.isEmpty) break;
    }

    return allRecords;
  }

  Future<CloudBackupResult> push({
    required String token,
    required String entity,
    required List<CloudBackupRecord> records,
  }) async {
    var received = 0;
    var inserted = 0;
    var updated = 0;
    var unchanged = 0;
    DateTime? backedUpAt;
    final chunks = <List<CloudBackupRecord>>[];
    if (records.isEmpty) {
      chunks.add(const []);
    } else {
      for (var start = 0; start < records.length; start += 250) {
        chunks.add(
          records.sublist(start, (start + 250).clamp(0, records.length)),
        );
      }
    }
    for (final chunk in chunks) {
      final payload = await _request(
        'PUT',
        token,
        body: {
          'entity': entity,
          'records': chunk.map((record) => record.toJson()).toList(),
        },
      );
      received += payload['received'] as int;
      inserted += payload['inserted'] as int;
      updated += payload['updated'] as int;
      unchanged += payload['unchanged'] as int;
      backedUpAt = DateTime.parse(payload['backedUpAt'] as String);
    }
    return CloudBackupResult(
      received: received,
      inserted: inserted,
      updated: updated,
      unchanged: unchanged,
      backedUpAt: backedUpAt!,
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String token, {
    Map<String, Object?>? body,
    Map<String, String>? queryParams,
  }) async {
    var uri = Uri.parse('$_apiUrl/api/mobile/backup');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'User-Agent': 'AV-Smartbilling-Mobile',
    };
    late http.Response response;
    try {
      response =
          await (method == 'PUT'
                  ? _client.put(uri, headers: headers, body: jsonEncode(body))
                  : _client.get(uri, headers: headers))
              .timeout(const Duration(seconds: 20));
    } on SocketException {
      throw const CloudConnectionException();
    } on http.ClientException {
      throw const CloudConnectionException();
    }
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Cloud backup service returned an invalid response.');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['ok'] != true) {
      throw Exception(payload['message'] ?? 'Cloud backup failed.');
    }
    return payload;
  }
}
