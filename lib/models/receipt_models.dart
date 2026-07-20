class ReceiptRegisterRequest {
  final String receiptNumber;
  final String receiptType;
  final String reason;
  final String receiptDate;
  final String receiptCounter;
  final String? manualReceiptNumber;
  final String sourceSystemType;
  final String sourceSystemNumber;
  final String receiptCurrency;
  final String? exchangeRate;
  final String collectedAmount;
  final String sellerTIN;
  final List<Map<String, dynamic>> invoices;
  final Map<String, dynamic> transactionDetails;

  ReceiptRegisterRequest({
    required this.receiptNumber,
    required this.receiptType,
    required this.reason,
    required this.receiptDate,
    required this.receiptCounter,
    this.manualReceiptNumber,
    required this.sourceSystemType,
    required this.sourceSystemNumber,
    required this.receiptCurrency,
    this.exchangeRate,
    required this.collectedAmount,
    required this.sellerTIN,
    required this.invoices,
    required this.transactionDetails,
  });

  Map<String, dynamic> toJson() => {
    'ReceiptNumber': receiptNumber,
    'ReceiptType': receiptType,
    'Reason': reason,
    'ReceiptDate': receiptDate,
    'ReceiptCounter': receiptCounter,
    'ManualReceiptNumber': manualReceiptNumber,
    'SourceSystemType': sourceSystemType,
    'SourceSystemNumber': sourceSystemNumber,
    'ReceiptCurrency': receiptCurrency,
    'ExchangeRate': exchangeRate,
    'CollectedAmount': collectedAmount,
    'SellerTIN': sellerTIN,
    'Invoices': invoices,
    'TransactionDetails': transactionDetails,
  };
}

class WithholdingReceiptRequest {
  final String receiptNumber;
  final String reason;
  final String receiptCounter;
  final String manualReceiptNumber;
  final String sourceSystemType;
  final String sourceSystemNumber;
  final String buyerTIN;
  final Map<String, dynamic> invoiceDetail;
  final Map<String, dynamic> withholdDetail;

  WithholdingReceiptRequest({
    required this.receiptNumber,
    required this.reason,
    required this.receiptCounter,
    required this.manualReceiptNumber,
    required this.sourceSystemType,
    required this.sourceSystemNumber,
    required this.buyerTIN,
    required this.invoiceDetail,
    required this.withholdDetail,
  });

  Map<String, dynamic> toJson() => {
    'ReceiptNumber': receiptNumber,
    'Reason': reason,
    'ReceiptCounter': receiptCounter,
    'ManualReceiptNumber': manualReceiptNumber,
    'SourceSystemType': sourceSystemType,
    'SourceSystemNumber': sourceSystemNumber,
    'BuyerTIN': buyerTIN,
    'InvoiceDetail': invoiceDetail,
    'WithholdDetail': withholdDetail,
  };
}

class ReceiptSummary {
  final int? id;
  final String? morId;
  final String? status;
  final String? rrn;
  final String? invoiceIrn;
  final String? receiptNumber;
  final String? qr;
  final bool? isSuccess;
  final Map<String, dynamic>? requestPayload;
  final String? createdAt;

  ReceiptSummary({
    this.id,
    this.morId,
    this.status,
    this.rrn,
    this.invoiceIrn,
    this.receiptNumber,
    this.qr,
    this.isSuccess,
    this.requestPayload,
    this.createdAt,
  });

  factory ReceiptSummary.fromJson(Map<String, dynamic> json) {
    return ReceiptSummary(
      id: json['id'] as int?,
      morId: json['mor_id']?.toString(),
      status: json['status']?.toString(),
      rrn: json['rrn']?.toString(),
      invoiceIrn: json['invoice_irn']?.toString(),
      receiptNumber: json['receipt_number']?.toString(),
      qr: json['qr']?.toString(),
      isSuccess: json['is_success'] as bool?,
      requestPayload: json['request_payload'] as Map<String, dynamic>?,
      createdAt: json['created_at']?.toString(),
    );
  }
}
