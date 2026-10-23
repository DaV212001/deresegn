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
}
