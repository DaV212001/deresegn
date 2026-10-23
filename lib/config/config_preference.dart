import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:logger/logger.dart';

import '../models/working_hours_model.dart';
import '../services/invoice_cache_service.dart';

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
  static const String keyBranchStatus = 'branch_status';
  static const String keyPackageId = 'package_id';
  static const String keyExpiredDate = 'expired_date';
  static const String keyBranchPhone = 'branch_phone';
  static const String keyBranchEmail = 'branch_email';
  static const String keyBranchWorkingHours = 'branch_working_hours';
  static const String keyFcmToken = 'fcm_token';

  // Theme Keys
  static const String keyIsDarkMode = 'is_dark_mode';

  // Auth Lockout Keys
  static const String keyLockoutExpiry = 'auth_lockout_expiry';
  static const String keyLockoutMessage = 'auth_lockout_message';

  static Future<void> init() async {
    _accessToken = await _storage.read(key: keyAccessToken);
    _refreshToken = await _storage.read(key: keyRefreshToken);
    _companyAccessToken = await _storage.read(key: keyCompanyAccessToken);
    _morToken = await _storage.read(key: keyMorToken);
    _companyId = await _storage.read(key: keyCompanyId);
    _branchId = await _storage.read(key: keyBranchId);
    _branchStatus = await _storage.read(key: keyBranchStatus);
    _packageId = await _storage.read(key: keyPackageId);
    _expiredDate = await _storage.read(key: keyExpiredDate);
    _branchPhone = await _storage.read(key: keyBranchPhone);
    _branchEmail = await _storage.read(key: keyBranchEmail);
    _branchWorkingHoursJson = await _storage.read(key: keyBranchWorkingHours);
    _fcmToken = await _storage.read(key: keyFcmToken);
  }

  static String? _companyId;
  static String? _branchId;
  static String? _branchStatus;
  static String? _packageId;
  static String? _expiredDate;
  static String? _branchPhone;
  static String? _branchEmail;
  static String? _branchWorkingHoursJson;
  static String? _fcmToken;

  static String? getCompanyId() => _companyId;
  static String? getBranchId() => _branchId;
  static String? getBranchStatus() => _branchStatus;
  static String? getPackageId() => _packageId;
  static String? getExpiredDate() => _expiredDate;
  static String? getBranchPhone() => _branchPhone;
  static String? getBranchEmail() => _branchEmail;

  static bool isBranchActive() {
    if (_branchStatus == null) return false;
    final status = _branchStatus!.toLowerCase();
    if (status != 'active') return false;
    if (_expiredDate != null && _expiredDate!.isNotEmpty) {
      final expiry = DateTime.tryParse(_expiredDate!);
      if (expiry != null && expiry.isBefore(DateTime.now())) {
        return false;
      }
    }
    return true;
  }

  static Future<void> saveBranchSubscription({
    required String status,
    int? packageId,
    String? expiredDate,
    String? phone,
    String? email,
  }) async {
    _branchStatus = status;
    await _storage.write(key: keyBranchStatus, value: status);

    if (packageId != null) {
      _packageId = packageId.toString();
      await _storage.write(key: keyPackageId, value: packageId.toString());
    }
    if (expiredDate != null) {
      _expiredDate = expiredDate;
      await _storage.write(key: keyExpiredDate, value: expiredDate);
    }
    if (phone != null) {
      _branchPhone = phone;
      await _storage.write(key: keyBranchPhone, value: phone);
    }
    if (email != null) {
      _branchEmail = email;
      await _storage.write(key: keyBranchEmail, value: email);
    }
  }

  static BranchWorkingHours? getBranchWorkingHours() {
    if (_branchWorkingHoursJson == null || _branchWorkingHoursJson!.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(_branchWorkingHoursJson!);
      if (decoded is Map) {
        return BranchWorkingHours.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      Logger().e('Error decoding cached branch working hours', error: e);
    }
    return null;
  }

  static Future<void> saveBranchWorkingHours(String jsonStr) async {
    _branchWorkingHoursJson = jsonStr;
    await _storage.write(key: keyBranchWorkingHours, value: jsonStr);
  }

  static String? getFcmToken() => _fcmToken;

  static Future<void> saveFcmToken(String token) async {
    _fcmToken = token;
    await _storage.write(key: keyFcmToken, value: token);
  }

  static Future<void> saveCompanyContext({
    required String companyId,
    String? branchId,
  }) async {
    _companyId = companyId.trim();
    final cleanBranch = branchId?.trim().replaceAll(RegExp(r'^/+'), '');
    _branchId = cleanBranch ?? _branchId;
    await _storage.write(key: keyCompanyId, value: _companyId!);
    if (cleanBranch != null) {
      await _storage.write(key: keyBranchId, value: cleanBranch);
    }
  }

  static Future<void> saveBranchId(String branchId) async {
    final clean = branchId.trim().replaceAll(RegExp(r'^/+'), '');
    _branchId = clean;
    await _storage.write(key: keyBranchId, value: clean);
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
    if (_accessToken == null || _accessToken!.isEmpty) return true;
    try {
      return JwtDecoder.isExpired(_accessToken!);
    } catch (e) {
      Logger().w('Could not decode JWT to check expiry: $e');
      return false;
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
    _accessToken = null;
    await _storage.delete(key: keyCompanyAccessToken);
    await _storage.delete(key: keyAccessToken);
    await InvoiceCacheService.clearCache();
  }

  static Future<void> clearMorTokens() async {
    _morToken = null;
    _refreshToken = null;
    await _storage.delete(key: keyMorToken);
    await _storage.delete(key: keyRefreshToken);
  }

  static bool isLoggedIn() {
    final accessToken = getAccessToken();
    final companyToken = getCompanyAccessToken();
    return (accessToken != null && accessToken.isNotEmpty) ||
        (companyToken != null && companyToken.isNotEmpty);
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

  static Future<void> saveLockout(int expiryTimestamp, String message) async {
    await _storage.write(key: keyLockoutExpiry, value: expiryTimestamp.toString());
    await _storage.write(key: keyLockoutMessage, value: message);
  }

  static Future<int?> getLockoutExpiry() async {
    final value = await _storage.read(key: keyLockoutExpiry);
    return value != null ? int.tryParse(value) : null;
  }

  static Future<String?> getLockoutMessage() async {
    return await _storage.read(key: keyLockoutMessage);
  }

  static Future<void> clearLockout() async {
    await _storage.delete(key: keyLockoutExpiry);
    await _storage.delete(key: keyLockoutMessage);
  }


  static Future<void> clearAll() async {
  await _storage.deleteAll();
  _accessToken = null;
  _refreshToken = null;
  _companyAccessToken = null;
  _morToken = null;
  _companyId = null;
  _branchId = null;
  await InvoiceCacheService.clearCache();
}
}
