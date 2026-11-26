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
  static const String keyPaidDate = 'paid_date';
  static const String keyBranchPhone = 'branch_phone';
  static const String keyBranchEmail = 'branch_email';
  static const String keyBranchWorkingHours = 'branch_working_hours';
  static const String keyFcmToken = 'fcm_token';
  static const String keyBranchCertificateInstalled = 'branch_certificate_installed';

  // Company & Branch Profile Keys
  static const String keyCompanyName = 'company_name';
  static const String keyOwnerName = 'owner_name';
  static const String keyBranchName = 'branch_name';
  static const String keyBranchCity = 'branch_city';
  static const String keyBranchWoreda = 'branch_woreda';
  static const String keyBranchRegion = 'branch_region';
  static const String keyBranchVatNumber = 'branch_vat_number';
  static const String keyBranchSystemNumber = 'branch_system_number';
  static const String keyLoggedInPhone = 'logged_in_phone';

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
    _paidDate = await _storage.read(key: keyPaidDate);
    _branchPhone = await _storage.read(key: keyBranchPhone);
    _branchEmail = await _storage.read(key: keyBranchEmail);
    _branchWorkingHoursJson = await _storage.read(key: keyBranchWorkingHours);
    _fcmToken = await _storage.read(key: keyFcmToken);
    final certVal = await _storage.read(key: keyBranchCertificateInstalled);
    _isBranchCertificateInstalled = certVal == 'true';
    _tin = await _storage.read(key: keyTin);
    _companyName = await _storage.read(key: keyCompanyName);
    _ownerName = await _storage.read(key: keyOwnerName);
    _branchName = await _storage.read(key: keyBranchName);
    _branchCity = await _storage.read(key: keyBranchCity);
    _branchWoreda = await _storage.read(key: keyBranchWoreda);
    _branchRegion = await _storage.read(key: keyBranchRegion);
    _branchVatNumber = await _storage.read(key: keyBranchVatNumber);
    _branchSystemNumber = await _storage.read(key: keyBranchSystemNumber);
    _loggedInPhone = await _storage.read(key: keyLoggedInPhone);
  }

  static String? _companyId;
  static String? _branchId;
  static String? _branchStatus;
  static String? _packageId;
  static String? _expiredDate;
  static String? _paidDate;
  static String? _branchPhone;
  static String? _branchEmail;
  static String? _branchWorkingHoursJson;
  static String? _fcmToken;
  static bool? _isBranchCertificateInstalled;
  static String? _tin;
  static String? _companyName;
  static String? _ownerName;
  static String? _branchName;
  static String? _branchCity;
  static String? _branchWoreda;
  static String? _branchRegion;
  static String? _branchVatNumber;
  static String? _branchSystemNumber;
  static String? _loggedInPhone;

  static String? getCompanyId() => _companyId;
  static String? getBranchId() => _branchId;
  static String? getBranchStatus() => _branchStatus;
  static String? getPackageId() => _packageId;
  static String? getExpiredDate() => _expiredDate;
  static String? getPaidDate() => _paidDate;
  static String? getBranchPhone() => _branchPhone;
  static String? getBranchEmail() => _branchEmail;
  static String? getCachedTin() => _tin;
  static String? getCompanyName() => _companyName;
  static String? getOwnerName() => _ownerName;
  static String? getBranchName() => _branchName;
  static String? getBranchCity() => _branchCity;
  static String? getBranchWoreda() => _branchWoreda;
  static String? getBranchRegion() => _branchRegion;
  static String? getBranchVatNumber() => _branchVatNumber;
  static String? getBranchSystemNumber() => _branchSystemNumber;
  static String? getLoggedInPhone() => _loggedInPhone;

  static bool isBranchCertificateInstalled() {
    return _isBranchCertificateInstalled ?? false;
  }

  static Future<void> saveBranchCertificateInstalled(bool installed) async {
    _isBranchCertificateInstalled = installed;
    await _storage.write(
      key: keyBranchCertificateInstalled,
      value: installed ? 'true' : 'false',
    );
  }

  static Future<void> saveCompanyProfile({
    String? companyName,
    String? tin,
    String? ownerName,
    String? branchName,
    String? city,
    String? woreda,
    String? region,
    String? vatNumber,
    String? systemNumber,
    String? phone,
    String? email,
    String? loggedInPhone,
  }) async {
    if (companyName != null && companyName.trim().isNotEmpty) {
      _companyName = companyName.trim();
      await _storage.write(key: keyCompanyName, value: _companyName!);
    }
    if (tin != null && tin.trim().isNotEmpty) {
      _tin = tin.trim();
      await _storage.write(key: keyTin, value: _tin!);
    }
    if (ownerName != null && ownerName.trim().isNotEmpty) {
      _ownerName = ownerName.trim();
      await _storage.write(key: keyOwnerName, value: _ownerName!);
    }
    if (branchName != null && branchName.trim().isNotEmpty) {
      _branchName = branchName.trim();
      await _storage.write(key: keyBranchName, value: _branchName!);
    }
    if (city != null && city.trim().isNotEmpty) {
      _branchCity = city.trim();
      await _storage.write(key: keyBranchCity, value: _branchCity!);
    }
    if (woreda != null && woreda.trim().isNotEmpty) {
      _branchWoreda = woreda.trim();
      await _storage.write(key: keyBranchWoreda, value: _branchWoreda!);
    }
    if (region != null && region.trim().isNotEmpty) {
      _branchRegion = region.trim();
      await _storage.write(key: keyBranchRegion, value: _branchRegion!);
    }
    if (vatNumber != null && vatNumber.trim().isNotEmpty) {
      _branchVatNumber = vatNumber.trim();
      await _storage.write(key: keyBranchVatNumber, value: _branchVatNumber!);
    }
    if (systemNumber != null && systemNumber.trim().isNotEmpty) {
      _branchSystemNumber = systemNumber.trim();
      await _storage.write(key: keyBranchSystemNumber, value: _branchSystemNumber!);
    }
    if (phone != null && phone.trim().isNotEmpty) {
      _branchPhone = phone.trim();
      await _storage.write(key: keyBranchPhone, value: _branchPhone!);
    }
    if (email != null && email.trim().isNotEmpty) {
      _branchEmail = email.trim();
      await _storage.write(key: keyBranchEmail, value: _branchEmail!);
    }
    if (loggedInPhone != null && loggedInPhone.trim().isNotEmpty) {
      _loggedInPhone = loggedInPhone.trim();
      await _storage.write(key: keyLoggedInPhone, value: _loggedInPhone!);
    }
  }

  static final Map<int, String> _branchCsrCache = {};

  static String? getBranchCsr(int branchId) => _branchCsrCache[branchId];

  static Future<void> saveBranchCsr(int branchId, String csr) async {
    _branchCsrCache[branchId] = csr;
    try {
      await _storage.write(
        key: 'branch_csr_$branchId',
        value: csr,
      );
    } catch (_) {}
  }

  static Future<String?> loadBranchCsr(int branchId) async {
    if (_branchCsrCache.containsKey(branchId) && _branchCsrCache[branchId] != null) {
      return _branchCsrCache[branchId];
    }
    try {
      final val = await _storage.read(key: 'branch_csr_$branchId');
      if (val != null && val.isNotEmpty) {
        _branchCsrCache[branchId] = val;
      }
      return val;
    } catch (_) {
      return null;
    }
  }

  static Future<void> removeBranchCsr(int branchId) async {
    _branchCsrCache.remove(branchId);
    try {
      await _storage.delete(key: 'branch_csr_$branchId');
    } catch (_) {}
  }

  /// Returns true ONLY when the branch has a confirmed, paid, unexpired package subscription.
  ///
  /// Note: The backend status may return "active" even for newly registered accounts
  /// that have not paid yet. Therefore, payment validity strictly requires:
  /// 1. Status is 'active' (not pending, inactive, or cancelled)
  /// 2. Valid package ID (must be > 0)
  /// 3. Valid future expiry date (expired_date > now)
  /// 4. Valid payment date (paid_date / payment_date is present)
  static bool isBranchActive() {
    // 1. Status check
    if (_branchStatus == null) return false;
    final status = _branchStatus!.toLowerCase();
    if (status != 'active') return false;

    // 2. Package ID check: A paid subscription MUST have an assigned package ID (> 0)
    if (_packageId == null || _packageId!.trim().isEmpty) return false;
    final pkgId = int.tryParse(_packageId!.trim());
    if (pkgId == null || pkgId <= 0) return false;

    // 3. Expiry date check: An active subscription MUST have an expiry date in the future
    if (_expiredDate == null || _expiredDate!.trim().isEmpty) return false;
    final expiry = DateTime.tryParse(_expiredDate!.trim());
    if (expiry == null || expiry.isBefore(DateTime.now())) {
      return false;
    }

    // 4. Paid date check: An active subscription MUST have a payment/paid date
    if (_paidDate == null || _paidDate!.trim().isEmpty) return false;

    return true;
  }

  static Future<void> saveBranchSubscription({
    required String status,
    int? packageId,
    String? expiredDate,
    String? paidDate,
    String? phone,
    String? email,
  }) async {
    _branchStatus = status;
    await _storage.write(key: keyBranchStatus, value: status);

    if (packageId != null && packageId > 0) {
      _packageId = packageId.toString();
      await _storage.write(key: keyPackageId, value: packageId.toString());
    } else {
      _packageId = null;
      await _storage.delete(key: keyPackageId);
    }

    if (expiredDate != null && expiredDate.trim().isNotEmpty) {
      _expiredDate = expiredDate.trim();
      await _storage.write(key: keyExpiredDate, value: _expiredDate!);
    } else {
      _expiredDate = null;
      await _storage.delete(key: keyExpiredDate);
    }

    if (paidDate != null && paidDate.trim().isNotEmpty) {
      _paidDate = paidDate.trim();
      await _storage.write(key: keyPaidDate, value: _paidDate!);
    } else {
      _paidDate = null;
      await _storage.delete(key: keyPaidDate);
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
    _isBranchCertificateInstalled = null;
    _loggedInPhone = null;
    await _storage.delete(key: keyCompanyAccessToken);
    await _storage.delete(key: keyAccessToken);
    await _storage.delete(key: keyBranchCertificateInstalled);
    await _storage.delete(key: keyLoggedInPhone);
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
    if (tin.trim().isNotEmpty) {
      _tin = tin.trim();
    }
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
  _branchStatus = null;
  _packageId = null;
  _expiredDate = null;
  _paidDate = null;
  _branchPhone = null;
  _branchEmail = null;
  _branchWorkingHoursJson = null;
  _fcmToken = null;
  _isBranchCertificateInstalled = null;
  _tin = null;
  _companyName = null;
  _ownerName = null;
  _branchName = null;
  _branchCity = null;
  _branchWoreda = null;
  _branchRegion = null;
  _branchVatNumber = null;
  _branchSystemNumber = null;
  _loggedInPhone = null;
  await InvoiceCacheService.clearCache();
}
}
