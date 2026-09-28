import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:deresegn/services/security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecurityService & SecurityCheckResult Tests', () {
    late SecurityService securityService;

    setUp(() {
      Get.reset();
      securityService = Get.put(SecurityService());
    });

    tearDown(() {
      Get.reset();
    });

    test('SecurityCheckResult.clean has isCompromised false and empty violations', () {
      const result = SecurityCheckResult.clean;
      expect(result.isCompromised, isFalse);
      expect(result.violations, isEmpty);
      expect(result.isRooted, isFalse);
      expect(result.isJailbroken, isFalse);
      expect(result.isFridaDetected, isFalse);
    });

    test('SecurityCheckResult with violations reflects compromised status', () {
      const result = SecurityCheckResult(
        isCompromised: true,
        violations: ['Android Root detected', 'Frida server running'],
        isRooted: true,
        isFridaDetected: true,
      );
      expect(result.isCompromised, isTrue);
      expect(result.violations.length, 2);
      expect(result.isRooted, isTrue);
      expect(result.isFridaDetected, isTrue);
    });

    test('SecurityService initial state is not compromised', () {
      expect(securityService.isCompromised.value, isFalse);
      expect(securityService.detectedViolations, isEmpty);
    });

    test('checkDeviceIntegrity executes cleanly without unhandled exceptions', () async {
      final result = await securityService.checkDeviceIntegrity(
        enforceAction: false,
      );
      expect(result, isNotNull);
      expect(securityService.isCompromised.value, equals(result.isCompromised));
    });
  });
}
