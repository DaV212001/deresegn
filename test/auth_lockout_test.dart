import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deresegn/controllers/auth_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('Account Lockout Detection and Timer Tests', () {
    late AuthController controller;

    setUp(() {
      controller = AuthController();
    });

    tearDown(() {
      controller.onClose();
    });

    test('Parses 29 minutes lockout message correctly', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/api/branch/login'),
        statusCode: 403,
        data: {
          'message': 'Account locked due to too many failed attempts. Try again in 29 minutes.',
        },
      );

      final isLockout = controller.handleLockoutIfPresent(null, response);
      expect(isLockout, isTrue);
      expect(controller.isLockedOut.value, isTrue);
      expect(controller.lockoutSeconds.value, equals(29 * 60));
      expect(controller.formattedLockoutTime, equals('29:00'));
    });

    test('Parses seconds lockout message correctly', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/api/branch/login'),
        statusCode: 403,
        data: {
          'message': 'Account locked. Try again in 45 seconds.',
        },
      );

      final isLockout = controller.handleLockoutIfPresent(null, response);
      expect(isLockout, isTrue);
      expect(controller.isLockedOut.value, isTrue);
      expect(controller.lockoutSeconds.value, equals(45));
      expect(controller.formattedLockoutTime, equals('00:45'));
    });

    test('Formatted time handles hours, minutes, and seconds', () {
      controller.lockoutSeconds.value = 3665;
      expect(controller.formattedLockoutTime, equals('1h 01m 05s'));

      controller.lockoutSeconds.value = 125;
      expect(controller.formattedLockoutTime, equals('02:05'));

      controller.lockoutSeconds.value = 9;
      expect(controller.formattedLockoutTime, equals('00:09'));

      controller.lockoutSeconds.value = 0;
      expect(controller.formattedLockoutTime, equals('00:00'));
    });

    test('Non-lockout 403 is not handled as lockout', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/api/branch/login'),
        statusCode: 403,
        data: {
          'message': 'Forbidden access.',
        },
      );

      final isLockout = controller.handleLockoutIfPresent(null, response);
      expect(isLockout, isFalse);
      expect(controller.isLockedOut.value, isFalse);
    });
  });
}
