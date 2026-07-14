class InvoiceHistoryResponse {
  final List<InvoiceSummary> data;
  final PaginationData pagination;

  InvoiceHistoryResponse({
    required this.data,
    required this.pagination,
  });

  factory InvoiceHistoryResponse.fromJson(Map<String, dynamic> json) {
    return InvoiceHistoryResponse(
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => InvoiceSummary.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      pagination: PaginationData.fromJson(json['pagination'] as Map<String, dynamic>),
    );
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
      currentPage: json['current_page'] ?? 1,
      perPage: json['per_page'] ?? 15,
      total: json['total'] ?? 0,
      lastPage: json['last_page'] ?? 1,
    );
  }
}

class InvoiceSummary {
  final int id;
  final String? irn;
  final String? documentNumber;
  final String? status; // 'A' for Active, etc.
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
  });

  factory InvoiceSummary.fromJson(Map<String, dynamic> json) {
    return InvoiceSummary(
      id: json['id'] as int,
      irn: json['irn'] as String?,
      documentNumber: json['document_number'] as String?,
      status: json['status'] as String?,
      ackDate: json['ack_date'] as String?,
      signedQr: json['signed_qr'] as String?,
      signedInvoice: json['signed_invoice'] as String?,
      buyer: BuyerInfo.fromJson(json['buyer'] as Map<String, dynamic>? ?? {}),
      totals: TotalsInfo.fromJson(json['totals'] as Map<String, dynamic>? ?? {}),
      transactionType: json['transaction_type'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      requestPayload: json['request_payload'] as Map<String, dynamic>?,
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
      totalValue: json['total_value'] as String?,
      taxValue: json['tax_value'] as String?,
      discount: json['discount'] as String?,
      exciseValue: json['excise_value'] as String?,
      currency: json['currency'] as String?,
    );
  }
}
