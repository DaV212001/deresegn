import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:deresegn/config/config_preference.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../models/auth_models.dart';
import '../models/company_models.dart';
import '../models/invoice_history_model.dart';
import '../models/invoice_models.dart';
import '../models/otp_models.dart';
import '../models/payment_package_models.dart';
import '../models/receipt_models.dart';
import '../models/working_hours_model.dart';
import 'dio_service.dart';

class ApiService {
  static Future<void> registerCompany(
    CompanyRegisterRequest request, {
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioPost(
      path: '/api/company/register',
      data: request.toJson(),
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static Future<void> loginCompany(
    CompanyLoginRequest request, {
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioPost(
      path: '/api/company/login',
      data: request.toJson(),
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static Future<void> fetchCompanies({
    Function(List<CompanySummary>)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioGet(
      path: '/api/companies',
      onSuccess: (response) {
        final raw = response.data is Map
            ? (response.data['data'] ?? response.data['companies'] ?? [])
            : response.data;
        if (raw is List) {
          onSuccess?.call(
            raw
                .whereType<Map>()
                .map(
                  (e) => CompanySummary.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList(),
          );
        }
      },
      onFailure: onFailure,
    );
  }

  static Future<void> createBranch(
    FormData data, {
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioPost(
      path: '/api/branches',
      data: data,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${ConfigPreference.getCompanyAccessToken()}',
          'Content-Type': 'multipart/form-data',
        },
      ),
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static Future<void> fetchInvoices({
    int page = 1,
    String? startDate,
    String? endDate,
    Function(InvoiceHistoryResponse)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    final queryParameters = {'page': page.toString()};
    if (startDate != null) queryParameters['start_date'] = startDate;
    if (endDate != null) queryParameters['end_date'] = endDate;

    final token = ConfigPreference.getAccessToken() ?? ConfigPreference.getCompanyAccessToken();

    await DioService.dioGet(
      path: '/api/invoices',
      queryParameters: queryParameters,
      options: Options(
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': "Bearer $token",
        },
      ),
      onSuccess: (response) {
        if (onSuccess != null && response.data != null) {
          if (response.data is Map<String, dynamic>) {
            final data = InvoiceHistoryResponse.fromJson(response.data as Map<String, dynamic>);
            onSuccess(data);
          } else if (response.data is String) {
            try {
              final decoded = jsonDecode(response.data as String);
              if (decoded is Map<String, dynamic>) {
                final data = InvoiceHistoryResponse.fromJson(decoded);
                onSuccess(data);
                return;
              }
            } catch (_) {}
            if (onFailure != null) {
              onFailure(
                DioException(
                  requestOptions: response.requestOptions,
                  response: response,
                  type: DioExceptionType.badResponse,
                  message: 'Unexpected server response format.',
                ),
                response,
              );
            }
          }
        }
      },
      onFailure: onFailure,
    );
  }

  static Future<void> loginBranch(
    BranchLoginRequest request, {
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioPost(
      path: '/api/branch/login',
      data: request.toJson(),
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static Future<void> login({
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioPost(
      path: '/api/login',
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static Future<void> registerInvoice(
    InvoiceRegisterRequest request, {
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioPost(
      path: '/api/invoice/register',
      options: Options(
        headers: {
          'Authorization': "Bearer ${ConfigPreference.getAccessToken()}",
        },
      ),
      data: request.toJson(),
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static Future<void> cancelInvoice(
    InvoiceCancelRequest request, {
    FutureOr<void> Function(Response)? onSuccess,
    FutureOr<void> Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioPost(
      path: '/api/cancel/invoice',
      options: Options(
        headers: {
          'Authorization': "Bearer ${ConfigPreference.getAccessToken()}",
        },
      ),
      data: request.toJson(),
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static Future<void> verifyInvoice(
    InvoiceVerificationRequest request, {
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioPost(
      path: '/api/irn/verfiy',
      options: Options(
        headers: {
          'Authorization': "Bearer ${ConfigPreference.getAccessToken()}",
        },
      ),
      data: request.toJson(),
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static Future<void> registerReceipt(
    ReceiptRegisterRequest request, {
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioPost(
      path: '/api/receipt/sales',
      options: Options(
        headers: {
          'Authorization': "Bearer ${ConfigPreference.getAccessToken()}",
        },
      ),
      data: request.toJson(),
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static Future<void> registerWithholdingReceipt(
    WithholdingReceiptRequest request, {
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioPost(
      path: '/api/receipt/withholding',
      options: Options(
        headers: {
          'Authorization': "Bearer ${ConfigPreference.getAccessToken()}",
        },
      ),
      data: request.toJson(),
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static String _suppliesPath({String? id}) {
    final rawBranchId = ConfigPreference.getBranchId();
    final branchId = rawBranchId?.trim().replaceAll(RegExp(r'^/+'), '');
    final base = (branchId != null && branchId.isNotEmpty)
        ? '/api/branches/$branchId/supplies'
        : '/api/supplies';
    return id != null ? '$base/$id' : base;
  }

  static String? _effectiveSuppliesToken() {
    return ConfigPreference.getAccessToken() ?? ConfigPreference.getCompanyAccessToken();
  }

  static Future<void> fetchSupplies({
    Function(List<SupplyItem>)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    final effectiveToken = _effectiveSuppliesToken();

    Logger().i('📦 [SUPPLIES] Fetching supplies at ${_suppliesPath()}');

    await DioService.dioGet(
      path: _suppliesPath(),
      options: Options(
        headers: {
          if (effectiveToken != null && effectiveToken.isNotEmpty) ...{
            'Authorization': "Bearer $effectiveToken",
            'token': "Bearer $effectiveToken",
          },
        },
      ),
      onSuccess: (response) {
        if (onSuccess != null && response.data != null) {
          final raw = response.data is Map
              ? (response.data['data'] ?? response.data['supplies'] ?? [])
              : response.data;
          if (raw is List) {
            final items = raw
                .whereType<Map>()
                .map((json) => SupplyItem.fromJson(Map<String, dynamic>.from(json)))
                .toList();
            onSuccess(items);
          }
        }
      },
      onFailure: onFailure,
    );
  }

  static Future<void> createSupply(
    SupplyItem item, {
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    final effectiveToken = _effectiveSuppliesToken();

    await DioService.dioPost(
      path: _suppliesPath(),
      options: Options(
        headers: {
          if (effectiveToken != null && effectiveToken.isNotEmpty) ...{
            'Authorization': "Bearer $effectiveToken",
            'token': "Bearer $effectiveToken",
          },
        },
      ),
      data: item.toJson(),
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static Future<void> updateSupply(
    String id,
    SupplyItem item, {
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    final effectiveToken = _effectiveSuppliesToken();

    await DioService.dioPost(
      path: _suppliesPath(id: id),
      options: Options(
        headers: {
          if (effectiveToken != null && effectiveToken.isNotEmpty) ...{
            'Authorization': "Bearer $effectiveToken",
            'token': "Bearer $effectiveToken",
          },
        },
      ),
      data: item.toJson(),
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static Future<void> deleteSupply(
    String id, {
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    final effectiveToken = _effectiveSuppliesToken();

    await DioService.dioDelete(
      path: _suppliesPath(id: id),
      options: Options(
        headers: {
          if (effectiveToken != null && effectiveToken.isNotEmpty) ...{
            'Authorization': "Bearer $effectiveToken",
            'token': "Bearer $effectiveToken",
          },
        },
      ),
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static Future<void> fetchReceiptsByIrn(
    String irn, {
    Function(dynamic)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioGet(
      path: '/api/receipts/irn/$irn',
      options: Options(
        headers: {
          'Authorization': "Bearer ${ConfigPreference.getAccessToken()}",
        },
      ),
      onSuccess: (response) {
        if (onSuccess != null && response.data != null) {
          final data = response.data['data'];
          onSuccess(data);
        }
      },
      onFailure: onFailure,
    );
  }

  // --- OTP Verification & Resend Endpoints ---

  static Future<void> verifyCompanyOtp({
    required String phone,
    required String code,
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioPost(
      path: '/api/company/register/verify',
      data: CompanyOtpVerifyRequest(phone: phone, code: code).toJson(),
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static Future<void> resendCompanyOtp({
    required String phone,
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioPost(
      path: '/api/company/register/resend-otp',
      data: ResendOtpRequest(phone: phone).toJson(),
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static Future<void> resendBranchOtp({
    required String phoneNumber,
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioPost(
      path: '/api/branch/resend-otp',
      data: {'phone_number': phoneNumber},
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static Future<void> verifyBranchOtp({
    required String phoneNumber,
    required String code,
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioPost(
      path: '/api/branch/verify-phone',
      data: BranchOtpVerifyRequest(phoneNumber: phoneNumber, code: code).toJson(),
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  // --- Payment Packages Endpoints ---

  static Future<void> fetchPackages({
    Function(List<PaymentPackage>)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioGet(
      path: '/api/packages',
      onSuccess: (response) {
        if (onSuccess != null && response.data != null) {
          final raw = response.data is Map
              ? (response.data['data'] ?? response.data['packages'] ?? [])
              : response.data;
          if (raw is List) {
            final packages = raw
                .whereType<Map>()
                .map((e) => PaymentPackage.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            onSuccess(packages);
          }
        }
      },
      onFailure: onFailure,
    );
  }

  static Future<void> initializePayment({
    required PaymentInitializeRequest request,
    String? token,
    Function(PaymentInitializeResponse)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    final effectiveToken = token ??
        ConfigPreference.getCompanyAccessToken() ??
        ConfigPreference.getAccessToken();

    await DioService.dioPost(
      path: '/api/payment/initialize',
      data: request.toJson(),
      options: Options(
        headers: {
          if (effectiveToken != null && effectiveToken.isNotEmpty)
            'Authorization': 'Bearer $effectiveToken',
        },
      ),
      onSuccess: (response) {
        if (onSuccess != null && response.data != null) {
          onSuccess(PaymentInitializeResponse.fromJson(response.data));
        }
      },
      onFailure: onFailure,
    );
  }

  static Future<void> checkPaymentStatus({
    required String txRef,
    Function(PaymentStatusResponse)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioGet(
      path: '/api/payment/status/$txRef',
      onSuccess: (response) {
        if (onSuccess != null && response.data != null) {
          if (response.data is Map) {
            onSuccess(
              PaymentStatusResponse.fromJson(Map<String, dynamic>.from(response.data)),
            );
          }
        }
      },
      onFailure: onFailure,
    );
  }

  // --- Branch Working Hours Endpoints ---

  static Future<void> getBranchHours({
    required String branchId,
    Function(BranchWorkingHours)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioGet(
      path: '/api/branches/$branchId/hours',
      onSuccess: (response) {
        if (onSuccess != null && response.data != null) {
          if (response.data is Map) {
            onSuccess(
              BranchWorkingHours.fromJson(
                Map<String, dynamic>.from(response.data),
              ),
            );
          }
        }
      },
      onFailure: onFailure,
    );
  }

  static Future<void> updateBranchHours({
    required String branchId,
    required List<WorkingDayHour> hours,
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioPost(
      path: '/api/branches/$branchId/hours',
      data: {
        'hours': hours.map((h) => h.toJson()).toList(),
      },
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static Future<void> registerFcmToken({
    required String fcmToken,
    String? platform,
    String? branchToken,
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    final token = branchToken ?? ConfigPreference.getAccessToken();
    if (token == null || token.isEmpty) {
      Logger().w('⚠️ [FCM] Skipping device token registration: Branch bearer token is missing.');
      return;
    }

    final platformName = platform ??
        (kIsWeb
            ? 'web'
            : Platform.isAndroid
                ? 'android'
                : Platform.isIOS
                    ? 'ios'
                    : Platform.isWindows
                        ? 'windows'
                        : Platform.isMacOS
                            ? 'macos'
                            : Platform.isLinux
                                ? 'linux'
                                : 'unknown');

    final request = FcmTokenRegistrationRequest(
      fcmToken: fcmToken,
      platform: platformName,
    );

    final headers = <String, dynamic>{
      'Authorization': 'Bearer $token',
    };
    final branchId = ConfigPreference.getBranchId();
    if (branchId != null && branchId.isNotEmpty) {
      headers['Branch-Id'] = branchId;
    }

    await DioService.dioPost(
      path: '/api/fcm/token',
      data: request.toJson(),
      options: Options(headers: headers),
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }
}
