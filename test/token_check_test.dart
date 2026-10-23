import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:deresegn/services/ssl_pinning_service.dart';

void main() {
  test('Token Check', () async {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.deresegn.com',
        connectTimeout: const Duration(seconds: 30),
      ),
    );
    dio.httpClientAdapter = SslPinningService.createPinnedAdapter();

    final branchRes = await dio.post(
      '/api/branch/login',
      data: {
        'phone_number': '0949384998',
        'password': 'Maru@123',
      },
    );
    final branchToken = branchRes.data['token'].toString();
    print('Token received: $branchToken');
    print('Token length: ${branchToken.length}');
    
    // Check if it is a JWT
    try {
      final isExp = JwtDecoder.isExpired(branchToken);
      print('JwtDecoder.isExpired: $isExp');
      final decoded = JwtDecoder.decode(branchToken);
      print('Decoded JWT: $decoded');
    } catch (e) {
      print('JwtDecoder threw exception: $e');
    }

    // Now test supplies endpoint
    final branchId = branchRes.data['branch']['id'].toString();
    print('Testing supplies endpoint with branchToken:');
    try {
      final suppliesRes = await dio.get(
        '/api/branches/$branchId/supplies',
        options: Options(
          headers: {
            'Authorization': 'Bearer $branchToken',
            'Branch-Id': branchId,
          },
        ),
      );
      print('Supplies with branchToken status: ${suppliesRes.statusCode}');
      print('Supplies data: ${suppliesRes.data}');
    } catch (e) {
      if (e is DioException) {
        print('Supplies with branchToken failed: ${e.response?.statusCode} -> ${e.response?.data}');
      } else {
        print('Supplies error: $e');
      }
    }
  });
}
