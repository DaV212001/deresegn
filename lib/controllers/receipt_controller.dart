import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_settings.dart';
import '../config/config_preference.dart';
import '../config/dio_config.dart';
import '../models/receipt_models.dart';
import '../services/api_service.dart';
import '../screens/payment_packages_screen.dart';
import 'auth_controller.dart';
import 'invoice_controller.dart';

class ReceiptController extends GetxController {
  var isSubmittingReceipt = false.obs;
  var isSubmittingWithholding = false.obs;

  Future<ReceiptSummary?> registerSalesReceipt(
    String invoiceIrn,
    String amount,
    String documentNumber,
    String invoiceTotal, {
    String modeOfPayment = 'CASH',
    String? referenceNumber,
    String? paymentServiceProvider,
    bool showSnackbar = true,
  }) async {
    Get.log(
      "Registering Receipt for IRN: $invoiceIrn, DocNum: $documentNumber, Total: $invoiceTotal, Mode: $modeOfPayment",
    );
    isSubmittingReceipt.value = true;
    ReceiptSummary? result;
    try {
      if (!ConfigPreference.isBranchActive()) {
        isSubmittingReceipt.value = false;
        if (showSnackbar) {
          Get.snackbar(
            'Subscription Required',
            'An active package is required to register receipts. Please select a package to proceed.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.amber.shade900,
            colorText: Colors.white,
            icon: const Icon(Icons.payment_rounded, color: Colors.white),
            duration: const Duration(seconds: 4),
          );
        }
        Get.to(() => PaymentPackagesScreen(
              currentStatus: ConfigPreference.getBranchStatus() ?? 'pending',
            ));
        return null;
      }

      final authController = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : Get.put(AuthController());
      final hasMorAuth = await authController.ensureMorAuth();
      if (!hasMorAuth) {
        isSubmittingReceipt.value = false;
        if (showSnackbar) {
          authController.showMorCredentialsRequiredDialog(action: 'register a receipt');
          Get.snackbar(
            'MoR Credentials Required',
            'Please contact support to set up your MoR credentials.',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        return null;
      }

    final tin = await ConfigPreference.getTin();
    final systemNumber = await AppSettings.getSystemNumber();
    final cashierName = await AppSettings.getCashierName();

    final Map<String, dynamic> txnDetails = {
      "ModeOfPayment": modeOfPayment,
      "DocumentNumber": int.tryParse(documentNumber) ?? documentNumber,
      "CollectorName": cashierName,
    };
    if (referenceNumber != null && referenceNumber.trim().isNotEmpty) {
      txnDetails["TransactionNumber"] = referenceNumber.trim();
    }
    if (paymentServiceProvider != null &&
        paymentServiceProvider.trim().isNotEmpty) {
      txnDetails["PaymentServiceProvider"] = paymentServiceProvider.trim();
    }

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
      transactionDetails: txnDetails,
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
        String errorMsg = e is DioException
            ? DioConfig.convertDioError(e)
            : (DioConfig.extractErrorMessage(r.data) ?? 'Failed to register receipt');
        if (showSnackbar) {
          Get.snackbar('Error', errorMsg, snackPosition: SnackPosition.BOTTOM);
        }
      },
    );
    } catch (e) {
      Get.log("Exception in registerSalesReceipt: $e");
    } finally {
      isSubmittingReceipt.value = false;
    }
    return result;
  }

  Future<void> registerWithholding(
    String invoiceIrn,
    String buyerTin,
    double pretaxAmount, {
    String natureOfSupplies = 'goods',
    double rate = 0.03,
  }) async {
    isSubmittingWithholding.value = true;
    try {
      if (!ConfigPreference.isBranchActive()) {
        isSubmittingWithholding.value = false;
        Get.snackbar(
          'Subscription Required',
          'An active package is required to register withholding receipts. Please select a package to proceed.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.amber.shade900,
          colorText: Colors.white,
          icon: const Icon(Icons.payment_rounded, color: Colors.white),
          duration: const Duration(seconds: 4),
        );
        Get.to(() => PaymentPackagesScreen(
              currentStatus: ConfigPreference.getBranchStatus() ?? 'pending',
            ));
        return;
      }

      final authController = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : Get.put(AuthController());
      final hasMorAuth = await authController.ensureMorAuth();
      if (!hasMorAuth) {
        authController.showMorCredentialsRequiredDialog(action: 'register withholding');
        Get.snackbar(
          'MoR Credentials Required',
          'Please contact support to set up your MoR credentials.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final systemNumber = await AppSettings.getSystemNumber();
      final withholdAmount = double.parse((pretaxAmount * rate).toStringAsFixed(2));
      final String reason = natureOfSupplies.toLowerCase().contains('serv')
          ? 'Withholding tax deduction on service payment.'
          : 'Withholding tax deducted from the payment.';

      final request = WithholdingReceiptRequest(
        receiptNumber: "WHT-${DateTime.now().millisecondsSinceEpoch}",
        reason: reason,
        receiptCounter: "1",
        manualReceiptNumber: (DateTime.now().millisecondsSinceEpoch % 100000)
            .toString(),
        sourceSystemType: "POS",
        sourceSystemNumber: systemNumber,
        buyerTIN: buyerTin,
        invoiceDetail: {"InvoiceIRN": invoiceIrn, "Currency": "ETB"},
        withholdDetail: {
          "Type": "TWHT",
          "NatureOfSupplies": InvoiceController.sanitizeNatureOfSupplies(natureOfSupplies),
          "PreTaxAmount": double.parse(pretaxAmount.toStringAsFixed(2)),
          "WithholdingAmount": withholdAmount,
        },
      );

      await ApiService.registerWithholdingReceipt(
        request,
        onSuccess: (r) {
          Get.snackbar('Success', 'Withholding receipt registered.');
          if (Get.isRegistered<ReceiptFetchController>(tag: invoiceIrn)) {
            Get.find<ReceiptFetchController>(tag: invoiceIrn).fetchReceipts();
          }
        },
        onFailure: (e, r) =>
            Get.snackbar('Error', 'Failed to register withholding.'),
      );
    } catch (e) {
      Get.log("Exception in registerWithholding: $e");
    } finally {
      isSubmittingWithholding.value = false;
    }
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
