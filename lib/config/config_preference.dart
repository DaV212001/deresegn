import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:logger/logger.dart';

class ConfigPreference {
  static const _storage = FlutterSecureStorage();

  static String? _accessToken;
  static String? _refreshToken;
  static String? _companyAccessToken;
  static String? _morToken;

  // Device Credentials Keys
  static const String keyClientId = 'client_id';
  static const String keyClientSecret = 'client_secret';
  static const String keyApiKey = 'api_key';
  static const String keyTin = 'tin';

  // Token Keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyCompanyAccessToken = 'company_access_token';
  static const String keyMorToken = 'mor_token';
  static const String keyCompanyId = 'company_id';
  static const String keyBranchId = 'branch_id';

  // Theme Keys
  static const String keyIsDarkMode = 'is_dark_mode';

  static Future<void> init() async {
    _accessToken = await _storage.read(key: keyAccessToken);
    _refreshToken = await _storage.read(key: keyRefreshToken);
    _companyAccessToken = await _storage.read(key: keyCompanyAccessToken);
    _morToken = await _storage.read(key: keyMorToken);
    _companyId = await _storage.read(key: keyCompanyId);
    _branchId = await _storage.read(key: keyBranchId);
  }

  static String? _companyId;
  static String? _branchId;
  static String? getCompanyId() => _companyId;
  static String? getBranchId() => _branchId;

  static Future<void> saveCompanyContext({
    required String companyId,
    String? branchId,
  }) async {
    _companyId = companyId;
    _branchId = branchId ?? _branchId;
    await _storage.write(key: keyCompanyId, value: companyId);
    if (branchId != null)
      await _storage.write(key: keyBranchId, value: branchId);
  }

  static Future<void> saveBranchId(String branchId) async {
    _branchId = branchId;
    await _storage.write(key: keyBranchId, value: branchId);
  }

  static Future<void> clearBranch() async {
    _branchId = null;
    await _storage.delete(key: keyBranchId);
  }

  static String? getAccessToken() => _accessToken;
  static String? getRefreshToken() => _refreshToken;
  static String? getCompanyAccessToken() => _companyAccessToken;
  static String? getMorToken() => _morToken;

  static Future<void> updateCompanyToken(String token) async {
    _companyAccessToken = token;
    await _storage.write(key: keyCompanyAccessToken, value: token);
  }

  static bool isAccessTokenExpired() {
    if (_accessToken == null) return true;
    try {
      return JwtDecoder.isExpired(_accessToken!);
    } catch (e) {
      Logger().e('Error decoding JWT token', error: e);
      return true;
    }
  }

  static Future<void> updateBranchToken(String access) async {
    _accessToken = access;
    await _storage.write(key: keyAccessToken, value: access);
  }

  static Future<void> updateMorTokens(
    String mor,
    String refresh,
    int expires,
  ) async {
    _morToken = mor;
    _refreshToken = refresh;
    await _storage.write(key: keyMorToken, value: mor);
    await _storage.write(key: keyRefreshToken, value: refresh);
  }

  static Future<void> clearTokens() async {
    await clearMorTokens();
    _companyAccessToken = null;
    await _storage.delete(key: keyCompanyAccessToken);
  }

  static Future<void> clearMorTokens() async {
    _morToken = null;
    _refreshToken = null;
    await _storage.delete(key: keyMorToken);
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
      (await _storage.read(key: keyClientId)) ?? "";
  static Future<String> getClientSecret() async =>
      (await _storage.read(key: keyClientSecret)) ?? "";
  static Future<String> getApiKey() async =>
      (await _storage.read(key: keyApiKey)) ?? "";
  static Future<String> getTin() async =>
      (await _storage.read(key: keyTin)) ?? "";

  static Future<void> clearDeviceCredentials() async {
    await _storage.delete(key: keyClientId);
    await _storage.delete(key: keyClientSecret);
    await _storage.delete(key: keyApiKey);
    await _storage.delete(key: keyTin);
  }

  static Future<bool> isDarkMode() async {
    final value = await _storage.read(key: keyIsDarkMode);
    return value == 'true'; // Default to false if not set
  }

  static Future<void> setDarkMode(bool isDark) async {
    await _storage.write(key: keyIsDarkMode, value: isDark.toString());
  }
}
