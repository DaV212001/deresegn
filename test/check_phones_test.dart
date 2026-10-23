import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:deresegn/services/ssl_pinning_service.dart';

void main() {
  test('Check both phone numbers', () async {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.deresegn.com',
        connectTimeout: const Duration(seconds: 30),
      ),
    );
    dio.httpClientAdapter = SslPinningService.createPinnedAdapter();

    print('Testing 0949384998:');
    try {
      final res1 = await dio.post(
        '/api/branch/login',
        data: {
          'phone_number': '0949384998',
          'password': 'Maru@123',
        },
      );
      print('0949384998 branch: ${res1.data['branch']}');
    } catch (e) {
      if (e is DioException) {
        print('0949384998 failed: ${e.response?.data}');
      }
    }

    print('\nTesting 0949389498:');
    try {
      final res2 = await dio.post(
        '/api/branch/login',
        data: {
          'phone_number': '0949389498',
          'password': 'Maru@123',
        },
      );
      print('0949389498 branch: ${res2.data['branch']}');
    } catch (e) {
      if (e is DioException) {
        print('0949389498 failed: ${e.response?.data}');
      }
    }
  });
}
