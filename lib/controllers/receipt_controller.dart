import 'package:get/get.dart';

import '../config/app_settings.dart';
import '../config/config_preference.dart';
import '../models/receipt_models.dart';
import '../services/api_service.dart';
import 'invoice_controller.dart';

class ReceiptController extends GetxController {
  var isSubmittingReceipt = false.obs;
  var isSubmittingWithholding = false.obs;

  Future<ReceiptSummary?> registerSalesReceipt(
    String invoiceIrn,
    String amount,
    String documentNumber,
    String invoiceTotal, {
    bool showSnackbar = true,
  }) async {
    Get.log(
      "Registering Receipt for IRN: $invoiceIrn, DocNum: $documentNumber, Total: $invoiceTotal",
    );
    isSubmittingReceipt.value = true;
    ReceiptSummary? result;

    final tin = await ConfigPreference.getTin() ?? '0000037187';
    final systemNumber = await AppSettings.getSystemNumber();
    final cashierName = await AppSettings.getCashierName();

    final request = ReceiptRegisterRequest(
      receiptNumber: "${DateTime.now().millisecondsSinceEpoch}",
      receiptType: "Sales Receipts",
      reason: "Payment for goods purchased",
      receiptDate: DateTime.now().toUtc().toIso8601String(),
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
          "TotalAmount": invoiceTotal,
        },
      ],
      transactionDetails: {
        "ModeOfPayment": "CASH",
        "DocumentNumber": int.tryParse(documentNumber) ?? documentNumber,
        "CollectorName": cashierName,
      },
    );

    await ApiService.registerReceipt(
      request,
      onSuccess: (r) {
        if (showSnackbar) Get.snackbar('Success', 'Sales Receipt registered.');
        if (r.data != null && r.data['data'] != null) {
          result = ReceiptSummary.fromJson(r.data['data']);
        } else if (r.data != null && r.data['body'] != null) {
          result = ReceiptSummary.fromJson(r.data['body']);
        } else if (r.data != null) {
          // Sometimes the object is directly in the response
          result = ReceiptSummary.fromJson(r.data);
        }

        if (Get.isRegistered<ReceiptFetchController>(tag: invoiceIrn)) {
          Get.find<ReceiptFetchController>(tag: invoiceIrn).fetchReceipts();
        }
      },
      onFailure: (e, r) {
        String errorMsg = 'Failed to register receipt';
        if (r.data != null) {
          // Use the same error parsing logic as InvoiceController
          final controller = Get.find<InvoiceController>();
          final parsed = controller.parseMessage(r.data);
          if (parsed != null) errorMsg = parsed;
        }
        if (showSnackbar) {
          Get.snackbar('Error', errorMsg, snackPosition: SnackPosition.BOTTOM);
        }
      },
    );
    isSubmittingReceipt.value = false;
    return result;
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

class ReceiptFetchController extends GetxController {
  final String invoiceIrn;
  ReceiptFetchController({required this.invoiceIrn});

  var isLoading = true.obs;
  var receipts = <ReceiptSummary>[].obs;
  var errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchReceipts();
  }

  Future<void> fetchReceipts() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      await ApiService.fetchReceiptsByIrn(
        invoiceIrn,
        onSuccess: (data) {
          if (data is List) {
            receipts.value = data
                .map((e) => ReceiptSummary.fromJson(e))
                .toList();
          } else if (data is Map<String, dynamic>) {
            receipts.value = [ReceiptSummary.fromJson(data)];
          } else {
            receipts.value = [];
          }
        },
        onFailure: (error, response) {
          errorMessage.value = 'Failed to load receipts';
        },
      );
    } catch (e) {
      errorMessage.value = 'An error occurred';
    } finally {
      isLoading.value = false;
    }
  }
}
