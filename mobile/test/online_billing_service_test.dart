import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:av_smartbilling_mobile/src/models.dart';
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

  test('loads online invoices and single invoice details', () async {
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer license-token');
      switch (request.url.queryParameters['resource']) {
        case 'invoices':
          return http.Response(
            jsonEncode({
              'ok': true,
              'invoices': [
                {
                  'id': 'inv-1',
                  'invoiceNumber': 'INV-000001',
                  'customerName': 'Ramesh Kumar',
                  'issuedAt': '2026-10-10T12:00:00.000Z',
                  'totalInPaise': 15000,
                  'status': 'PAID',
                },
              ],
            }),
            200,
          );
        case 'invoice':
          expect(request.url.queryParameters['id'], 'inv-1');
          return http.Response(
            jsonEncode({
              'ok': true,
              'invoice': {
                'id': 'inv-1',
                'invoice_number': 'INV-000001',
                'customer_name': 'Ramesh Kumar',
                'total_in_paise': 15000,
                'status': 'PAID',
              },
              'items': [
                {
                  'product_name': 'Item A',
                  'quantity': 2,
                  'total_in_paise': 15000,
                },
              ],
              'business': {
                'company_name': 'AV Stores',
              },
            }),
            200,
          );
      }
      return http.Response('{}', 404);
    });

    final service = OnlineBillingService(client: client);
    final summaries = await service.invoices('license-token');
    final detail = await service.invoice('license-token', 'inv-1');

    expect(summaries.single.invoiceNumber, 'INV-000001');
    expect(summaries.single.totalInPaise, 15000);
    expect(detail.invoice['invoice_number'], 'INV-000001');
    expect(detail.items.single['product_name'], 'Item A');
  });

  test('creates online POS sale with items and discounts', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload['resource'], 'pos-sale');
      final data = payload['data'] as Map<String, dynamic>;
      expect(data['walkInName'], 'Walk-in Customer');
      expect(data['paymentMethod'], 'CASH');
      expect(data['overallDiscountPercent'], 10);
      final items = data['items'] as List<dynamic>;
      expect(items.length, 1);
      return http.Response(
        jsonEncode({
          'ok': true,
          'invoiceId': 'new-invoice-id',
          'invoiceNumber': 'INV-000042',
          'totalInPaise': 27000,
        }),
        200,
      );
    });

    final service = OnlineBillingService(client: client);
    final result = await service.createPosSale(
      'license-token',
      walkInName: 'Walk-in Customer',
      walkInPhone: '',
      lines: [
        CartLine(
          product: Product.fromMap({
            'id': 'p-1',
            'name': 'Widget',
            'sku': 'W-1',
            'barcode': '',
            'unit': 'pcs',
            'price_in_paise': 30000,
            'tax_rate_basis_points': 0,
            'discount_percent': 0,
            'stock_quantity': 10,
            'active': 1,
          }),
          discountPercent: 0,
          quantity: 1,
        ),
      ],
      paymentMethod: 'CASH',
      overallDiscountPercent: 10,
    );

    expect(result.invoiceId, 'new-invoice-id');
    expect(result.invoiceNumber, 'INV-000042');
    expect(result.totalInPaise, 27000);
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
