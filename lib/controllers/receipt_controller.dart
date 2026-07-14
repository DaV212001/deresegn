import 'package:get/get.dart';

import '../config/app_settings.dart';
import '../config/config_preference.dart';
import '../models/receipt_models.dart';
import '../services/api_service.dart';

class ReceiptController extends GetxController {
  var isSubmittingReceipt = false.obs;
  var isSubmittingWithholding = false.obs;

  Future<void> registerSalesReceipt(String invoiceIrn, String amount) async {
    isSubmittingReceipt.value = true;
    final tin = await ConfigPreference.getTin() ?? '0000037187';
    final systemNumber = await AppSettings.getSystemNumber();
    final cashierName = await AppSettings.getCashierName();

    final request = ReceiptRegisterRequest(
      receiptNumber: "${DateTime.now().millisecondsSinceEpoch}",
      receiptType: "Sales Receipts",
      reason: "Payment for goods purchased",
      receiptDate: DateTime.now().toIso8601String(),
      receiptCounter: "1",
      sourceSystemType: "POS",
      sourceSystemNumber: systemNumber,
      receiptCurrency: "ETB",
      collectedAmount: amount,
      sellerTIN: tin,
      invoices: [
        {
          "InvoiceIRN": invoiceIrn,
          "PaymentCoverage": "FULL",
          "InvoicePaidAmount": amount,
          "TotalAmount": amount,
        },
      ],
      transactionDetails: {
        "ModeOfPayment": "CASH",
        "DocumentNumber": "46",
        "CollectorName": cashierName,
      },
    );

    await ApiService.registerReceipt(
      request,
      onSuccess: (r) => Get.snackbar('Success', 'Sales Receipt registered.'),
      onFailure: (e, r) => Get.snackbar('Error', 'Failed to register receipt.'),
    );
    isSubmittingReceipt.value = false;
  }

  Future<void> registerWithholding(
    String invoiceIrn,
    String buyerTin,
    double pretaxAmount,
  ) async {
    isSubmittingWithholding.value = true;
    final systemNumber = await AppSettings.getSystemNumber();

    final request = WithholdingReceiptRequest(
      receiptNumber: "WHT-${DateTime.now().millisecondsSinceEpoch}",
      reason: "Withhold for goods purchased",
      receiptCounter: "1",
      manualReceiptNumber: (DateTime.now().millisecondsSinceEpoch % 100000)
          .toString(),
      sourceSystemType: "POS",
      sourceSystemNumber: systemNumber,
      buyerTIN: buyerTin,
      invoiceDetail: {"InvoiceIRN": invoiceIrn, "Currency": "ETB"},
      withholdDetail: {
        "Type": "TWHT",
        "PreTaxAmount": double.parse(pretaxAmount.toStringAsFixed(2)),
        "WithholdingAmount": double.parse(
          (pretaxAmount * 0.02).toStringAsFixed(2),
        ),
      },
    );

    await ApiService.registerWithholdingReceipt(
      request,
      onSuccess: (r) => Get.snackbar('Success', 'Withholding registered.'),
      onFailure: (e, r) =>
          Get.snackbar('Error', 'Failed to register withholding.'),
    );
    isSubmittingWithholding.value = false;
  }
}
