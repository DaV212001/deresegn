import 'dart:async';
import 'package:flutter/material.dart';
import 'package:deresegn/config/dio_config.dart';
import 'package:dio/dio.dart' as dio_lib;
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../config/config_preference.dart';
import '../models/auth_models.dart';
import '../models/company_models.dart';
import '../services/api_service.dart';

class AuthController extends GetxController {
  var isLinked = false.obs;
  var isLoggingIn = false.obs;
  var isCompanyLoading = false.obs;

  // Lockout countdown timer
  var lockoutSeconds = 0.obs;
  var isLockedOut = false.obs;
  var lockoutMessage = ''.obs;
  Timer? _lockoutTimer;

  String get formattedLockoutTime {
    final s = lockoutSeconds.value;
    if (s <= 0) return '00:00';
    final hours = s ~/ 3600;
    final minutes = (s % 3600) ~/ 60;
    final seconds = s % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void startLockout(int seconds, String message) {
    _lockoutTimer?.cancel();
    lockoutSeconds.value = seconds;
    isLockedOut.value = true;
    lockoutMessage.value = message;

    final expiryMs =
        DateTime.now().add(Duration(seconds: seconds)).millisecondsSinceEpoch;
    ConfigPreference.saveLockout(expiryMs, message);

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (lockoutSeconds.value <= 1) {
        timer.cancel();
        lockoutSeconds.value = 0;
        isLockedOut.value = false;
        lockoutMessage.value = '';
        ConfigPreference.clearLockout();
      } else {
        lockoutSeconds.value--;
      }
    });
  }

  Future<void> _restoreLockoutIfActive() async {
    final expiryMs = await ConfigPreference.getLockoutExpiry();
    if (expiryMs != null) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (expiryMs > nowMs) {
        final remainingSeconds = ((expiryMs - nowMs) / 1000).ceil();
        final message = await ConfigPreference.getLockoutMessage() ?? '';
        startLockout(remainingSeconds, message);
      } else {
        await ConfigPreference.clearLockout();
      }
    }
  }

  bool handleLockoutIfPresent(dynamic error, dynamic response) {
    int? statusCode;
    dynamic data;

    if (error is dio_lib.DioException) {
      statusCode = error.response?.statusCode;
      data = error.response?.data;
    } else if (response is dio_lib.Response) {
      statusCode = response.statusCode;
      data = response.data;
    }

    if (statusCode == 403 || statusCode == 429) {
      final msg = _parseMessage(data) ?? '';
      final lower = msg.toLowerCase();
      if (lower.contains('locked') ||
          lower.contains('too many') ||
          lower.contains('try again in') ||
          lower.contains('rate limit')) {
        int seconds = 1800; // default 30 minutes fallback

        // Parse: "29 minutes", "300 seconds", "1 hour", etc.
        final match = RegExp(
          r'(\d+)\s*(minute|min|second|sec|hour|hr)s?',
          caseSensitive: false,
        ).firstMatch(msg);

        if (match != null) {
          final count = int.tryParse(match.group(1) ?? '') ?? 0;
          final unit = (match.group(2) ?? '').toLowerCase();
          if (unit.startsWith('hour') || unit.startsWith('hr')) {
            seconds = count * 3600;
          } else if (unit.startsWith('min')) {
            seconds = count * 60;
          } else if (unit.startsWith('sec')) {
            seconds = count;
          }
        }

        startLockout(seconds, msg);
        return true;
      }
    }
    return false;
  }

  @override
  void onInit() {
    super.onInit();
    isLinked.value = ConfigPreference.getCompanyAccessToken() != null;
    _restoreLockoutIfActive();
  }

  @override
  void onClose() {
    _lockoutTimer?.cancel();
    super.onClose();
  }

  Future<void> checkDeviceLink() async {
    isLinked.value = ConfigPreference.getCompanyAccessToken() != null;
  }

  Future<bool> registerCompany(
    String companyName,
    String tin,
    String owner,
    String phone,
    String password,
    String email,
    String website,
  ) async {
    isCompanyLoading.value = true;
    bool success = false;
    await ApiService.registerCompany(
      CompanyRegisterRequest(
        companyName: companyName,
        tinNumber: tin,
        ownerName: owner,
        phone: phone,
        password: password,
        email: email,
        website: website,
      ),
      onSuccess: (response) async {
        final token = _tokenFromResponse(response.data);
        if (token != null) {
          await ConfigPreference.updateCompanyToken(token);
          await ConfigPreference.saveCompanyContext(
            companyId: _idFromResponse(response.data) ?? '',
          );
        }
        success = true;
      },
      onFailure: (e, r) => _handleError(e, r),
    );
    isCompanyLoading.value = false;
    return success;
  }

  Future<bool> loginCompany(
    String phone,
    String password,
    String companyId,
  ) async {
    if (phone.trim().isEmpty || password.isEmpty || companyId.trim().isEmpty) {
      Get.snackbar(
        'Missing details',
        'Phone, password, and company ID are required.',
      );
      return false;
    }
    isCompanyLoading.value = true;
    bool success = false;
    await ApiService.loginCompany(
      CompanyLoginRequest(
        phone: phone.trim(),
        password: password,
        companyId: companyId.trim(),
      ),
      onSuccess: (response) async {
        final body = response.data is Map ? response.data : <String, dynamic>{};
        final data = body['data'] is Map ? body['data'] : body;
        final token =
            data['accessToken'] ?? data['access_token'] ?? data['token'];
        if (token == null) {
          Get.snackbar(
            'Login failed',
            'The server did not return an access token.',
          );
          return;
        }
        await ConfigPreference.updateCompanyToken('$token');
        await ConfigPreference.saveCompanyContext(
          companyId: '${data['company_id'] ?? data['companyId'] ?? companyId}',
        );
        success = true;
      },
      onFailure: (e, r) {
        if (!handleLockoutIfPresent(e, r)) {
          _handleError(e, r);
        }
      },
    );
    isCompanyLoading.value = false;
    return success;
  }

  Future<void> performBranchLogin(String tin, String password) async {
    isLoggingIn.value = true;
    
    final request = BranchLoginRequest(tinNumber: tin, password: password);
    
    await ApiService.loginBranch(
      request,
      onSuccess: (response) async {
        final data = response.data;
        final token = data['token'];
        final branchDetails = data['branch'];
        
        if (token != null && branchDetails != null) {
          await ConfigPreference.updateBranchToken(token);
          await ConfigPreference.saveBranchId('${branchDetails['id']}');
          if (branchDetails['company_id'] != null) {
            await ConfigPreference.saveCompanyContext(
              companyId: '${branchDetails['company_id']}',
              branchId: '${branchDetails['id']}',
            );
          }
          await ConfigPreference.saveDeviceCredentials(
            clientId: branchDetails['client_id'] ?? '',
            clientSecret: '',
            apiKey: '',
            tin: branchDetails['tin_number'] ?? tin,
          );
          isLoggingIn.value = false;
          Get.offAllNamed('/dashboard');
        } else {
          Logger().w('Branch login returned 200 but missing token payload.');
          isLoggingIn.value = false;
        }
      },
      onFailure: (error, response) {
        Logger().e('Login failed: $error');
        final isLockout = handleLockoutIfPresent(error, response);
        if (isLockout) {
          Get.snackbar(
            'Account Locked',
            lockoutMessage.value.isNotEmpty
                ? lockoutMessage.value
                : 'Account locked due to too many failed attempts.',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red.shade900.withValues(alpha: 0.9),
            colorText: Colors.white,
            icon: const Icon(Icons.lock_clock_rounded, color: Colors.white),
          );
        } else {
          _handleError(error, response);
        }
        isLoggingIn.value = false;
      },
    );
  }

  Future<bool> ensureMorAuth() async {
    final morToken = ConfigPreference.getMorToken();
    if (morToken != null && morToken.isNotEmpty) {
      return true;
    }

    bool success = false;
    await ApiService.login(
      onSuccess: (response) async {
        final body = response.data is Map ? response.data : <String, dynamic>{};
        final data = body['data'] is Map ? body['data'] : body;
        final token = data['accessToken'] ?? data['access_token'] ?? data['token'];
        final refresh = data['refreshToken'] ?? data['refresh_token'] ?? '';
        final expires = data['expiresIn'] ?? data['expires_in'] ?? 3600;

        if (token != null && '$token'.isNotEmpty) {
          final int expiryInt = expires is int ? expires : (int.tryParse('$expires') ?? 3600);
          await ConfigPreference.updateMorTokens('$token', '$refresh', expiryInt);
          Logger().i('Deferred MoR login successful.');
          success = true;
        } else {
          Logger().w('MoR login returned 200 but missing token.');
          success = false;
        }
      },
      onFailure: (error, response) {
        Logger().e('Deferred MoR login failed: $error');
        success = false;
      },
    );

    return success;
  }

  void showMorCredentialsRequiredDialog({String action = 'perform this action'}) {
    Get.dialog(
      Dialog(
        backgroundColor: Get.theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.amber,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'MoR Setup Required',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Get.theme.textTheme.bodyLarge?.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'To $action, your branch must have Ministry of Revenues (MoR) credentials configured.\n\nPlease contact support to set up your MoR credentials.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Get.theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> performMorLogin() async {
    isLoggingIn.value = true;

    await ApiService.login(
      onSuccess: (response) async {
        final data = response.data['data'];
        if (data != null) {
          final token = data['accessToken'];
          final refresh = data['refreshToken'] ?? '';
          final expires = data['expiresIn'] ?? 3600;
          await ConfigPreference.updateMorTokens(token, refresh, expires);
          Logger().i('MoR login successful.');
          Get.offAllNamed('/dashboard');
        } else {
          Logger().w('MoR login returned 200 but no token payload.');
        }
        isLoggingIn.value = false;
      },
      onFailure: (error, response) {
        Logger().e('MoR login failed: $error');
        _handleError(error, response);
        isLoggingIn.value = false;
        Get.snackbar(
          'MoR Login Failed',
          'Could not authenticate with MoR. Status: ${response.statusCode}',
        );
      },
    );
  }

  String? _tokenFromResponse(dynamic response) {
    if (response is! Map) return null;
    final data = response['data'] is Map ? response['data'] : response;
    return '${data['accessToken'] ?? data['access_token'] ?? data['token']}' ==
            'null'
        ? null
        : '${data['accessToken'] ?? data['access_token'] ?? data['token']}';
  }

  String? _idFromResponse(dynamic response) {
    if (response is! Map) return null;
    final data = response['data'] is Map ? response['data'] : response;
    final id = data['company_id'] ?? data['companyId'] ?? data['id'];
    return id == null ? null : '$id';
  }

  void _handleError(dynamic error, dynamic response) {
    String errorMsg = "An error occurred while processing your request";

    if (error is dio_lib.DioException) {
      errorMsg = DioConfig.convertDioError(error);
      Logger().d(errorMsg);
      if (error.response?.data != null) {
        final backendMsg = _parseMessage(error.response!.data);
        Logger().d(backendMsg);
        if (backendMsg != null) errorMsg = backendMsg;
      }
    } else if (response != null && response.data != null) {
      final backendMsg = _parseMessage(response.data);
      Logger().d(backendMsg);
      if (backendMsg != null) errorMsg = backendMsg;
    }
    Get.snackbar('Error', errorMsg, snackPosition: SnackPosition.BOTTOM);
  }

  String? _parseMessage(dynamic data) {
    if (data == null) return null;
    if (data is! Map) return data.toString();
    final dynamic message = data['message'] ?? data['messages'];
    if (message == null) return null;

    if (message is List) {
      return message.join('\n');
    }
    return message.toString();
  }
}
