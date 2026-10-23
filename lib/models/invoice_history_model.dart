import 'dart:convert';
import 'package:get/get.dart';
import '../services/cancelled_invoices_storage.dart';

class InvoiceHistoryResponse {
  final List<InvoiceSummary> data;
  final PaginationData pagination;

  InvoiceHistoryResponse({required this.data, required this.pagination});

  factory InvoiceHistoryResponse.fromJson(Map<String, dynamic> json) {
    return InvoiceHistoryResponse(
      data: (json['data'] as List<dynamic>?)
              ?.map(
                (item) => InvoiceSummary.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      pagination: PaginationData.fromJson(
        json['pagination'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data.map((item) => item.toJson()).toList(),
      'pagination': pagination.toJson(),
    };
  }
}

class PaginationData {
  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;

  PaginationData({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  factory PaginationData.fromJson(Map<String, dynamic> json) {
    return PaginationData(
      currentPage: json['current_page'] is int
          ? json['current_page'] as int
          : int.tryParse(json['current_page']?.toString() ?? '1') ?? 1,
      perPage: json['per_page'] is int
          ? json['per_page'] as int
          : int.tryParse(json['per_page']?.toString() ?? '15') ?? 15,
      total: json['total'] is int
          ? json['total'] as int
          : int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      lastPage: json['last_page'] is int
          ? json['last_page'] as int
          : int.tryParse(json['last_page']?.toString() ?? '1') ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_page': currentPage,
      'per_page': perPage,
      'total': total,
      'last_page': lastPage,
    };
  }
}

class InvoiceSummary {
  final int id;
  final String? irn;
  final String? documentNumber;
  final String? status; // 'A' for Active, 'C' for Cancelled
  final String? ackDate;
  final String? signedQr;
  final String? signedInvoice;
  final BuyerInfo buyer;
  final TotalsInfo totals;
  final String? transactionType;
  final String? createdAt;
  final String? updatedAt;

  // The request payload contains the full original submission
  final Map<String, dynamic>? requestPayload;
  final String? cancellationReason;

  bool get isCancelled {
    final s = status?.toUpperCase();
    if (s == 'C' || s == 'CANCELLED') return true;
    if (irn != null && CancelledInvoicesStorage.isCancelled(irn)) return true;

    final payload = requestPayload;
    if (payload != null) {
      final pStatus = (payload['Status'] ??
              payload['status'] ??
              payload['InvoiceStatus'] ??
              payload['invoiceStatus'] ??
              payload['DocumentStatus'] ??
              payload['documentStatus'])
          ?.toString()
          .toUpperCase();
      if (pStatus == 'C' || pStatus == 'CANCELLED') return true;

      if (payload['is_cancelled'] == true ||
          payload['IsCancelled'] == true ||
          payload['isCancelled'] == true) {
        return true;
      }

      if (payload['CancellationDetails'] != null ||
          payload['cancellationDetails'] != null ||
          payload['cancellation_details'] != null ||
          payload['CancellationReason'] != null ||
          payload['cancellation_reason'] != null ||
          payload['CancelReason'] != null ||
          payload['cancel_reason'] != null) {
        return true;
      }
    }
    return false;
  }

  String? get cancellationReasonDescription {
    final rawReason = cancellationReason ??
        (irn != null ? CancelledInvoicesStorage.getReason(irn) : null) ??
        _extractReasonFromPayload();
    if (rawReason == null || rawReason.trim().isEmpty) return null;
    final trimmed = rawReason.trim();
    switch (trimmed) {
      case '1':
        return 'reason_code_1'.tr;
      case '2':
        return 'reason_code_2'.tr;
      case '3':
        return 'reason_code_3'.tr;
      case '4':
        return 'reason_code_4'.tr;
      default:
        return trimmed;
    }
  }

  String? _extractReasonFromPayload() {
    final payload = requestPayload;
    if (payload == null) return null;
    final cd = payload['CancellationDetails'] ??
        payload['cancellationDetails'] ??
        payload['cancellation_details'];
    if (cd is Map) {
      final r = cd['Reason'] ??
          cd['reason'] ??
          cd['ReasonCode'] ??
          cd['reasonCode'] ??
          cd['reason_code'];
      if (r != null) return r.toString();
    }
    final direct = payload['CancellationReason'] ??
        payload['cancellation_reason'] ??
        payload['CancelReason'] ??
        payload['cancel_reason'];
    if (direct != null) return direct.toString();
    return null;
  }

  String get rawDocumentType {
    final payload = requestPayload;
    final docType = payload?['DocumentDetails']?['Type']?.toString().toUpperCase() ??
        payload?['documentDetails']?['type']?.toString().toUpperCase() ??
        'INV';
    final payTerm = payload?['PaymentDetails']?['PaymentTerm']?.toString().toUpperCase() ??
        payload?['paymentDetails']?['paymentTerm']?.toString().toUpperCase() ??
        'IMMEDIATE';
    final payMode = payload?['PaymentDetails']?['Mode']?.toString().toUpperCase() ??
        payload?['paymentDetails']?['mode']?.toString().toUpperCase() ??
        '';

    if (docType == 'CRE' || docType == 'CN') return 'CREDIT_NOTE';
    if (docType == 'DEB' || docType == 'DN') return 'DEBIT_NOTE';
    if (docType == 'TWTH') return 'WITHHOLDING';
    if (payTerm == 'CREDIT' ||
        payMode == 'CREDIT' ||
        payTerm.contains('NET') ||
        payTerm.contains('DAY')) {
      return 'CREDIT_SALE';
    }
    return 'CASH_SALE';
  }

  String get documentType {
    switch (rawDocumentType) {
      case 'CREDIT_NOTE':
        return 'credit_note'.tr;
      case 'DEBIT_NOTE':
        return 'debit_note'.tr;
      case 'WITHHOLDING':
        return 'withholding_receipt'.tr;
      case 'CREDIT_SALE':
        return 'credit_sale'.tr;
      case 'CASH_SALE':
      default:
        return 'cash_sale'.tr;
    }
  }

  String? get referenceIrn {
    final payload = requestPayload;
    final ref = payload?['ReferenceDetails']?['PreviousIrn'] ??
        payload?['ReferenceDetails']?['RelatedDocument'] ??
        payload?['referenceDetails']?['previousIrn'] ??
        payload?['referenceDetails']?['relatedDocument'];
    if (ref != null && ref.toString().isNotEmpty && ref.toString() != 'null') {
      return ref.toString();
    }
    return null;
  }

  InvoiceSummary({
    required this.id,
    this.irn,
    this.documentNumber,
    this.status,
    this.ackDate,
    this.signedQr,
    this.signedInvoice,
    required this.buyer,
    required this.totals,
    this.transactionType,
    this.createdAt,
    this.updatedAt,
    this.requestPayload,
    this.cancellationReason,
  });

  factory InvoiceSummary.fromJson(Map<String, dynamic> json) {
    dynamic payload = json['request_payload'];
    if (payload is String) {
      try {
        payload = jsonDecode(payload);
      } catch (_) {}
    }
    final payloadMap = payload is Map<String, dynamic> ? payload : null;

    final docNum = json['document_number'] ??
        json['DocumentNumber'] ??
        json['documentNumber'] ??
        payloadMap?['DocumentDetails']?['DocumentNumber'] ??
        payloadMap?['documentDetails']?['documentNumber'] ??
        payloadMap?['DocumentNumber'];

    final cancelReason = json['cancellation_reason'] ??
        json['cancel_reason'] ??
        json['cancellation_reason_code'] ??
        json['cancellation_code'] ??
        payloadMap?['CancellationDetails']?['Reason'] ??
        payloadMap?['CancellationDetails']?['ReasonCode'] ??
        payloadMap?['cancellationDetails']?['reason'] ??
        payloadMap?['cancellationDetails']?['reasonCode'] ??
        payloadMap?['CancellationReason'] ??
        payloadMap?['cancellation_reason'] ??
        payloadMap?['CancelReason'] ??
        payloadMap?['cancel_reason'];

    final rawId = json['id'];
    final int parsedId = (rawId is int)
        ? rawId
        : int.tryParse(rawId?.toString() ?? '0') ?? 0;

    return InvoiceSummary(
      id: parsedId,
      irn: json['irn'] as String?,
      documentNumber: docNum?.toString(),
      status: json['status'] as String?,
      ackDate: json['ack_date'] as String?,
      signedQr: json['signed_qr'] as String?,
      signedInvoice: json['signed_invoice'] as String?,
      buyer: BuyerInfo.fromJson(json['buyer'] as Map<String, dynamic>? ?? {}),
      totals: TotalsInfo.fromJson(
        json['totals'] as Map<String, dynamic>? ?? {},
      ),
      transactionType: json['transaction_type'] as String?,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      requestPayload: payloadMap,
      cancellationReason: cancelReason?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'irn': irn,
      'document_number': documentNumber,
      'status': status,
      'ack_date': ackDate,
      'signed_qr': signedQr,
      'signed_invoice': signedInvoice,
      'buyer': buyer.toJson(),
      'totals': totals.toJson(),
      'transaction_type': transactionType,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'request_payload': requestPayload,
      'cancellation_reason': cancellationReason,
    };
  }

  InvoiceSummary copyWith({
    int? id,
    String? irn,
    String? documentNumber,
    String? status,
    String? ackDate,
    String? signedQr,
    String? signedInvoice,
    BuyerInfo? buyer,
    TotalsInfo? totals,
    String? transactionType,
    String? createdAt,
    String? updatedAt,
    Map<String, dynamic>? requestPayload,
    String? cancellationReason,
  }) {
    return InvoiceSummary(
      id: id ?? this.id,
      irn: irn ?? this.irn,
      documentNumber: documentNumber ?? this.documentNumber,
      status: status ?? this.status,
      ackDate: ackDate ?? this.ackDate,
      signedQr: signedQr ?? this.signedQr,
      signedInvoice: signedInvoice ?? this.signedInvoice,
      buyer: buyer ?? this.buyer,
      totals: totals ?? this.totals,
      transactionType: transactionType ?? this.transactionType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      requestPayload: requestPayload ?? this.requestPayload,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }
}

class BuyerInfo {
  final String? tin;
  final String? legalName;
  final String? phone;
  final String? email;
  final String? city;
  final String? region;

  BuyerInfo({
    this.tin,
    this.legalName,
    this.phone,
    this.email,
    this.city,
    this.region,
  });

  factory BuyerInfo.fromJson(Map<String, dynamic> json) {
    return BuyerInfo(
      tin: json['tin'] as String?,
      legalName: json['legal_name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tin': tin,
      'legal_name': legalName,
      'phone': phone,
      'email': email,
      'city': city,
      'region': region,
    };
  }
}

class TotalsInfo {
  final String? totalValue;
  final String? taxValue;
  final String? discount;
  final String? exciseValue;
  final String? currency;

  TotalsInfo({
    this.totalValue,
    this.taxValue,
    this.discount,
    this.exciseValue,
    this.currency,
  });

  factory TotalsInfo.fromJson(Map<String, dynamic> json) {
    return TotalsInfo(
      totalValue: json['total_value']?.toString(),
      taxValue: json['tax_value']?.toString(),
      discount: json['discount']?.toString(),
      exciseValue: json['excise_value']?.toString(),
      currency: json['currency']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_value': totalValue,
      'tax_value': taxValue,
      'discount': discount,
      'excise_value': exciseValue,
      'currency': currency,
    };
  }
}
