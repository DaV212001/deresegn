import 'package:deresegn/config/config_preference.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../models/auth_models.dart';
import '../models/company_models.dart';
import '../models/invoice_history_model.dart';
import '../models/invoice_models.dart';
import '../models/receipt_models.dart';
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

    await DioService.dioGet(
      path: '/api/invoices',
      queryParameters: queryParameters,
      options: Options(
        headers: {
          'Authorization': "Bearer ${ConfigPreference.getAccessToken()}",
        },
      ),
      onSuccess: (response) {
        if (onSuccess != null && response.data != null) {
          final data = InvoiceHistoryResponse.fromJson(response.data);
          onSuccess(data);
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
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
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

  /// Temporary test method to grab company owner token using test credentials
  static Future<String?> ensureCompanyToken() async {
    String? token = ConfigPreference.getCompanyAccessToken();
    if (token != null && token.isNotEmpty) {
      return token;
    }

    final candidates = [
      {'phone': '0949384998', 'password': 'Maru@123'},
      {'phone': '251949384998', 'password': 'Maru@123'},
      {'phone': '0949384998', 'password': 'Maru@123', 'company_id': 4},
      {'phone': '0949384998', 'password': 'Maru@123', 'company_id': 9},
      {'phone': '25191134567', 'password': 'password123'},
      {'phone': '251911234567', 'password': 'password123'},
    ];

    for (final cred in candidates) {
      try {
        Logger().i('🔑 [TEST] Attempting company login with ${cred['phone']} (payload: $cred)...');
        final payload = <String, dynamic>{
          'phone': cred['phone'],
          'password': cred['password'],
        };
        if (cred.containsKey('company_id')) {
          payload['company_id'] = cred['company_id'];
        }

        await DioService.dioPost(
          path: '/api/company/login',
          data: payload,
          onSuccess: (response) async {
            final body = response.data is Map ? response.data : <String, dynamic>{};
            final data = body['data'] is Map ? body['data'] : body;
            final grabbed = data['accessToken'] ?? data['access_token'] ?? data['token'];
            if (grabbed != null) {
              Logger().i('✅ [TEST] Successfully grabbed company token with ${cred['phone']}!');
              await ConfigPreference.updateCompanyToken('$grabbed');
              token = '$grabbed';
            }
          },
          onFailure: (error, response) {
            Logger().w('⚠️ [TEST] Company login failed for ${cred['phone']}: $error');
          },
        );
        if (token != null && token!.isNotEmpty) {
          return token;
        }
      } catch (e) {
        Logger().w('⚠️ [TEST] Exception logging in company for ${cred['phone']}: $e');
      }
    }
    return token;
  }

  static String _suppliesPath({String? id}) {
    final branchId = ConfigPreference.getBranchId();
    final base = (branchId != null && branchId.isNotEmpty)
        ? '/api/branches/$branchId/supplies'
        : '/api/supplies';
    return id != null ? '$base/$id' : base;
  }

  static Future<void> fetchSupplies({
    Function(List<SupplyItem>)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    final companyToken = await ensureCompanyToken();
    final effectiveToken = companyToken ?? ConfigPreference.getAccessToken();

    Logger().i('📦 [SUPPLIES] Fetching supplies using ${companyToken != null ? "COMPANY OWNER TOKEN" : "BRANCH TOKEN"} at ${_suppliesPath()}');

    await DioService.dioGet(
      path: _suppliesPath(),
      options: Options(
        headers: {
          'Authorization': "Bearer $effectiveToken",
          'token': "Bearer $effectiveToken",
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
    final companyToken = await ensureCompanyToken();
    final effectiveToken = companyToken ?? ConfigPreference.getAccessToken();

    await DioService.dioPost(
      path: _suppliesPath(),
      options: Options(
        headers: {
          'Authorization': "Bearer $effectiveToken",
          'token': "Bearer $effectiveToken",
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
    final companyToken = await ensureCompanyToken();
    final effectiveToken = companyToken ?? ConfigPreference.getAccessToken();

    await DioService.dioPost(
      path: _suppliesPath(id: id),
      options: Options(
        headers: {
          'Authorization': "Bearer $effectiveToken",
          'token': "Bearer $effectiveToken",
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
    final companyToken = await ensureCompanyToken();
    final effectiveToken = companyToken ?? ConfigPreference.getAccessToken();

    await DioService.dioDelete(
      path: _suppliesPath(id: id),
      options: Options(
        headers: {
          'Authorization': "Bearer $effectiveToken",
          'token': "Bearer $effectiveToken",
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
}
