import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:deresegn/services/ssl_pinning_service.dart';

void main() {
  test('Fetch All Live Invoices and Update Cache', () async {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.deresegn.com',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    dio.httpClientAdapter = SslPinningService.createPinnedAdapter();

    print('Logging in to branch...');
    final branchRes = await dio.post(
      '/api/branch/login',
      data: {
        'phone_number': '0949384998',
        'password': 'Maru@123',
      },
    );
    final branchToken = branchRes.data['token'];
    final branchId = branchRes.data['branch']['id'].toString();

    print('Fetching invoices from api.deresegn.com...');
    final invoicesRes = await dio.get(
      '/api/invoices',
      queryParameters: {'page': '1'},
      options: Options(
        headers: {
          'Authorization': 'Bearer $branchToken',
          'Branch-Id': branchId,
        },
      ),
    );

    final data = invoicesRes.data;
    List<dynamic> list = [];
    if (data is Map) {
      list = data['data'] ?? data['invoices'] ?? [];
    } else if (data is List) {
      list = data;
    }

    print('Fetched ${list.length} invoices.');
    for (var inv in list) {
      print('Doc: ${inv['document_number']} | Type: ${inv['request_payload']?['DocumentDetails']?['Type']} | Items: ${(inv['items'] as List?)?.length} | Total: ${inv['totals']?['total_value']} | IRN: ${inv['irn']}');
    }

    final cacheFile = File('test/live_invoices_cache.json');
    await cacheFile.writeAsString(const JsonEncoder.withIndent('  ').convert(list));
    print('Updated test/live_invoices_cache.json with ${list.length} invoices.');
  });
}
