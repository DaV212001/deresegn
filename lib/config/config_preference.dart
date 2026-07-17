import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:logger/logger.dart';

class ConfigPreference {
  static const _storage = FlutterSecureStorage();

  static String? _accessToken;
  static String? _refreshToken;

  // Device Credentials Keys
  static const String keyClientId = 'client_id';
  static const String keyClientSecret = 'client_secret';
  static const String keyApiKey = 'api_key';
  static const String keyTin = 'tin';

  // Token Keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';

  // Theme Keys
  static const String keyIsDarkMode = 'is_dark_mode';

  static Future<void> init() async {
    _accessToken = await _storage.read(key: keyAccessToken);
    _refreshToken = await _storage.read(key: keyRefreshToken);
  }

  static String? getAccessToken() => _accessToken;
  static String? getRefreshToken() => _refreshToken;

  static bool isAccessTokenExpired() {
    if (_accessToken == null) return true;
    try {
      return JwtDecoder.isExpired(_accessToken!);
    } catch (e) {
      Logger().e('Error decoding JWT token', error: e);
      return true;
    }
  }

  static Future<void> updateTokens(
    String access,
    String refresh,
    int expires,
  ) async {
    _accessToken = access;
    _refreshToken = refresh;
    await _storage.write(key: keyAccessToken, value: access);
    await _storage.write(key: keyRefreshToken, value: refresh);
  }

  static Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.delete(key: keyAccessToken);
    await _storage.delete(key: keyRefreshToken);
  }

  static bool isLoggedIn() {
    final accessToken = getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  static Future<void> saveDeviceCredentials({
    required String clientId,
    required String clientSecret,
    required String apiKey,
    required String tin,
  }) async {
    await _storage.write(key: keyClientId, value: clientId);
    await _storage.write(key: keyClientSecret, value: clientSecret);
    await _storage.write(key: keyApiKey, value: apiKey);
    await _storage.write(key: keyTin, value: tin);
  }

  static Future<String> getClientId() async =>
      (await _storage.read(key: keyClientId)) ??
      "127ae9ad-8de2-4856-ba88-4e6a49ad10d0";
  static Future<String> getClientSecret() async =>
      (await _storage.read(key: keyClientSecret)) ??
      "d3ddb848-9daa-44ab-8d96-374fcc8c9e6b";
  static Future<String> getApiKey() async =>
      (await _storage.read(key: keyApiKey)) ??
      "dc481579-a6e7-4594-abcf-5493e261685e";
  static Future<String> getTin() async =>
      (await _storage.read(key: keyTin)) ?? "0000037187";

  static Future<void> clearDeviceCredentials() async {
    await _storage.delete(key: keyClientId);
    await _storage.delete(key: keyClientSecret);
    await _storage.delete(key: keyApiKey);
    await _storage.delete(key: keyTin);
  }

  static Future<bool> isDarkMode() async {
    final value = await _storage.read(key: keyIsDarkMode);
    return value != 'false'; // Default to true if not set
  }

  static Future<void> setDarkMode(bool isDark) async {
    await _storage.write(key: keyIsDarkMode, value: isDark.toString());
  }
}
