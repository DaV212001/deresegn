import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:deresegn/services/ssl_pinning_service.dart';

void main() {
  test('Test /api/login endpoint', () async {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.deresegn.com',
        connectTimeout: const Duration(seconds: 30),
      ),
    );
    dio.httpClientAdapter = SslPinningService.createPinnedAdapter();

    print('1. Logging into branch...');
    Response branchRes;
    try {
      branchRes = await dio.post(
        '/api/branch/login',
        data: {
          'phone_number': '0949384998',
          'password': 'Maru@123',
        },
      );
    } catch (e) {
      if (e is DioException) {
        print('0949384998 failed: ${e.response?.data}');
      }
      branchRes = await dio.post(
        '/api/branch/login',
        data: {
          'phone_number': '0949389498',
          'password': 'Maru@123',
        },
      );
    }
    final branchToken = branchRes.data['token'].toString();
    final branchId = branchRes.data['branch']['id'].toString();
    print('Branch login OK: token=${branchToken.substring(0, 15)}..., branchId=$branchId');

    print('2. Calling /api/login with branch token...');
    try {
      final loginRes = await dio.post(
        '/api/login',
        options: Options(
          headers: {
            'Authorization': 'Bearer $branchToken',
            'Branch-Id': branchId,
          },
        ),
      );
      print('Status: ${loginRes.statusCode}');
      print('Data: ${loginRes.data}');
    } catch (e) {
      if (e is DioException) {
        print('Error status: ${e.response?.statusCode}');
        print('Error data: ${e.response?.data}');
        print('Error headers: ${e.response?.headers}');
      } else {
        print('Exception: $e');
      }
    }
  });
}
