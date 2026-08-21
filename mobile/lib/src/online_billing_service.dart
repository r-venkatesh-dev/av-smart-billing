import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'input_rules.dart';
import 'models.dart';

class OnlineConnectionException implements Exception {
  const OnlineConnectionException();

  @override
  String toString() =>
      'Online Billing requires internet. Please connect to the internet and try again, or switch to Offline Billing.';
}

class OnlineBillingStatus {
  const OnlineBillingStatus({
    required this.businessName,
    required this.lowStockThreshold,
  });

  final String businessName;
  final double lowStockThreshold;
}

class OnlineBillingService {
  OnlineBillingService({http.Client? client})
    : _client = client ?? http.Client();

  static const _apiUrl = String.fromEnvironment(
    'AVSB_API_URL',
    defaultValue: 'https://av-smart-billing.vercel.app',
  );
  final http.Client _client;

  Future<OnlineBillingStatus> status(String token) async {
    final payload = await _request('GET', token, resource: 'status');
    final business = payload['business'] as Map<String, dynamic>;
    return OnlineBillingStatus(
      businessName: business['companyName'] as String,
      lowStockThreshold: (business['lowStockThreshold'] as num).toDouble(),
    );
  }

  Future<List<Product>> products(String token, {String query = ''}) async {
    final payload = await _request(
      'GET',
      token,
      resource: 'products',
      query: query,
    );
    return (payload['products'] as List<dynamic>)
        .map((value) => value as Map<String, dynamic>)
        .map(
          (value) => Product.fromMap({
            'id': value['id'],
            'name': value['name'],
            'sku': value['sku'],
            'barcode': value['barcode'],
            'unit': value['unit'],
            'price_in_paise': value['priceInPaise'],
            'tax_rate_basis_points': value['taxRateBasisPoints'],
            'discount_percent': value['discountPercent'],
            'stock_quantity': value['stockQuantity'],
            'active': value['active'] == true ? 1 : 0,
          }),
        )
        .toList();
  }

  Future<void> saveProduct(
    String token, {
    String? id,
    required String name,
    required String sku,
    required String barcode,
    required String unit,
    required double price,
    required double taxRate,
    required double discountPercent,
    required double stock,
  }) async {
    final cleanUnit = unit.trim();
    if (name.trim().length < 2 ||
        sku.trim().isEmpty ||
        cleanUnit.isEmpty ||
        double.tryParse(cleanUnit) != null ||
        price < 0 ||
        stock < 0 ||
        taxRate < 0 ||
        taxRate > 100 ||
        discountPercent < 0 ||
        discountPercent > 100) {
      throw Exception('Enter valid product details.');
    }
    await _request(
      'PUT',
      token,
      body: {
        'resource': 'product',
        'data': {
          if (id != null) 'id': id,
          'name': name.trim(),
          'sku': sku.trim().toUpperCase(),
          'barcode': barcode.trim(),
          'unit': cleanUnit,
          'priceInPaise': (price * 100).round(),
          'taxRateBasisPoints': (taxRate * 100).round(),
          'discountPercent': discountPercent,
          'stockQuantity': stock,
        },
      },
    );
  }

  Future<void> setProductActive(String token, String id, bool active) =>
      _request(
        'PATCH',
        token,
        body: {'resource': 'product-status', 'id': id, 'active': active},
      );

  Future<void> deleteProduct(String token, String id) =>
      _request('DELETE', token, resource: 'product', id: id);

  Future<List<Customer>> customers(String token) async {
    final payload = await _request('GET', token, resource: 'customers');
    return (payload['customers'] as List<dynamic>)
        .map((value) => value as Map<String, dynamic>)
        .map(
          (value) => Customer.fromMap({
            'id': value['id'],
            'name': value['name'],
            'phone': value['phone'],
            'address': value['address'],
            'gstin': value['gstin'],
          }),
        )
        .toList();
  }

  Future<void> saveCustomer(
    String token, {
    String? id,
    required String name,
    required String phone,
    required String address,
    required String gstin,
  }) async {
    if (name.trim().length < 2) throw Exception('Customer name is required.');
    final phoneError = validateOptionalMobileNumber(phone);
    if (phoneError != null) throw Exception(phoneError);
    await _request(
      'PUT',
      token,
      body: {
        'resource': 'customer',
        'data': {
          if (id != null) 'id': id,
          'name': name.trim(),
          'phone': phone.trim(),
          'address': address.trim(),
          'gstin': gstin.trim().toUpperCase(),
        },
      },
    );
  }

  Future<void> deleteCustomer(String token, String id) =>
      _request('DELETE', token, resource: 'customer', id: id);

  Future<Map<String, dynamic>> _request(
    String method,
    String token, {
    String? resource,
    String? query,
    String? id,
    Map<String, Object?>? body,
  }) async {
    final parameters = <String, String>{
      if (resource != null) 'resource': resource,
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      if (id != null) 'id': id,
    };
    final uri = Uri.parse(
      '$_apiUrl/api/mobile/online',
    ).replace(queryParameters: parameters.isEmpty ? null : parameters);
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'User-Agent': 'AV-Smartbilling-Mobile',
    };
    late http.Response response;
    try {
      response = await switch (method) {
        'PUT' => _client.put(uri, headers: headers, body: jsonEncode(body)),
        'PATCH' => _client.patch(uri, headers: headers, body: jsonEncode(body)),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => _client.get(uri, headers: headers),
      }.timeout(const Duration(seconds: 20));
    } on SocketException {
      throw const OnlineConnectionException();
    } on http.ClientException {
      throw const OnlineConnectionException();
    } on TimeoutException {
      throw const OnlineConnectionException();
    }

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Online billing service returned an invalid response.');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['ok'] != true) {
      throw Exception(payload['message'] ?? 'Online billing request failed.');
    }
    return payload;
  }
}
