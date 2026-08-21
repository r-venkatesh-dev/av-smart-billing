import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:av_smartbilling_mobile/src/online_billing_service.dart';

void main() {
  test('loads online status and products using the licensed API', () async {
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer license-token');
      switch (request.url.queryParameters['resource']) {
        case 'status':
          return http.Response(
            jsonEncode({
              'ok': true,
              'business': {
                'id': 'business-id',
                'companyName': 'AV Stores',
                'lowStockThreshold': 4,
              },
            }),
            200,
          );
        case 'products':
          expect(request.url.queryParameters['query'], 'soap');
          return http.Response(
            jsonEncode({
              'ok': true,
              'products': [
                {
                  'id': 'product-id',
                  'name': 'Soap',
                  'sku': 'SOAP-1',
                  'barcode': '',
                  'unit': 'pcs',
                  'priceInPaise': 5000,
                  'taxRateBasisPoints': 1800,
                  'discountPercent': 5,
                  'stockQuantity': 3,
                  'active': true,
                },
              ],
            }),
            200,
          );
      }
      return http.Response('{}', 404);
    });
    final service = OnlineBillingService(client: client);

    final status = await service.status('license-token');
    final products = await service.products('license-token', query: 'soap');

    expect(status.businessName, 'AV Stores');
    expect(status.lowStockThreshold, 4);
    expect(products.single.name, 'Soap');
    expect(products.single.discountPercent, 5);
    expect(products.single.active, isTrue);
  });

  test('sends product changes only to the online API', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PUT');
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload['resource'], 'product');
      final data = payload['data'] as Map<String, dynamic>;
      expect(data['sku'], 'SKU-1');
      expect(data['priceInPaise'], 1099);
      expect(data['discountPercent'], 2.5);
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final service = OnlineBillingService(client: client);

    await service.saveProduct(
      'license-token',
      name: 'Online product',
      sku: 'sku-1',
      barcode: '',
      unit: 'pcs',
      price: 10.99,
      taxRate: 5,
      discountPercent: 2.5,
      stock: 8,
    );
  });

  test('returns a clear connection error when the server is unreachable', () {
    final service = OnlineBillingService(
      client: MockClient((_) => throw http.ClientException('offline')),
    );

    expect(
      () => service.status('license-token'),
      throwsA(isA<OnlineConnectionException>()),
    );
  });
}
