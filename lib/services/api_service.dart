import 'package:deresegn/config/config_preference.dart';
import 'package:dio/dio.dart';

import '../models/auth_models.dart';
import '../models/invoice_history_model.dart';
import '../models/invoice_models.dart';
import '../models/receipt_models.dart';
import 'dio_service.dart';

class ApiService {
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

  static Future<void> login(
    LoginRequest request, {
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioPost(
      path: '/api/login',
      data: request.toJson(),
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
      path: '/api/receipt/register',
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
      data: request.toJson(),
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  static Future<void> fetchSupplies({
    Function(List<SupplyItem>)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    await DioService.dioGet(
      path: '/api/supplies',
      options: Options(
        headers: {
          'Authorization': "Bearer ${ConfigPreference.getAccessToken()}",
        },
      ),
      onSuccess: (response) {
        if (onSuccess != null && response.data != null) {
          final List<dynamic> data = response.data;
          final items = data.map((json) => SupplyItem.fromJson(json)).toList();
          onSuccess(items);
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
    await DioService.dioPost(
      path: '/api/supplies',
      options: Options(
        headers: {
          'Authorization': "Bearer ${ConfigPreference.getAccessToken()}",
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
    await DioService.dioPost(
      path: '/api/supplies/$id',
      options: Options(
        headers: {
          'Authorization': "Bearer ${ConfigPreference.getAccessToken()}",
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
    await DioService.dioDelete(
      path: '/api/supplies/$id',
      options: Options(
        headers: {
          'Authorization': "Bearer ${ConfigPreference.getAccessToken()}",
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
