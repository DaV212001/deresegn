import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:deresegn/config/dio_config.dart';
import 'package:dio/dio.dart' as dio_lib;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/app_settings.dart';
import '../config/config_preference.dart';
import '../models/invoice_history_model.dart';
import '../models/invoice_models.dart';
import '../models/receipt_models.dart';
import '../screens/invoice_detail_screen.dart';
import '../screens/pdf_preview_screen.dart';
import '../services/api_service.dart';
import '../services/cancelled_invoices_storage.dart';
import '../services/invoice_pdf_service.dart';
import '../services/offline_queue_service.dart';
import '../services/receipt_pdf_service.dart';
import 'auth_controller.dart';
import 'branch_hours_controller.dart';
import 'invoice_history_controller.dart';
import 'receipt_controller.dart';

class TaxCategory {
  final String code;
  final String description;
  final double rate;

  const TaxCategory({
    required this.code,
    required this.description,
    required this.rate,
  });
}

const List<TaxCategory> taxCategories = [
  TaxCategory(code: 'VAT15', description: 'VAT (15%)', rate: 0.15),
  TaxCategory(code: 'VAT0', description: 'Zero Rated (0%)', rate: 0.0),
  TaxCategory(code: 'VATEX', description: 'Exempt (Non-taxable)', rate: 0.0),
  TaxCategory(code: 'TOT2', description: 'TOT (2%)', rate: 0.02),
  TaxCategory(code: 'TOT10', description: 'TOT (10%)', rate: 0.10),
];

class InvoiceItem {
  String description;
  double unitPrice;
  double quantity;
  TaxCategory taxCategory;
  double exciseRate;
  bool isExciseTaxable;
  String itemCode;
  String natureOfSupplies;
  String unit;
  double discount;

  InvoiceItem({
    required this.description,
    required this.unitPrice,
    required this.quantity,
    this.taxCategory = const TaxCategory(
      code: 'VAT15',
      description: 'VAT (15%)',
      rate: 0.15,
    ),
    this.exciseRate = 0.0,
    this.isExciseTaxable = false,
    this.itemCode = '',
    this.natureOfSupplies = 'goods',
    this.unit = 'PCS',
    this.discount = 0.0,
  });

  double get netValue => unitPrice * quantity;
  double get discountAmount => discount;
  double get afterDiscount => netValue - discountAmount;
  double get exciseAmount => isExciseTaxable ? afterDiscount * exciseRate : 0.0;
  double get vatBase => afterDiscount + exciseAmount;
  double get vatAmount => vatBase * taxCategory.rate;
  double get totalLineAmount => vatBase + vatAmount;
}

class InvoiceController extends GetxController {
  static const Set<String> validMorUnits = {
    'LTR',
    'MTR',
    '101',
    'PCS',
    'ROL',
    'MTS',
    'PKG',
    'SET',
    'KLG',
  };

  static String sanitizeNatureOfSupplies(String? nature) {
    if (nature == null || nature.isEmpty) return 'goods';
    final lower = nature.toLowerCase().trim();
    if (lower.contains('serv') || lower == 's') {
      return 'service';
    }
    return 'goods';
  }

  static String sanitizeUnit(String? unit) {
    if (unit == null || unit.isEmpty) return 'PCS';
    final upper = unit.toUpperCase().trim();
    if (validMorUnits.contains(upper)) {
      return upper;
    }
    switch (upper) {
      case 'KG':
      case 'KILOGRAM':
      case 'KILO':
        return 'KLG';
      case 'BOX':
      case 'CARTON':
      case 'PKT':
      case 'PACKET':
      case 'PACK':
      case 'BAG':
      case 'BUNDLE':
        return 'PKG';
      case 'PIECE':
      case 'PIECES':
      case 'UNIT':
      case 'UNITS':
      case 'NOS':
      case 'NO':
        return 'PCS';
      case 'METER':
      case 'METERS':
        return 'MTR';
      case 'LITER':
      case 'LITRE':
      case 'LITERS':
        return 'LTR';
      case 'ROLL':
      case 'ROLLS':
        return 'ROL';
      case 'TON':
      case 'TONS':
      case 'MT':
        return 'MTS';
      default:
        return 'PCS';
    }
  }

  var isSubmitting = false.obs;
  var generatedQrCode = ''.obs;

  // Form State
  var buyerTin = ''.obs;
  var buyerName = ''.obs;
  var buyerPhone = ''.obs;
  var buyerEmail = ''.obs;
  var items = <InvoiceItem>[].obs;
  var paymentMode = 'CASH'.obs;
  var paymentTerm = 'IMMEDIATE'.obs;
  var customPaymentTerm = ''.obs;
  var transactionType = 'B2C'.obs;
  var documentType = 'CASH_SALE'.obs;
  var referenceIrn = ''.obs;
  var selectedReferenceInvoice = Rxn<InvoiceSummary>();
  var adjustmentReason = ''.obs;
  var invoiceCurrency = 'ETB'.obs;
  var exchangeRate = '1.00'.obs;
  var incomeWithholdValue = '0.00'.obs;
  var txnWithholdValue = '0.00'.obs;
  var selectedTaxCategory = taxCategories.first.obs;
  var availableSupplies = <SupplyItem>[].obs;
  var isLoadingSupplies = false.obs;
  var formResetSignal = 0.obs;

  void setReferenceInvoice(InvoiceSummary parentInvoice) {
    selectedReferenceInvoice.value = parentInvoice;
    referenceIrn.value = parentInvoice.irn ?? '';

    // Auto-populate buyer info from parent invoice
    if (parentInvoice.buyer.tin != null && parentInvoice.buyer.tin!.isNotEmpty) {
      buyerTin.value = parentInvoice.buyer.tin!;
    } else {
      buyerTin.value = '';
    }
    if (parentInvoice.buyer.legalName != null && parentInvoice.buyer.legalName!.isNotEmpty) {
      buyerName.value = parentInvoice.buyer.legalName!;
    } else {
      buyerName.value = 'Walk-in Customer';
    }

    final refPayload = parentInvoice.requestPayload;
    final rBuyer = (refPayload?['BuyerDetails'] as Map<String, dynamic>?) ??
        (refPayload?['buyerDetails'] as Map<String, dynamic>?);
    buyerPhone.value = parentInvoice.buyer.phone ?? rBuyer?['Phone']?.toString() ?? '';
    buyerEmail.value = parentInvoice.buyer.email ?? rBuyer?['Email']?.toString() ?? '';

    // Inherit PaymentTerm and Mode from parent invoice (Required for MoR Rule 7030 compliance)
    String? term = refPayload?['PaymentDetails']?['PaymentTerm']?.toString() ??
        refPayload?['paymentDetails']?['paymentTerm']?.toString();
    String? mode = refPayload?['PaymentDetails']?['Mode']?.toString() ??
        refPayload?['paymentDetails']?['mode']?.toString();

    if (term == null || term.isEmpty) {
      term = (parentInvoice.rawDocumentType == 'CREDIT_SALE') ? 'CREDIT' : 'IMMEDIATE';
    }
    if (mode == null || mode.isEmpty) {
      mode = (parentInvoice.rawDocumentType == 'CREDIT_SALE') ? 'CREDIT' : 'CASH';
    }

    paymentTerm.value = term;
    paymentMode.value = mode;

    // Copy parent invoice items
    items.clear();
    final payload = parentInvoice.requestPayload;
    if (payload != null && payload['ItemList'] is List) {
      final parentItems = payload['ItemList'] as List<dynamic>;
      for (final it in parentItems) {
        if (it is Map) {
          final taxCode = it['TaxCode']?.toString() ?? 'VAT15';
          final matchedTax = taxCategories.firstWhere(
            (c) => c.code == taxCode,
            orElse: () => taxCategories.first,
          );
          final qty = double.tryParse(it['Quantity']?.toString() ?? '1') ?? 1.0;
          final price = double.tryParse(it['UnitPrice']?.toString() ?? '0') ?? 0.0;
          final disc = double.tryParse(it['Discount']?.toString() ?? '0') ?? 0.0;
          final extVal = double.tryParse(it['ExciseTaxValue']?.toString() ?? '0') ?? 0.0;

          items.add(
            InvoiceItem(
              description: it['ProductDescription']?.toString() ?? 'Item',
              unitPrice: price,
              quantity: qty,
              taxCategory: matchedTax,
              itemCode: it['ItemCode']?.toString() ?? '',
              natureOfSupplies: it['NatureOfSupplies']?.toString() ?? 'goods',
              unit: it['Unit']?.toString() ?? 'PCS',
              discount: disc,
              isExciseTaxable: extVal > 0,
            ),
          );
        }
      }
    }
  }

  void clearReferenceInvoice() {
    selectedReferenceInvoice.value = null;
    referenceIrn.value = '';
  }

  @override
  void onInit() {
    super.onInit();
    if (!DioConfig.isTestMode) {
      fetchSupplies();
      final authController = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : Get.put(AuthController());
      authController.ensureMorAuth().catchError((e) {
        Logger().w('Background MoR auth in InvoiceController: $e');
        return false;
      });
    }
  }

  Future<void> fetchSupplies() async {
    isLoadingSupplies.value = true;
    await ApiService.fetchSupplies(
      onSuccess: (data) {
        availableSupplies.assignAll(data);
        isLoadingSupplies.value = false;
      },
      onFailure: (error, response) {
        isLoadingSupplies.value = false;
        Logger().e('Failed to fetch supplies: $error');
      },
    );
  }

  Future<void> saveItemToCatalog(InvoiceItem item) async {
    final supplyItem = SupplyItem(
      // description: item.description,
      unitPrice: item.unitPrice,
      // taxCategory: item.taxCategory.code,
      exciseTaxRate: item.exciseRate,
      isExciseTaxable: item.isExciseTaxable,
      itemCode: item.itemCode,
      natureOfSupplies: item.natureOfSupplies,
      unit: item.unit,
      productDescription: item.description,
      taxCode: item.taxCategory.code,
    );

    await ApiService.createSupply(
      supplyItem,
      onSuccess: (response) {
        Get.snackbar('Success', 'Item saved to catalog.');
        fetchSupplies();
      },
      onFailure: (error, response) {
        Logger().e('Failed to save item to catalog: $error');
        Get.snackbar('Error', 'Failed to save item to catalog.');
      },
    );
  }

  Future<void> updateSupply(String id, InvoiceItem item) async {
    final supplyItem = SupplyItem(
      id: id,
      productDescription: item.description,
      unitPrice: item.unitPrice,
      taxCode: item.taxCategory.code,
      exciseTaxRate: item.exciseRate,
      isExciseTaxable: item.isExciseTaxable,
      itemCode: item.itemCode,
      natureOfSupplies: item.natureOfSupplies,
      unit: item.unit,
    );

    await ApiService.updateSupply(
      id,
      supplyItem,
      onSuccess: (response) {
        Get.snackbar('Success', 'Supply updated.');
        fetchSupplies();
      },
      onFailure: (error, response) {
        Logger().e('Failed to update supply: $error');
        Get.snackbar('Error', 'Failed to update supply.');
      },
    );
  }

  Future<void> deleteSupply(String id) async {
    await ApiService.deleteSupply(
      id,
      onSuccess: (response) {
        Get.snackbar('Success', 'Supply deleted.');
        fetchSupplies();
      },
      onFailure: (error, response) {
        Logger().e('Failed to delete supply: $error');
        Get.snackbar('Error', 'Failed to delete supply.');
      },
    );
  }

  double get totalPreTax => items.fold(0, (sum, item) => sum + item.netValue);
  double get totalDiscount =>
      items.fold(0, (sum, item) => sum + item.discountAmount);
  double get totalExcise =>
      items.fold(0, (sum, item) => sum + item.exciseAmount);
  double get totalVat => items.fold(0, (sum, item) => sum + item.vatAmount);
  double get grandTotal =>
      items.fold(0, (sum, item) => sum + item.totalLineAmount);

  void addItem(
    String desc,
    double price,
    double qty,
    TaxCategory tax, {
    double exciseRate = 0.0,
    bool isExciseTaxable = false,
    String itemCode = '',
    String natureOfSupplies = 'goods',
    String unit = 'PCS',
    double discount = 0.0,
  }) {
    items.add(
      InvoiceItem(
        description: desc,
        unitPrice: price,
        quantity: qty,
        taxCategory: tax,
        exciseRate: exciseRate,
        isExciseTaxable: isExciseTaxable,
        itemCode: itemCode,
        natureOfSupplies: natureOfSupplies,
        unit: unit,
        discount: discount,
      ),
    );
  }

  void removeItem(int index) {
    items.removeAt(index);
  }

  void clearForm() {
    buyerTin.value = '';
    buyerName.value = '';
    buyerPhone.value = '';
    buyerEmail.value = '';
    items.clear();
    paymentMode.value = 'CASH';
    paymentTerm.value = 'IMMEDIATE';
    customPaymentTerm.value = '';
    transactionType.value = 'B2C';
    documentType.value = 'CASH_SALE';
    referenceIrn.value = '';
    selectedReferenceInvoice.value = null;
    adjustmentReason.value = '';
    invoiceCurrency.value = 'ETB';
    exchangeRate.value = '1.00';
    incomeWithholdValue.value = '0.00';
    txnWithholdValue.value = '0.00';
    selectedTaxCategory.value = taxCategories.first;
    generatedQrCode.value = '';
    formResetSignal.value++;
  }

  String _formatInvoiceDate(DateTime dt) {
    // MoR validator strictly validates timestamps against its server UTC clock
    // and rejects any timestamps in the future.
    // Convert to UTC with a 1-minute safety offset to prevent client clock skew rejections.
    final utc = dt.toUtc().subtract(const Duration(minutes: 1));
    return DateFormat("dd-MM-yyyy'T'HH:mm:ss").format(utc);
  }

  /// Verifies whether the branch status is active.
  /// TEMPORARY (App Store review): Payment prompt is disabled.
  bool checkActiveSubscriptionOrPromptPayment() {
    if (ConfigPreference.isBranchActive()) {
      return true;
    }

    Logger().i(
      'Invoice registration blocked: branch status is inactive.',
    );
    if (!DioConfig.isTestMode) {
      Get.snackbar(
        'Branch Inactive',
        'Your branch account is currently inactive. Please contact support.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.amber.shade900,
        colorText: Colors.white,
        icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
        duration: const Duration(seconds: 4),
      );
    }

    return false;
  }

  Future<void> registerWithholdingFromForm(BuildContext context) async {
    if (!checkActiveSubscriptionOrPromptPayment()) return;

    if (referenceIrn.value.trim().isEmpty) {
      Get.snackbar(
        'Reference Required',
        'Please enter or select a Reference Invoice IRN for the withholding receipt.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (buyerTin.value.trim().isEmpty) {
      Get.snackbar(
        'TIN Required',
        'Please enter Buyer / Withholding Agent TIN.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isSubmitting.value = true;
    try {
      final authController = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : Get.put(AuthController());
      final hasMorAuth = await authController.ensureMorAuth();
      if (!hasMorAuth) {
        isSubmitting.value = false;
        authController.showMorCredentialsRequiredDialog(action: 'register withholding');
        Get.snackbar(
          'MoR Credentials Required',
          'Please contact support to set up your MoR credentials.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      double pretaxAmount = 0.0;
      if (items.isNotEmpty) {
        pretaxAmount = items.fold<double>(0.0, (sum, it) => sum + it.afterDiscount);
      } else if (selectedReferenceInvoice.value != null) {
        final valDet = selectedReferenceInvoice.value!.requestPayload?['ValueDetails'] as Map<String, dynamic>?;
        final rawPretax = valDet?['TaxableAmount'] ?? selectedReferenceInvoice.value!.totals.totalValue;
        pretaxAmount = double.tryParse(rawPretax?.toString() ?? '0') ?? 0.0;
      }

      if (pretaxAmount <= 0) {
        isSubmitting.value = false;
        Get.snackbar(
          'Amount Required',
          'Please add items or select an invoice to determine the pre-tax withholding base.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final bool hasServices = items.any((i) => i.natureOfSupplies.toLowerCase().contains('serv'));
      final String natureOfSupplies = hasServices ? 'services' : 'goods';
      final systemNumber = await AppSettings.getSystemNumber();
      const double rate = 0.03;
      final withholdAmount = double.parse((pretaxAmount * rate).toStringAsFixed(2));
      final String reason = adjustmentReason.value.trim().isNotEmpty
          ? adjustmentReason.value.trim()
          : (natureOfSupplies == 'services'
              ? 'Withholding tax deduction on service payment.'
              : 'Withholding tax deducted from the payment.');

      final receiptNumber = "WHT-${DateTime.now().millisecondsSinceEpoch}";
      final request = WithholdingReceiptRequest(
        receiptNumber: receiptNumber,
        reason: reason,
        receiptCounter: "1",
        manualReceiptNumber: (DateTime.now().millisecondsSinceEpoch % 100000).toString(),
        sourceSystemType: "POS",
        sourceSystemNumber: systemNumber,
        buyerTIN: buyerTin.value.trim(),
        invoiceDetail: {
          "InvoiceIRN": referenceIrn.value.trim(),
          "Currency": invoiceCurrency.value,
        },
        withholdDetail: {
          "Type": "TWHT",
          "NatureOfSupplies": sanitizeNatureOfSupplies(natureOfSupplies),
          "PreTaxAmount": double.parse(pretaxAmount.toStringAsFixed(2)),
          "WithholdingAmount": withholdAmount,
        },
      );

      await ApiService.registerWithholdingReceipt(
        request,
        onSuccess: (response) async {
          isSubmitting.value = false;
          Get.snackbar(
            'Success',
            'Withholding Receipt registered successfully on MoR.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.withOpacity(0.15),
            colorText: Colors.green,
            duration: const Duration(seconds: 4),
          );

          final parent = selectedReferenceInvoice.value ??
              InvoiceSummary(
                id: 0,
                irn: referenceIrn.value.trim(),
                documentNumber: 'WHT',
                status: 'A',
                buyer: BuyerInfo(
            legalName: buyerName.value,
            tin: buyerTin.value,
            phone: buyerPhone.value.trim().isNotEmpty ? buyerPhone.value.trim() : null,
            email: buyerEmail.value.trim().isNotEmpty ? buyerEmail.value.trim() : null,
          ),
                totals: TotalsInfo(totalValue: pretaxAmount.toStringAsFixed(2), currency: invoiceCurrency.value),
              );

          final receiptSummary = ReceiptSummary(
            id: DateTime.now().millisecondsSinceEpoch,
            morId: 'MOR-WHT-${DateTime.now().millisecondsSinceEpoch % 10000}',
            status: 'A',
            invoiceIrn: referenceIrn.value.trim(),
            receiptNumber: receiptNumber,
            isSuccess: true,
            createdAt: DateTime.now().toIso8601String(),
            requestPayload: {
              'ReceiptNumber': receiptNumber,
              'Reason': reason,
              'NatureOfSupplies': natureOfSupplies,
              'ReceiptCounter': '1',
              'SourceSystemType': 'POS',
              'SourceSystemNumber': systemNumber,
              'BuyerTIN': buyerTin.value.trim(),
              'InvoiceDetail': {
                'InvoiceIRN': referenceIrn.value.trim(),
                'Currency': invoiceCurrency.value,
              },
              'WithholdDetail': {
                'Type': 'TWHT',
                'NatureOfSupplies': natureOfSupplies,
                'PreTaxAmount': pretaxAmount,
                'WithholdingRate': rate,
                'WithholdingAmount': withholdAmount,
              },
            },
          );

          clearForm();

          try {
            final pdfBytes = await ReceiptPdfService.generate(receiptSummary, parent, isWithholding: true);
            Get.to(
              () => PdfPreviewScreen(
                receipt: receiptSummary,
                parentInvoice: parent,
                isWithholding: true,
                pdfBytes: pdfBytes,
                title: 'Withholding Tax Receipt',
                irn: parent.irn,
                documentNumber: parent.documentNumber,
              ),
            );
          } catch (e) {
            Logger().w('Could not open preview for withholding receipt: $e');
            Get.back();
          }
        },
        onFailure: (error, response) {
          isSubmitting.value = false;
          final errorData = error is dio_lib.DioException ? error.response?.data : response.data;
          final msg = (errorData is Map && errorData['message'] != null)
              ? errorData['message'].toString()
              : 'Failed to register Withholding Receipt. Please try again.';
          Get.snackbar(
            'Registration Failed',
            msg,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.withOpacity(0.15),
            colorText: Colors.red,
            duration: const Duration(seconds: 5),
          );
        },
      );
    } catch (e) {
      isSubmitting.value = false;
      Logger().e('Error in registerWithholdingFromForm: $e');
      Get.snackbar('Error', 'An error occurred: $e');
    }
  }

  Future<int> _getNextDocumentNumber() async {
    try {
      final historyController = Get.isRegistered<InvoiceHistoryController>()
          ? Get.find<InvoiceHistoryController>()
          : Get.put(InvoiceHistoryController());

      if (historyController.invoices.isEmpty) {
        await historyController.fetchInvoices(refresh: true);
      }

      if (historyController.invoices.isNotEmpty) {
        int maxDoc = 0;
        for (var inv in historyController.invoices) {
          final docNum = int.tryParse(inv.documentNumber ?? '');
          if (docNum != null && docNum > maxDoc) {
            maxDoc = docNum;
          }
        }
        if (maxDoc > 0) return maxDoc + 1;
      }
    } catch (e) {
      Logger().w('Error determining next document number: $e');
    }
    // Fallback starting from 174 (last verified live doc number was 173)
    return 174;
  }

  Future<void> registerFormInvoice(BuildContext context) async {
    if (!checkActiveSubscriptionOrPromptPayment()) return;

    final hoursController = Get.isRegistered<BranchHoursController>()
        ? Get.find<BranchHoursController>()
        : Get.put(BranchHoursController());
    if (!hoursController.isCurrentlyOpen()) {
      hoursController.showClosedDialog(context);
      return;
    }

    if (documentType.value == 'WITHHOLDING_RECEIPT') {
      await registerWithholdingFromForm(context);
      return;
    }

    if (items.isEmpty || buyerName.value.isEmpty) {
      Get.snackbar(
        'Error',
        'Please fill out buyer details and add at least one item.',
      );
      return;
    }

    isSubmitting.value = true;
    try {
      final authController = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : Get.put(AuthController());
      final hasMorAuth = await authController.ensureMorAuth();
      if (!hasMorAuth) {
        isSubmitting.value = false;
        authController.showMorCredentialsRequiredDialog(action: 'create an invoice');
        Get.snackbar(
          'MoR Credentials Required',
          'Please contact support to set up your MoR credentials.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final int nextDocNumber = await _getNextDocumentNumber();

    final rawTin = await ConfigPreference.getTin();
    final tin = rawTin.isNotEmpty ? rawTin : "0000037187";
    final cashierName = await AppSettings.getCashierName();
    final systemNumber = await AppSettings.getSystemNumber();
    final tradeName = await AppSettings.getTradeName();
    final vatNumber = await AppSettings.getVatNumber();
    final city = await AppSettings.getDefaultCity();

    final itemListMap = items.asMap().entries.map((entry) {
      int idx = entry.key;
      InvoiceItem item = entry.value;
      return {
        "LineNumber": idx + 1,
        "NatureOfSupplies": sanitizeNatureOfSupplies(item.natureOfSupplies),
        "UnitPrice": item.unitPrice.toStringAsFixed(2),
        "TotalLineAmount": item.totalLineAmount.toStringAsFixed(2),
        "PreTaxValue": item.afterDiscount.toStringAsFixed(2),
        "Unit": sanitizeUnit(item.unit),
        "TaxCode": item.taxCategory.code,
        "TaxAmount": item.vatAmount.toStringAsFixed(2),
        "Quantity": item.quantity.toStringAsFixed(2),
        "Discount": item.discountAmount.toStringAsFixed(2),
        "ExciseTaxValue": item.exciseAmount.toStringAsFixed(2),
        "ProductDescription": item.description,
        "ItemCode": item.itemCode.isNotEmpty
            ? item.itemCode
            : "ITEM-${idx + 1}",
      };
    }).toList();

    String docType = "INV";
    String payTerm = paymentTerm.value.trim();
    String mode = paymentMode.value.trim();

    if (documentType.value == 'CREDIT_SALE') {
      if (mode.toUpperCase() == 'CASH') mode = 'CREDIT';
      if (payTerm.toUpperCase() == 'IMMEDIATE' || payTerm.toUpperCase() == 'CASH' || payTerm.isEmpty) {
        payTerm = 'CREDIT';
      }
    } else if (documentType.value == 'CREDIT_NOTE' || documentType.value == 'DEBIT_NOTE') {
      docType = documentType.value == 'CREDIT_NOTE' ? "CRE" : "DEB";
      // MoR Rule 7030: PaymentTerm and Mode must match the referenced invoice exactly
      if (selectedReferenceInvoice.value != null) {
        final refPayload = selectedReferenceInvoice.value!.requestPayload;
        final refTerm = refPayload?['PaymentDetails']?['PaymentTerm']?.toString() ??
            refPayload?['paymentDetails']?['paymentTerm']?.toString();
        final refMode = refPayload?['PaymentDetails']?['Mode']?.toString() ??
            refPayload?['paymentDetails']?['mode']?.toString();
        if (refTerm != null && refTerm.trim().isNotEmpty) payTerm = refTerm.trim();
        if (refMode != null && refMode.trim().isNotEmpty) mode = refMode.trim();
      }
    }

    if (payTerm.isEmpty) {
      payTerm = (mode.toUpperCase() == 'CREDIT') ? 'CREDIT' : 'IMMEDIATE';
    }
    if (mode.isEmpty) {
      mode = (payTerm.toUpperCase() == 'CREDIT') ? 'CREDIT' : 'CASH';
    }

    if (payTerm.toLowerCase() == 'custom' && customPaymentTerm.value.trim().isNotEmpty) {
      payTerm = customPaymentTerm.value.trim();
    }

    // Standardize Mode to MoR Rule 7022 specification ("CASH", "ADVANCE", "CREDIT")
    String formattedMode;
    switch (mode.toUpperCase()) {
      case 'CREDIT':
        formattedMode = 'CREDIT';
        break;
      case 'ADVANCE':
        formattedMode = 'ADVANCE';
        break;
      case 'DIRECT_TRANSFER':
      case 'DIRECT TRANSFER':
      case 'BANK_TRANSFER':
      case 'CASH':
      default:
        formattedMode = 'CASH';
        break;
    }

    final String docReason = (docType == "CRE" || docType == "DEB")
        ? (adjustmentReason.value.trim().isNotEmpty
              ? adjustmentReason.value.trim()
              : "Adjustment Note")
        : "Sales Invoice";

    final Map<String, dynamic> valDetails = {
      "TotalValue": grandTotal.toStringAsFixed(2),
      "TaxValue": totalVat.toStringAsFixed(2),
      "Discount": totalDiscount.toStringAsFixed(2),
      "ExciseValue": totalExcise.toStringAsFixed(2),
      "InvoiceCurrency": invoiceCurrency.value,
      "IncomeWithholdValue": incomeWithholdValue.value,
      "TransactionWithholdValue": txnWithholdValue.value,
    };
    if (invoiceCurrency.value != "ETB") {
      valDetails["ExchangeRate"] = exchangeRate.value;
    }

    final request = InvoiceRegisterRequest(
      documentDetails: {
        "DocumentNumber": nextDocNumber.toString(),
        "Type": docType,
        "Reason": docReason,
        "Date": _formatInvoiceDate(DateTime.now()),
      },
      transactionType: transactionType.value,
      sourceSystem: {
        "SystemType": "POS",
        "CashierName": cashierName,
        "SystemNumber": systemNumber,
        "InvoiceCounter": nextDocNumber,
        "SalesPersonName": cashierName,
      },
      sellerDetails: {
        "Tin": tin,
        "LegalName": 'Micro Sun & Solution PLC',
        "City": city,
        "Wereda": "13",
        "Region": "1",
        "Email": "amanuielt@mssmea.com",
        "Phone": "+251947990585",
        "Country": "1",
        "TradeName": tradeName,
        "VatNumber": vatNumber,
      },
      buyerDetails: {
        "LegalName": buyerName.value,
        "IdType": "KID",
        "HouseNumber": "",
        "IdNumber": "",
        "Tin": buyerTin.value,
        "Email": buyerEmail.value.trim(),
        "Phone": buyerPhone.value.trim(),
        "City": city,
        "Region": "",
        "Country": "",
        "Kebele": "",
        "Wereda": "",
        "VatNumber": buyerTin.value.isEmpty ? null : "",
      },
      itemList: itemListMap,
      valueDetails: valDetails,
      paymentDetails: {"PaymentTerm": payTerm, "Mode": formattedMode},
      referenceDetails: {
        "RelatedDocument":
            (documentType.value == 'CREDIT_NOTE' ||
                documentType.value == 'DEBIT_NOTE')
            ? referenceIrn.value
            : null,
        "PreviousIrn":
            (documentType.value == 'CREDIT_NOTE' ||
                documentType.value == 'DEBIT_NOTE')
            ? referenceIrn.value
            : "null",
      }, // TODO: revert to null once backend schema is fixed
      version: "1",
    );

    await _sendInvoiceRequest(context, request);
    } catch (e) {
      isSubmitting.value = false;
      Logger().e('Error in registerFormInvoice: $e');
    }
  }

  Future<void> registerSampleInvoice(BuildContext context) async {
    if (!checkActiveSubscriptionOrPromptPayment()) return;

    final hoursController = Get.isRegistered<BranchHoursController>()
        ? Get.find<BranchHoursController>()
        : Get.put(BranchHoursController());
    if (!hoursController.isCurrentlyOpen()) {
      hoursController.showClosedDialog(context);
      return;
    }

    isSubmitting.value = true;
    try {
      final authController = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : Get.put(AuthController());
      final hasMorAuth = await authController.ensureMorAuth();
      if (!hasMorAuth) {
        isSubmitting.value = false;
        authController.showMorCredentialsRequiredDialog(action: 'create an invoice');
        Get.snackbar(
          'MoR Credentials Required',
          'Please contact support to set up your MoR credentials.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final int nextDocNumber = await _getNextDocumentNumber();
    final tin = await ConfigPreference.getTin();
    final cashierName = await AppSettings.getCashierName();
    final systemNumber = await AppSettings.getSystemNumber();
    final tradeName = await AppSettings.getTradeName();
    final vatNumber = await AppSettings.getVatNumber();
    final city = await AppSettings.getDefaultCity();

    final request = InvoiceRegisterRequest(
      documentDetails: {
        "DocumentNumber": nextDocNumber.toString(),
        "Type": "INV",
        "Reason": "Reason:-",
        "Date": _formatInvoiceDate(DateTime.now()),
      },
      transactionType: "B2B",
      sourceSystem: {
        "SystemType": "POS",
        "CashierName": cashierName,
        "SystemNumber": systemNumber,
        "InvoiceCounter": nextDocNumber,
        "SalesPersonName": cashierName,
      },
      sellerDetails: {
        "Tin": tin,
        "LegalName": 'Micro Sun & Solution PLC',
        "City": city,
        "Wereda": "13",
        "Region": "1",
        "Email": "amanuielt@mssmea.com",
        "Phone": "+251947990585",
        "Country": "1",
        "TradeName": tradeName,
        "VatNumber": vatNumber,
      },
      buyerDetails: {
        "LegalName": "Amanuel Teferi",
        "IdType": "KID",
        "HouseNumber": "",
        "IdNumber": "",
        "Tin": "0000037187",
        "Email": "",
        "Phone": "",
        "City": city,
        "Region": "",
        "Country": "",
        "Kebele": "",
        "Wereda": "",
        "VatNumber": "",
      },
      itemList: [
        {
          "LineNumber": 1,
          "NatureOfSupplies": "goods",
          "UnitPrice": "10.00",
          "TotalLineAmount": "11.50",
          "PreTaxValue": "10.00",
          "Unit": "PCS",
          "TaxCode": "VAT15",
          "TaxAmount": "1.50",
          "Quantity": "1.00",
          "Discount": "0.00",
          "ExciseTaxValue": "0.00",
          "ProductDescription": "Sample Item",
          "ItemCode": "ITEM-1",
        },
      ],
      valueDetails: {
        "TotalValue": "11.50",
        "TaxValue": "1.50",
        "Discount": "0.00",
        "ExciseValue": "0.00",
        "InvoiceCurrency": "ETB",
      },
      paymentDetails: {"PaymentTerm": "CASH", "Mode": "CASH"},
      referenceDetails: {
        "RelatedDocument": null,
        "PreviousIrn": "null",
      }, // TODO: revert to null once backend schema is fixed
      version: "1",
    );

    await _sendInvoiceRequest(context, request);
    } catch (e) {
      isSubmitting.value = false;
      Logger().e('Error in registerSampleInvoice: $e');
    }
  }

  String? _extractExpectedValue(dynamic responseData) {
    if (responseData == null) return null;
    final str = responseData is String ? responseData : jsonEncode(responseData);
    final match = RegExp(r'expected\s*(?:value)?\s*:\s*(\d+)', caseSensitive: false).firstMatch(str);
    return match?.group(1);
  }

  Future<void> _sendInvoiceRequest(
    BuildContext context,
    InvoiceRegisterRequest request, {
    int retryCount = 0,
  }) async {
    await ApiService.registerInvoice(
      request,
      onSuccess: (response) async {
        final data = response.data;
        String? irn;
        String? signedQr;
        if (data != null) {
          if (data['body'] != null && data['body'] is Map) {
            irn = data['body']['irn']?.toString();
            signedQr = data['body']['signed_qr']?.toString();
          }
          if (irn == null && data['irn'] != null) {
            irn = data['irn']?.toString();
          }
          if (signedQr == null && data['signed_qr'] != null) {
            signedQr = data['signed_qr']?.toString();
          }
          if (irn == null && data['data'] != null && data['data'] is Map) {
            irn = data['data']['irn']?.toString();
            signedQr = data['data']['signed_qr']?.toString();
          }
        }
        final String finalIrn = irn ?? "mock_irn_fallback_${DateTime.now().millisecondsSinceEpoch}";

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
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Invoice Registered',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Get.theme.colorScheme.primary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Generating receipt & PDF...',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          barrierDismissible: false,
        );
        // Loader is deliberately kept active until receipt completes

        // Fetch the invoice from history to ensure we have full details for the prompt
        InvoiceSummary? registeredInvoice;
        try {
          final historyController = Get.put(InvoiceHistoryController());
          await historyController.fetchInvoices(refresh: true);
          registeredInvoice = historyController.invoices.firstWhereOrNull(
            (inv) => inv.irn == finalIrn,
          );
        } catch (e) {
          Logger().e('Error fetching registered invoice: $e');
        }

        // If not found in history yet, construct a minimal summary from local state
        registeredInvoice ??= InvoiceSummary(
          id: 0,
          irn: finalIrn,
          documentNumber: request.documentDetails['DocumentNumber'],
          status: 'A',
          signedQr: signedQr,
          buyer: BuyerInfo(
            legalName: buyerName.value,
            tin: buyerTin.value,
            phone: buyerPhone.value.trim().isNotEmpty ? buyerPhone.value.trim() : null,
            email: buyerEmail.value.trim().isNotEmpty ? buyerEmail.value.trim() : null,
          ),
          totals: TotalsInfo(
            totalValue: grandTotal.toStringAsFixed(2),
            taxValue: totalVat.toStringAsFixed(2),
            currency: 'ETB',
          ),
          createdAt: DateTime.now().toIso8601String(),
          requestPayload: request.toJson(),
        );

        clearForm();

        // Automatically register receipt and show combined PDF preview
        _autoRegisterReceiptAndPreview(registeredInvoice, context);
      },
      onFailure: (error, response) async {
        final dynamic errorData = (error is dio_lib.DioException)
            ? error.response?.data
            : response.data;
        final int? statusCode = (error is dio_lib.DioException)
            ? error.response?.statusCode
            : (error is int ? error : response.statusCode);

        if (error is dio_lib.DioException) {
          final isNetworkError =
              error.type == dio_lib.DioExceptionType.connectionTimeout ||
              error.type == dio_lib.DioExceptionType.sendTimeout ||
              error.type == dio_lib.DioExceptionType.receiveTimeout ||
              error.type == dio_lib.DioExceptionType.connectionError ||
              (error.type == dio_lib.DioExceptionType.unknown &&
                  error.error is SocketException);
          if (isNetworkError) {
            final queueService = Get.find<OfflineQueueService>();
            await queueService.addInvoiceToQueue(
              request,
              buyerName.value,
              grandTotal.toStringAsFixed(2),
            );

            if (Get.isDialogOpen ?? false) {
              Get.back();
            }

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
                      Icon(Icons.cloud_off, size: 48, color: Colors.orange),
                      const SizedBox(height: 16),
                      Text(
                        'No Connection',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The invoice has been saved offline and will be registered automatically when connection is restored.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Get.back(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ),
              barrierDismissible: false,
            );

            clearForm();
            isSubmitting.value = false;
            return;
          }
        }

        if (retryCount < 2 && statusCode == 406) {
          final expectedValue = _extractExpectedValue(errorData);
          if (expectedValue != null) {
            Logger().i(
              "Auto-retrying invoice registration with expected value: $expectedValue",
            );
            request.documentDetails['DocumentNumber'] = expectedValue;
            request.sourceSystem['InvoiceCounter'] =
                int.tryParse(expectedValue) ?? expectedValue;
            // Short backoff delay before retry to prevent triggering rate-limiters (HTTP 429)
            await Future.delayed(const Duration(milliseconds: 1200));
            _sendInvoiceRequest(context, request, retryCount: retryCount + 1);
            return;
          }
        }

        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        _handleError(error, response);
        Logger().e('Invoice Registration failed: $error');
        isSubmitting.value = false;
      },
    );
  }

  Future<void> _autoRegisterReceiptAndPreview(
    InvoiceSummary invoice,
    BuildContext context,
  ) async {
    try {
      final docType = invoice.requestPayload?['DocumentDetails']?['Type']?.toString().toUpperCase() ?? 'INV';
      final payTerm = invoice.requestPayload?['PaymentDetails']?['PaymentTerm']?.toString().toUpperCase() ?? 'IMMEDIATE';
      final payMode = invoice.requestPayload?['PaymentDetails']?['Mode']?.toString().toUpperCase() ?? 'CASH';
      final isCredit = payTerm == 'CREDIT' || payMode == 'CREDIT' || payTerm.contains('NET') || payTerm.contains('DAY');

      // Auto-register Sales Receipt (CRB) only for Cash Sales
      final isCashSale = docType == 'INV' && !isCredit;

      ReceiptSummary? receipt;
      if (isCashSale && invoice.irn != null && invoice.totals.totalValue != null) {
        final receiptController = Get.put(ReceiptController());
        receipt = await receiptController.registerSalesReceipt(
          invoice.irn!,
          invoice.totals.totalValue!,
          invoice.documentNumber ?? '',
          invoice.totals.totalValue!,
          showSnackbar: false,
        );
      }

      final invoiceBytes = await InvoicePdfService.generate(invoice);

      Uint8List previewBytes;
      String screenTitle;

      if (receipt != null) {
        previewBytes = await _generateCombinedPdf(invoice, receipt);
        screenTitle = 'Invoice & Receipt #${invoice.documentNumber}';
      } else {
        previewBytes = invoiceBytes;
        if (docType == 'CRE') {
          screenTitle = 'Tax Credit Note #${invoice.documentNumber}';
        } else if (docType == 'DEB') {
          screenTitle = 'Tax Debit Note #${invoice.documentNumber}';
        } else if (isCredit) {
          screenTitle = 'Credit Sales Invoice #${invoice.documentNumber}';
        } else {
          screenTitle = 'Sales Invoice #${invoice.documentNumber}';
        }
      }

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.to(
        () => PdfPreviewScreen(
          invoice: invoice,
          receipt: receipt,
          pdfBytes: previewBytes,
          title: screenTitle,
          irn: invoice.irn,
          documentNumber: invoice.documentNumber,
        ),
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      Logger().e('Error in auto receipt/preview: $e');
      // Fallback to showing the dialog if something fails
      _showPostRegistrationDialog(invoice, context);
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<Uint8List> _generateCombinedPdf(
    InvoiceSummary invoice,
    ReceiptSummary receipt,
  ) async {
    pw.Font? ethiopicRegular;
    try {
      final regData = await rootBundle.load(
        'assets/fonts/NotoSansEthiopic-Regular.ttf',
      );
      ethiopicRegular = pw.Font.ttf(regData);
    } catch (e) {
      debugPrint('Ethiopic font load error: $e');
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        fontFallback: [if (ethiopicRegular != null) ethiopicRegular],
      ),
    );

    // Add Invoice Pages
    await InvoicePdfService.generateIntoDocument(pdf, invoice);

    // Add Receipt Pages
    await ReceiptPdfService.generateIntoDocument(pdf, receipt, invoice);

    return pdf.save();
  }

  void _showPostRegistrationDialog(
    InvoiceSummary invoice,
    BuildContext context,
  ) {
    Get.dialog(
      barrierDismissible: false,
      Dialog(
        backgroundColor: Get.theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Invoice Registered',
                style: TextStyle(
                  color: Get.theme.colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Invoice #${invoice.documentNumber} for ${invoice.buyer.legalName} has been successfully registered.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Get.theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  Get.to(() => InvoiceDetailScreen(invoice: invoice));
                },
                child: const Text(
                  'Register Sales Receipt',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Get.back();
                  Get.to(() => InvoiceDetailScreen(invoice: invoice));
                },
                child: Text(
                  'View Details',
                  style: TextStyle(
                    color: Get.theme.colorScheme.onSurface.withOpacity(0.5),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleError(dynamic error, dynamic response) {
    Logger().d("Error: $error");
    Logger().d("Response: $response");
    String errorMsg = "An error occurred while processing your request";

    if (error is dio_lib.DioException) {
      errorMsg = DioConfig.convertDioError(error);
      if (error.response?.data != null) {
        final backendMsg = _parseMessage(error.response!.data);
        if (backendMsg != null) errorMsg = backendMsg;
      }
    } else if (response != null && response.data != null) {
      final backendMsg = _parseMessage(response.data);
      if (backendMsg != null) errorMsg = backendMsg;
    }

    // Log the final error message being shown to the user
    final int? statusCode = (error is dio_lib.DioException)
        ? error.response?.statusCode
        : (error is int ? error : response?.statusCode);
    final hasRuleCode = RegExp(r'^\d{4}:').hasMatch(errorMsg.trim());
    final isMorAuthError = !hasRuleCode &&
        (statusCode == 401 ||
            statusCode == 4503 ||
            errorMsg.toLowerCase().contains('invalid credential') ||
            errorMsg.toLowerCase().contains('unauthenticated') ||
            errorMsg.toLowerCase().contains('unauthorized') ||
            (errorMsg.toLowerCase().contains('credential') &&
                !errorMsg.toLowerCase().contains('rule')));

    if (isMorAuthError) {
      errorMsg = 'Please contact support to set up your MoR credentials.';
    }

    Logger().e('Final Error Message: $errorMsg');

    Get.snackbar(
      isMorAuthError ? 'MoR Credentials Required' : 'Error',
      errorMsg,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 5),
      backgroundColor: Get.theme.colorScheme.error.withOpacity(0.1),
      colorText: Get.theme.colorScheme.onError,
    );
  }

  String? parseMessage(dynamic data) {
    return _parseMessage(data);
  }

  String? _parseMessage(dynamic data) {
    if (data == null) return null;
    return DioConfig.extractErrorMessage(data) ?? data.toString();
  }
}

class CancelInvoiceController extends GetxController {
  var isSubmitting = false.obs;

  Future<bool> cancelInvoice(String irn, String reasonCode) async {
    isSubmitting.value = true;
    bool success = false;
    try {
      final authController = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : Get.put(AuthController());
      final hasMorAuth = await authController.ensureMorAuth();
      if (!hasMorAuth) {
        authController.showMorCredentialsRequiredDialog(action: 'cancel an invoice');
        Get.snackbar(
          'MoR Credentials Required',
          'Please contact support to set up your MoR credentials.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      final req = InvoiceCancelRequest(irn: irn, reasonCode: reasonCode);
      await ApiService.cancelInvoice(
        req,
        onSuccess: (r) async {
          await CancelledInvoicesStorage.markCancelled(irn, reasonCode: reasonCode);
          success = true;
          Get.snackbar('Success', 'Invoice cancelled.');
          if (Get.isRegistered<InvoiceHistoryController>()) {
            final hist = Get.find<InvoiceHistoryController>();
            hist.markInvoiceCancelledLocally(irn, reasonCode: reasonCode);
            hist.fetchInvoices(refresh: true);
          }
        },
        onFailure: (e, r) async {
          dynamic respData = r.data;
          if (respData == null && e is dio_lib.DioException) {
            respData = e.response?.data;
          }
          final errStr = '${e.toString()} ${respData?.toString() ?? ''}'.toLowerCase();
          if (errStr.contains('already cancel') ||
              errStr.contains('is cancelled') ||
              errStr.contains('is canceled')) {
            await CancelledInvoicesStorage.markCancelled(irn, reasonCode: reasonCode);
            success = true;
            Get.snackbar(
              'Already Cancelled',
              'This invoice has already been cancelled in the system.',
              snackPosition: SnackPosition.BOTTOM,
            );
            if (Get.isRegistered<InvoiceHistoryController>()) {
              final hist = Get.find<InvoiceHistoryController>();
              hist.markInvoiceCancelledLocally(irn, reasonCode: reasonCode);
              hist.fetchInvoices(refresh: true);
            }
            return;
          }
          Get.snackbar('Error', 'Failed to cancel invoice.');
        },
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to cancel invoice: $e');
    } finally {
      isSubmitting.value = false;
    }
    return success;
  }
}
