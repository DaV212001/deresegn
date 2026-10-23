import 'package:flutter_test/flutter_test.dart';
import 'package:deresegn/models/auth_models.dart';

void main() {
  group('FCM Token Registration API Model and Payload Tests', () {
    test('FcmTokenRegistrationRequest serializes correctly with platform and fcm_token', () {
      const sampleToken =
          'dvh5IE45SLSy3SfcPNc5bb:APA91bE6izYYYGAnYHg9Ki31b_PwrVRHiAX83EDNIq1J5b1tuzz5YyvnkpCxKm9kqzyrpKINgCM1R36AUIabG3S9Gi0IW7Vb4RSGBh9UHb5U-2H4bEWOYnk';

      final request = FcmTokenRegistrationRequest(
        fcmToken: sampleToken,
        platform: 'android',
      );

      final json = request.toJson();

      expect(json['fcm_token'], sampleToken);
      expect(json['device_info'], isA<Map<String, dynamic>>());
      expect(json['device_info']['platform'], 'android');
    });

    test('FcmTokenRegistrationRequest serializes custom platforms (ios, windows, web)', () {
      final iosRequest = FcmTokenRegistrationRequest(
        fcmToken: 'test-ios-token',
        platform: 'ios',
      );
      expect(iosRequest.toJson()['device_info']['platform'], 'ios');

      final windowsRequest = FcmTokenRegistrationRequest(
        fcmToken: 'test-windows-token',
        platform: 'windows',
      );
      expect(windowsRequest.toJson()['device_info']['platform'], 'windows');
    });
  });
}
