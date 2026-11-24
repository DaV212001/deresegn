import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:deresegn/config/dio_config.dart';
import 'package:deresegn/config/config_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> mockStorage = {};
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockStorage.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'write') {
        mockStorage[methodCall.arguments['key'] as String] =
            methodCall.arguments['value'] as String;
        return null;
      } else if (methodCall.method == 'read') {
        return mockStorage[methodCall.arguments['key'] as String];
      } else if (methodCall.method == 'delete') {
        mockStorage.remove(methodCall.arguments['key'] as String);
        return null;
      } else if (methodCall.method == 'deleteAll') {
        mockStorage.clear();
        return null;
      }
      return null;
    });
  });

  test('isSessionExpiredError identifies session expired exception correctly', () {
    final err = DioException(
      requestOptions: RequestOptions(path: '/api/branches/29/supplies'),
      message: 'Session expired. Please log in again.',
      type: DioExceptionType.unknown,
    );
    expect(DioConfig.isSessionExpiredError(err), isTrue);

    final otherErr = DioException(
      requestOptions: RequestOptions(path: '/api/branches/29/supplies'),
      message: 'Connection error',
      type: DioExceptionType.connectionError,
    );
    expect(DioConfig.isSessionExpiredError(otherErr), isFalse);
  });

  test('ConfigPreference.clearTokens properly clears both company and branch access tokens', () async {
    await ConfigPreference.updateBranchToken('mock_branch_token_123');
    await ConfigPreference.updateCompanyToken('mock_company_token_456');

    expect(ConfigPreference.isLoggedIn(), isTrue);

    await ConfigPreference.clearTokens();

    expect(ConfigPreference.getAccessToken(), isNull);
    expect(ConfigPreference.getCompanyAccessToken(), isNull);
    expect(ConfigPreference.isLoggedIn(), isFalse);
  });

  test('AuthInterceptor does NOT logout or wipe session on 401 from /api/payment/initialize', () async {
    await ConfigPreference.updateBranchToken('mock_branch_token_123');
    expect(ConfigPreference.isLoggedIn(), isTrue);

    final interceptor = AuthInterceptor();
    final handler = _TestErrorHandler();
    final dioErr = DioException(
      requestOptions: RequestOptions(path: '/api/payment/initialize', method: 'POST'),
      response: Response(
        requestOptions: RequestOptions(path: '/api/payment/initialize', method: 'POST'),
        statusCode: 401,
        data: {'message': 'Unauthenticated.'},
      ),
      type: DioExceptionType.badResponse,
    );

    interceptor.onError(dioErr, handler);

    // Give microtasks a cycle to settle
    await Future.delayed(const Duration(milliseconds: 50));

    // The error should be passed directly to next() for screen-level handling
    expect(handler.passedErr, isNotNull);
    expect(handler.rejectedErr, isNull);
    // User session should NOT be wiped out
    expect(ConfigPreference.getAccessToken(), 'mock_branch_token_123');
  });

  test('AuthInterceptor does NOT logout or wipe session on 401 from /api/packages', () async {
    await ConfigPreference.updateBranchToken('mock_branch_token_123');
    expect(ConfigPreference.isLoggedIn(), isTrue);

    final interceptor = AuthInterceptor();
    final handler = _TestErrorHandler();
    final dioErr = DioException(
      requestOptions: RequestOptions(path: '/api/packages', method: 'GET'),
      response: Response(
        requestOptions: RequestOptions(path: '/api/packages', method: 'GET'),
        statusCode: 401,
        data: {'message': 'Unauthenticated.'},
      ),
      type: DioExceptionType.badResponse,
    );

    interceptor.onError(dioErr, handler);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(handler.passedErr, isNotNull);
    expect(handler.rejectedErr, isNull);
    expect(ConfigPreference.getAccessToken(), 'mock_branch_token_123');
  });
}

class _TestErrorHandler extends ErrorInterceptorHandler {
  DioException? passedErr;
  DioException? rejectedErr;
  Response? resolvedResponse;

  @override
  void next(DioException err) {
    passedErr = err;
  }

  @override
  void reject(DioException err, [bool trueOnError = false]) {
    rejectedErr = err;
  }

  @override
  void resolve(Response response) {
    resolvedResponse = response;
  }
}
