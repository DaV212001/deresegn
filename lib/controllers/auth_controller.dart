import 'dart:async';
import 'package:flutter/material.dart';
import 'package:deresegn/config/dio_config.dart';
import 'package:dio/dio.dart' as dio_lib;
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../config/config_preference.dart';
import '../models/auth_models.dart';
import '../models/company_models.dart';
import '../screens/branch_certificate_screen.dart';
import '../screens/otp_verification_screen.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import '../utils/phone_utils.dart';

class AuthController extends GetxController {
  var isLinked = false.obs;
  var isLoggingIn = false.obs;
  var isCompanyLoading = false.obs;
  var isMorAuthenticating = false.obs;
  static Future<bool>? _morAuthFuture;

  // OTP state variables
  var isOtpLoading = false.obs;
  var isResendingOtp = false.obs;
  var otpCooldownSeconds = 0.obs;
  Timer? _otpCooldownTimer;
  bool registrationRequiresOtp = false;

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
    _otpCooldownTimer?.cancel();
    super.onClose();
  }

  void startOtpCooldown([int seconds = 60]) {
    _otpCooldownTimer?.cancel();
    otpCooldownSeconds.value = seconds;
    _otpCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (otpCooldownSeconds.value <= 1) {
        timer.cancel();
        otpCooldownSeconds.value = 0;
      } else {
        otpCooldownSeconds.value--;
      }
    });
  }

  Future<bool> verifyOtp({
    required String phone,
    required String code,
    bool isCompany = true,
  }) async {
    if (code.trim().length != 6) {
      Get.snackbar('Invalid Code', 'Please enter a valid 6-digit verification code.');
      return false;
    }
    isOtpLoading.value = true;
    bool success = false;
    final authPhone = PhoneUtils.formatForAuth(phone.trim());

    if (isCompany) {
      await ApiService.verifyCompanyOtp(
        phone: authPhone,
        code: code.trim(),
        onSuccess: (response) async {
          success = true;
          isOtpLoading.value = false;
          final body = response.data is Map ? response.data : <String, dynamic>{};
          final token = body['token'] ?? body['data']?['token'];
          if (token != null) {
            await ConfigPreference.updateCompanyToken(token.toString());
          }
          final user = body['user'] is Map ? body['user'] as Map : null;
          if (user != null && user['company_id'] != null) {
            await ConfigPreference.saveCompanyContext(
              companyId: user['company_id'].toString(),
            );
          }
          final branch = body['branch'] is Map ? body['branch'] as Map : null;
          if (branch != null) {
            if (branch['id'] != null) {
              await ConfigPreference.saveBranchId(branch['id'].toString());
            }
            final rawPkgId = branch['package_id'] ?? branch['packageId'] ?? body['package_id'];
            final packageId = rawPkgId != null ? int.tryParse('$rawPkgId') : null;
            final expiry = branch['expired_date'] ??
                branch['expiredDate'] ??
                branch['expiry_date'] ??
                body['expired_date'];
            final paid = branch['payment_date'] ??
                branch['paid_date'] ??
                branch['paid_at'] ??
                body['payment_date'] ??
                body['paid_date'] ??
                body['paid_at'];

            await ConfigPreference.saveBranchSubscription(
              status: branch['status']?.toString() ?? 'pending',
              packageId: packageId,
              expiredDate: expiry?.toString(),
              paidDate: paid?.toString(),
              phone: branch['phone_number']?.toString(),
              email: branch['email']?.toString(),
            );
          }
          await _persistCompanyProfileFromMaps(
            root: body,
            branch: branch,
            user: user,
            fallbackPhone: authPhone,
          );
        },
        onFailure: (error, response) {
          isOtpLoading.value = false;
          _handleError(error, response);
        },
      );
    } else {
      await ApiService.verifyBranchOtp(
        phoneNumber: authPhone,
        code: code.trim(),
        onSuccess: (response) {
          success = true;
          isOtpLoading.value = false;
        },
        onFailure: (error, response) {
          isOtpLoading.value = false;
          _handleError(error, response);
        },
      );
    }
    return success;
  }

  Future<bool> resendOtp({
    required String phone,
    bool isCompany = true,
  }) async {
    if (otpCooldownSeconds.value > 0) {
      Get.snackbar(
        'Please wait',
        'You can request a new code in ${otpCooldownSeconds.value}s.',
      );
      return false;
    }

    isResendingOtp.value = true;
    bool success = false;
    final authPhone = PhoneUtils.formatForAuth(phone.trim());

    if (isCompany) {
      await ApiService.resendCompanyOtp(
        phone: authPhone,
        onSuccess: (response) {
          success = true;
          isResendingOtp.value = false;
          startOtpCooldown(60);
          final msg = _parseMessage(response.data) ?? 'OTP resent successfully.';
          Get.snackbar(
            'Code Sent',
            msg,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade800,
            colorText: Colors.white,
          );
        },
        onFailure: (error, response) {
          isResendingOtp.value = false;
          _handleError(error, response);
        },
      );
    } else {
      await ApiService.resendBranchOtp(
        phoneNumber: authPhone,
        onSuccess: (response) {
          success = true;
          isResendingOtp.value = false;
          startOtpCooldown(60);
          final msg = _parseMessage(response.data) ?? 'OTP resent successfully.';
          Get.snackbar(
            'Code Sent',
            msg,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade800,
            colorText: Colors.white,
          );
        },
        onFailure: (error, response) {
          isResendingOtp.value = false;
          _handleError(error, response);
        },
      );
    }
    return success;
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
    final authPhone = PhoneUtils.formatForAuth(phone.trim());
    await ApiService.registerCompany(
      CompanyRegisterRequest(
        companyName: companyName,
        tinNumber: tin,
        ownerName: owner,
        phone: authPhone,
        password: password,
        email: email,
        website: website,
      ),
      onSuccess: (response) async {
        final body = response.data is Map ? response.data : <String, dynamic>{};
        final user = body['user'] is Map ? body['user'] as Map : null;
        final branch = body['branch'] is Map ? body['branch'] as Map : null;
        final token = _tokenFromResponse(body);

        if (token != null) {
          await ConfigPreference.updateCompanyToken(token);
        }

        final compId = user?['company_id']?.toString() ?? _idFromResponse(body) ?? '';
        if (compId.isNotEmpty) {
          await ConfigPreference.saveCompanyContext(
            companyId: compId,
            branchId: branch?['id']?.toString(),
          );
        }

        if (branch != null) {
          final branchStatus = '${branch['status'] ?? 'pending'}'.toLowerCase();
          final rawPkgId = branch['package_id'] ?? branch['packageId'] ?? body['package_id'];
          final packageId = rawPkgId != null ? int.tryParse('$rawPkgId') : null;
          final expiry = branch['expired_date'] ??
              branch['expiredDate'] ??
              branch['expiry_date'] ??
              body['expired_date'];
          final paid = branch['payment_date'] ??
              branch['paid_date'] ??
              branch['paid_at'] ??
              body['payment_date'] ??
              body['paid_date'] ??
              body['paid_at'];

          await ConfigPreference.saveBranchSubscription(
            status: branchStatus,
            packageId: packageId,
            expiredDate: expiry?.toString(),
            paidDate: paid?.toString(),
            phone: branch['phone_number']?.toString() ?? authPhone,
            email: branch['email']?.toString() ?? email,
          );
        }

        await _persistCompanyProfileFromMaps(
          root: body,
          branch: branch,
          user: user,
          fallbackCompanyName: companyName,
          fallbackTin: tin,
          fallbackOwnerName: owner,
          fallbackPhone: authPhone,
          fallbackEmail: email,
        );

        success = true;

        // Check if OTP verification is required (e.g. user is unverified or response indicates OTP sent)
        final isVerified = user?['is_verified'] == true;
        final msg = '${body['message'] ?? ''}'.toLowerCase();
        final requiresOtp = !isVerified || msg.contains('otp') || msg.contains('verify');
        registrationRequiresOtp = requiresOtp;

        if (requiresOtp) {
          Logger().i('Registration initiated. Navigating to OTP verification for $authPhone');
          Get.to(() => OtpVerificationScreen(
                phone: authPhone,
                isCompanyRegistration: true,
                branchId: branch?['id'] != null ? int.tryParse('${branch!['id']}') : null,
                companyId: compId,
                ownerName: owner,
                email: email,
              ));
        }
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
    final authPhone = PhoneUtils.getExceptionPhoneNumber(phone.trim(), password) ??
        PhoneUtils.formatForAuth(phone.trim());
    await ApiService.loginCompany(
      CompanyLoginRequest(
        phone: authPhone,
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
        await _persistCompanyProfileFromMaps(
          root: body,
          branch: data['branch'] is Map ? data['branch'] as Map : null,
          user: data['user'] is Map ? data['user'] as Map : null,
          fallbackPhone: authPhone,
        );
        success = true;
      },
      onFailure: (e, r) {
        if (!handleLockoutIfPresent(e, r)) {
          final errorMsg = _parseMessage(r.data) ??
              _parseMessage((e is dio_lib.DioException) ? e.response?.data : null) ?? '';
          final lower = errorMsg.toLowerCase();
          if (lower.contains('verify your phone') ||
              lower.contains('please verify') ||
              lower.contains('verification required')) {
            Get.to(() => OtpVerificationScreen(
                  phone: authPhone,
                  isCompanyRegistration: true,
                  companyId: companyId,
                ));
            Get.snackbar(
              'Verification Required',
              'Please verify your phone number before logging in.',
              snackPosition: SnackPosition.BOTTOM,
            );
          } else {
            _handleError(e, r);
          }
        }
      },
    );
    isCompanyLoading.value = false;
    return success;
  }

  Future<void> performBranchLogin(String tin, String password) async {
    isLoggingIn.value = true;
    final authTin = PhoneUtils.getExceptionPhoneNumber(tin, password) ??
        (PhoneUtils.isValidEthiopianPhone(tin)
            ? PhoneUtils.formatForAuth(tin)
            : tin.trim());

    final request = BranchLoginRequest(tinNumber: authTin, password: password);

    await ApiService.loginBranch(
      request,
      onSuccess: (response) async {
        final data = response.data;
        final token = data['token'];
        final branchDetails = data['branch'] is Map ? data['branch'] : null;

        if (token != null && branchDetails != null) {
          final rawStatus = branchDetails['status'] ?? data['status'];
          final status = (rawStatus != null ? '$rawStatus' : '').toLowerCase();
          final rawPkgId = branchDetails['package_id'] ?? branchDetails['packageId'] ?? data['package_id'];
          final packageId = rawPkgId != null ? int.tryParse('$rawPkgId') : null;
          final expiredDate = (branchDetails['expired_date'] ??
                  branchDetails['expiredDate'] ??
                  branchDetails['expiry_date'] ??
                  data['expired_date'])
              ?.toString();
          final paidDate = (branchDetails['payment_date'] ??
                  branchDetails['paid_date'] ??
                  branchDetails['paid_at'] ??
                  data['payment_date'] ??
                  data['paid_date'] ??
                  data['paid_at'])
              ?.toString();

          await ConfigPreference.updateBranchToken(token);
          await ConfigPreference.saveBranchId('${branchDetails['id']}');
          unawaited(PushNotificationService.registerDeviceToken(branchToken: token, force: true));
          await ConfigPreference.saveBranchSubscription(
            status: status.isNotEmpty ? status : 'active',
            packageId: packageId,
            expiredDate: expiredDate,
            paidDate: paidDate,
            phone: branchDetails['phone_number']?.toString() ?? tin,
            email: branchDetails['email']?.toString(),
          );

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
          await _persistCompanyProfileFromMaps(
            root: data is Map ? data : null,
            branch: branchDetails is Map ? branchDetails : null,
            user: data is Map && data['user'] is Map ? data['user'] as Map : null,
            fallbackTin: '${branchDetails['tin_number'] ?? tin}',
            fallbackPhone: branchDetails['phone_number']?.toString() ?? authTin,
            fallbackEmail: branchDetails['email']?.toString(),
          );

          // Eagerly authenticate with MoR upon branch login so subsequent invoice registrations
          // have an active MoR session ready without delay or failure.
          try {
            await ensureMorAuth();
          } catch (e) {
            Logger().w('Initial MoR authentication during branch login encountered: $e');
          }

          isLoggingIn.value = false;

          // Always navigate to the dashboard upon login. Payment screen should never be
          // the first screen users navigate into, even if unpaid.
          // Payment screen will only pop up when users attempt to register invoices without paying.
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
          final errorMsg = _parseMessage(response.data) ??
              _parseMessage((error is dio_lib.DioException) ? error.response?.data : null) ?? '';
          final lower = errorMsg.toLowerCase();
          if (lower.contains('verify your phone') ||
              lower.contains('please verify') ||
              lower.contains('verification required')) {
            isLoggingIn.value = false;
            Get.to(() => OtpVerificationScreen(
                  phone: authTin,
                  isCompanyRegistration: false,
                ));
            Get.snackbar(
              'Verification Required',
              'Please verify your phone number with the OTP code.',
              snackPosition: SnackPosition.BOTTOM,
            );
            return;
          }
          _handleError(error, response);
        }
        isLoggingIn.value = false;
      },
    );
  }

  Future<bool> ensureMorAuth({bool forceRefresh = false}) async {
    final morToken = ConfigPreference.getMorToken();
    if (!forceRefresh && morToken != null && morToken.isNotEmpty) {
      return true;
    }

    if (_morAuthFuture != null) {
      Logger().d('MoR authentication already in progress, joining shared future...');
      return _morAuthFuture!;
    }

    final hasToken = (ConfigPreference.getAccessToken() != null &&
            ConfigPreference.getAccessToken()!.isNotEmpty) ||
        (ConfigPreference.getCompanyAccessToken() != null &&
            ConfigPreference.getCompanyAccessToken()!.isNotEmpty);
    if (!hasToken) {
      Logger().w('ensureMorAuth called but no branch or company token is available.');
      return false;
    }

    _morAuthFuture = _performMorLoginTask();
    try {
      final success = await _morAuthFuture!;
      return success;
    } finally {
      _morAuthFuture = null;
    }
  }

  Future<bool> _performMorLoginTask() async {
    isMorAuthenticating.value = true;
    bool success = false;
    try {
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
            Logger().i('MoR login successful.');
            success = true;
          } else {
            Logger().w('MoR login returned 200 but missing token.');
            success = false;
          }
        },
        onFailure: (error, response) {
          Logger().e('MoR login failed: $error');
          success = false;
        },
      );

      // If initial attempt failed, retry once after a short delay to handle transient gateway blips
      if (!success) {
        Logger().i('Retrying MoR login once after failure...');
        await Future.delayed(const Duration(milliseconds: 1000));
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
              Logger().i('MoR login successful on retry.');
              success = true;
            }
          },
          onFailure: (error, response) {
            Logger().e('MoR login retry failed: $error');
          },
        );
      }
    } catch (e) {
      Logger().e('Exception during MoR login task: $e');
      success = false;
    } finally {
      isMorAuthenticating.value = false;
    }

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
                'To $action, your branch must have an INSA digital certificate installed.\n\nWaiting for INSA? You can upload your certificate anytime from:\n⚙️ Settings > INSA Certificate',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Get.theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Get.back();
                      final branchId = int.tryParse(ConfigPreference.getBranchId() ?? '29') ?? 29;
                      Get.to(() => BranchCertificateScreen(
                            branchId: branchId,
                            email: ConfigPreference.getBranchEmail() ?? '',
                            phone: ConfigPreference.getBranchPhone() ?? '',
                            startAtUpload: true,
                          ));
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text(
                      'Upload Certificate Now',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text("I'll Upload Later from Settings"),
                  ),
                ],
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
    } else if (response != null && response.data != null) {
      final backendMsg = DioConfig.extractErrorMessage(response.data);
      if (backendMsg != null && backendMsg.isNotEmpty) errorMsg = backendMsg;
    } else if (error != null) {
      final backendMsg = DioConfig.extractErrorMessage(error);
      if (backendMsg != null && backendMsg.isNotEmpty) errorMsg = backendMsg;
    }

    Logger().e('AuthController Error: $errorMsg');
    Get.snackbar(
      'Error',
      errorMsg,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
    );
  }

  String? _parseMessage(dynamic data) {
    return DioConfig.extractErrorMessage(data);
  }

  Future<void> _persistCompanyProfileFromMaps({
    Map? root,
    Map? branch,
    Map? user,
    String? fallbackCompanyName,
    String? fallbackTin,
    String? fallbackOwnerName,
    String? fallbackPhone,
    String? fallbackEmail,
  }) async {
    String? pick(List<dynamic> candidates) {
      for (final c in candidates) {
        if (c != null && c.toString().trim().isNotEmpty && c.toString().trim() != 'null') {
          return c.toString().trim();
        }
      }
      return null;
    }

    final Map? dataMap = root?['data'] is Map ? root!['data'] as Map : null;
    final Map? companyMap = (branch?['company'] is Map
            ? branch!['company'] as Map
            : null) ??
        (root?['company'] is Map ? root!['company'] as Map : null) ??
        (dataMap?['company'] is Map ? dataMap!['company'] as Map : null) ??
        (user?['company'] is Map ? user!['company'] as Map : null);

    final resolvedCompanyName = pick([
      companyMap?['company_name'],
      companyMap?['legal_name'],
      companyMap?['trade_name'],
      companyMap?['name'],
      branch?['company_name'],
      branch?['legal_name'],
      branch?['trade_name'],
      root?['company_name'],
      dataMap?['company_name'],
      fallbackCompanyName,
      branch?['name'],
      branch?['branch_name'],
    ]);

    final resolvedBranchName = pick([
      branch?['branch_name'],
      branch?['name'],
    ]);

    final resolvedTin = pick([
      branch?['tin_number'],
      branch?['tin'],
      companyMap?['tin_number'],
      companyMap?['tin'],
      user?['tin_number'],
      user?['tin'],
      fallbackTin,
    ]);

    final resolvedOwnerName = pick([
      companyMap?['owner_name'],
      user?['owner_name'],
      user?['full_name'],
      user?['name'],
      branch?['owner_name'],
      branch?['manager_name'],
      branch?['cashier_name'],
      fallbackOwnerName,
    ]);

    final resolvedCity = pick([
      branch?['city'],
      companyMap?['city'],
    ]);

    final resolvedWoreda = pick([
      branch?['woreda'],
      branch?['wereda'],
      companyMap?['woreda'],
      companyMap?['wereda'],
    ]);

    final resolvedRegion = pick([
      branch?['region'],
      companyMap?['region'],
    ]);

    final resolvedVat = pick([
      branch?['vat_number'],
      branch?['vatNumber'],
      companyMap?['vat_number'],
      companyMap?['vatNumber'],
    ]);

    final resolvedSystemNumber = pick([
      branch?['system_number'],
      branch?['systemNumber'],
      companyMap?['system_number'],
    ]);

    final resolvedPhone = pick([
      branch?['phone_number'],
      branch?['phone'],
      companyMap?['phone'],
      companyMap?['phone_number'],
      user?['phone'],
      user?['phone_number'],
      fallbackPhone,
    ]);

    final resolvedEmail = pick([
      branch?['email'],
      companyMap?['email'],
      user?['email'],
      fallbackEmail,
    ]);

    await ConfigPreference.saveCompanyProfile(
      companyName: resolvedCompanyName,
      tin: resolvedTin,
      ownerName: resolvedOwnerName,
      branchName: resolvedBranchName,
      city: resolvedCity,
      woreda: resolvedWoreda,
      region: resolvedRegion,
      vatNumber: resolvedVat,
      systemNumber: resolvedSystemNumber,
      phone: resolvedPhone,
      email: resolvedEmail,
      loggedInPhone: fallbackPhone ?? resolvedPhone,
    );
  }
}
