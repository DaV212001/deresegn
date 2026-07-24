import 'dart:convert';
import 'dart:typed_data';

import 'package:deresegn/config/dio_config.dart';
import 'package:dio/dio.dart' as dio_lib;
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart' show debugPrint;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../config/app_settings.dart';
import '../config/config_preference.dart';
import '../models/invoice_history_model.dart';
import '../models/invoice_models.dart';
import '../models/receipt_models.dart';
import '../screens/invoice_detail_screen.dart';
import '../screens/pdf_preview_screen.dart';
import '../services/api_service.dart';
import '../services/invoice_pdf_service.dart';
import '../services/receipt_pdf_service.dart';
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
  TaxCategory(code: 'TOT2', description: 'TOT (2%)', rate: 0.02),
  TaxCategory(code: 'TOT10', description: 'TOT (10%)', rate: 0.10),
  TaxCategory(code: 'EXMT', description: 'Exempt', rate: 0.0),
  TaxCategory(code: 'ZERO', description: 'Zero Rated', rate: 0.0),
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
  var isSubmitting = false.obs;
  var generatedQrCode = ''.obs;

  // Form State
  var buyerTin = ''.obs;
  var buyerName = ''.obs;
  var items = <InvoiceItem>[].obs;
  var paymentMode = 'CASH'.obs;
  var transactionType = 'B2C'.obs;
  var documentType = 'CASH_SALE'.obs;
  var referenceIrn = ''.obs;
  var adjustmentReason = ''.obs;
  var invoiceCurrency = 'ETB'.obs;
  var exchangeRate = '1.00'.obs;
  var incomeWithholdValue = '0.00'.obs;
  var txnWithholdValue = '0.00'.obs;
  var selectedTaxCategory = taxCategories.first.obs;
  var availableSupplies = <SupplyItem>[].obs;
  var isLoadingSupplies = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchSupplies();
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
    items.clear();
    paymentMode.value = 'CASH';
    transactionType.value = 'B2C';
    documentType.value = 'CASH_SALE';
    referenceIrn.value = '';
    adjustmentReason.value = '';
    invoiceCurrency.value = 'ETB';
    exchangeRate.value = '1.00';
    incomeWithholdValue.value = '0.00';
    txnWithholdValue.value = '0.00';
    selectedTaxCategory.value = taxCategories.first;
    generatedQrCode.value = '';
  }

  String _formatInvoiceDate(DateTime dt) {
    return DateFormat("dd-MM-yyyy'T'HH:mm:ss").format(dt);
  }

  Future<int> _getNextDocumentNumber() async {
    try {
      InvoiceHistoryController historyController;
      if (Get.isRegistered<InvoiceHistoryController>()) {
        historyController = Get.find<InvoiceHistoryController>();
      } else {
        historyController = Get.put(InvoiceHistoryController());
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
    // Fallback to timestamp-based number if history is unavailable
    return DateTime.now().millisecondsSinceEpoch % 100000;
  }

  Future<void> registerFormInvoice() async {
    if (items.isEmpty || buyerName.value.isEmpty) {
      Get.snackbar(
        'Error',
        'Please fill out buyer details and add at least one item.',
      );
      return;
    }

    isSubmitting.value = true;
    final int nextDocNumber = await _getNextDocumentNumber();

    final tin = await ConfigPreference.getTin() ?? '0000037187';
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
        "NatureOfSupplies": item.natureOfSupplies,
        "UnitPrice": item.unitPrice.toStringAsFixed(2),
        "TotalLineAmount": item.totalLineAmount.toStringAsFixed(2),
        "PreTaxValue": item.afterDiscount.toStringAsFixed(2),
        "Unit": item.unit,
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
    String payTerm = paymentMode.value;
    if (documentType.value == 'CREDIT_SALE') {
      payTerm = "CREDIT";
    } else if (documentType.value == 'CREDIT_NOTE') {
      docType = "CRE";
      payTerm = "CREDIT";
    } else if (documentType.value == 'DEBIT_NOTE') {
      docType = "DEB";
      payTerm = "CREDIT";
    }

    final String docReason =
        (docType == "CRE" || docType == "DEB")
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
        "Email": "",
        "Phone": "",
        "City": city,
        "Region": "",
        "Country": "",
        "Kebele": "",
        "Wereda": "",
        "VatNumber": buyerTin.value.isEmpty ? null : "",
      },
      itemList: itemListMap,
      valueDetails: valDetails,
      paymentDetails: {"PaymentTerm": payTerm, "Mode": paymentMode.value},
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

    await _sendInvoiceRequest(request);
  }

  Future<void> registerSampleInvoice() async {
    isSubmitting.value = true;
    final int nextDocNumber = await _getNextDocumentNumber();
    final tin = await ConfigPreference.getTin() ?? '0000037187';
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

    await _sendInvoiceRequest(request);
  }

  String? _extractExpectedValue(dynamic responseData) {
    if (responseData is Map) {
      final msg = responseData['message'] ?? responseData['errorMessage'];
      if (msg != null && msg is String && msg.contains('expected value:')) {
        final match = RegExp(r'expected value: ([\d]+)').firstMatch(msg);
        return match?.group(1);
      }
    }
    return null;
  }

  Future<void> _sendInvoiceRequest(
    InvoiceRegisterRequest request, {
    int retryCount = 0,
  }) async {
    await ApiService.registerInvoice(
      request,
      onSuccess: (response) async {
        final data = response.data;
        final String irn =
            (data != null &&
                data['body'] != null &&
                data['body']['irn'] != null)
            ? data['body']['irn']
            : "mock_irn_fallback_${DateTime.now().millisecondsSinceEpoch}";

        Get.dialog(
          Dialog(
            backgroundColor: Get.theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Invoice Registered', style: TextStyle(fontWeight: FontWeight.bold, color: Get.theme.colorScheme.primary, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Generating receipt & PDF...', textAlign: TextAlign.center),
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
            (inv) => inv.irn == irn,
          );
        } catch (e) {
          Logger().e('Error fetching registered invoice: $e');
        }

        // If not found in history yet, construct a minimal summary from local state
        if (registeredInvoice == null) {
          registeredInvoice = InvoiceSummary(
            id: 0,
            irn: irn,
            documentNumber: request.documentDetails['DocumentNumber'],
            status: 'A',
            buyer: BuyerInfo(legalName: buyerName.value, tin: buyerTin.value),
            totals: TotalsInfo(
              totalValue: grandTotal.toStringAsFixed(2),
              taxValue: totalVat.toStringAsFixed(2),
              currency: 'ETB',
            ),
            createdAt: DateTime.now().toIso8601String(),
            requestPayload: request.toJson(),
          );
        }

        clearForm();

        // Automatically register receipt and show combined PDF preview
        _autoRegisterReceiptAndPreview(registeredInvoice);
      },
      onFailure: (error, response) {
        final dynamic errorData = (error is dio_lib.DioException)
            ? error.response?.data
            : response.data;
        final int? statusCode = (error is dio_lib.DioException)
            ? error.response?.statusCode
            : (error is int ? error : response.statusCode);

        if (retryCount < 1 && statusCode == 406) {
          final expectedValue = _extractExpectedValue(errorData);
          if (expectedValue != null) {
            Logger().i(
              "Auto-retrying invoice registration with expected value: $expectedValue",
            );
            request.documentDetails['DocumentNumber'] = expectedValue;
            request.sourceSystem['InvoiceCounter'] =
                int.tryParse(expectedValue) ?? expectedValue;
            _sendInvoiceRequest(request, retryCount: retryCount + 1);
            return;
          }
        }

        _handleError(error, response);
        Logger().e('Invoice Registration failed: $error');
        isSubmitting.value = false;
      },
    );
  }

  Future<void> _autoRegisterReceiptAndPreview(InvoiceSummary invoice) async {
    try {
      final receiptController = Get.put(ReceiptController());
      final receipt = await receiptController.registerSalesReceipt(
        invoice.irn!,
        invoice.totals.totalValue!,
        invoice.documentNumber!,
        invoice.totals.totalValue!,
        showSnackbar: false,
      );

      final invoiceBytes = await InvoicePdfService.generate(invoice);

      // If receipt is registered, we can try to show both.
      // Since merging PDF bytes is non-trivial without extra dependencies,
      // we'll generate one PDF that contains both if possible,
      // or just show the invoice if receipt fails.

      Uint8List combinedBytes;
      if (receipt != null) {
        // We'll create a new document and add pages from both if we had a PDF merger.
        // Instead, let's create a combined PDF by calling a specialized method or just appending.
        // For simplicity, I'll generate the invoice PDF and if receipt exists,
        // I would ideally append.
        // Let's see if we can just use pw.Document to create a multi-page PDF.

        final receiptBytes = await ReceiptPdfService.generate(receipt, invoice);

        // As a compromise, let's use a screen that can show multiple PDFs or
        // just show the invoice and inform about the receipt.
        // BUT the user asked for "a PDF preview screen that shows both".
        // Let's try to merge them using the pdf package's widgets.

        combinedBytes = await _generateCombinedPdf(invoice, receipt);
      } else {
        combinedBytes = invoiceBytes;
      }

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.to(
        () => PdfPreviewScreen(
          pdfBytes: combinedBytes,
          title: 'Invoice & Receipt #${invoice.documentNumber}',
        ),
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      Logger().e('Error in auto receipt/preview: $e');
      // Fallback to showing the dialog if something fails
      _showPostRegistrationDialog(invoice);
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
      final regData = await rootBundle.load('assets/fonts/NotoSansEthiopic-Regular.ttf');
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

  void _showPostRegistrationDialog(InvoiceSummary invoice) {
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
                  color: const Color(0xFF00FFB3).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF00FFB3),
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Invoice Registered',
                style: TextStyle(
                  color: Get.theme.colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFB3),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Register Sales Receipt',
                  style: TextStyle(fontWeight: FontWeight.w900),
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
    Logger().e('Final Error Message: $errorMsg');

    Get.snackbar(
      'Error',
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

    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return data;
      }
    }

    if (data is Map) {
      final List<String> extractedErrors = [];

      void findErrors(dynamic obj) {
        if (obj is Map) {
          // Look for common error fields
          final msg = obj['message'] ?? obj['errorMessage'] ?? obj['error'];
          if (msg != null && msg is String && msg != "SCHEMA ERROR") {
            extractedErrors.add(msg);
          }
          // Recurse into body or other nested structures
          obj.forEach((key, value) {
            if (value is Map || value is List) {
              findErrors(value);
            }
          });
        } else if (obj is List) {
          for (var item in obj) {
            findErrors(item);
          }
        }
      }

      findErrors(data);

      if (extractedErrors.isNotEmpty) {
        // Return unique errors joined by newlines
        return extractedErrors.toSet().join('\n');
      }

      // Fallback to the top-level message if nothing else was found
      final dynamic topMessage = data['message'] ?? data['messages'];
      if (topMessage != null) {
        if (topMessage is List) return topMessage.join('\n');
        return topMessage.toString();
      }
    }

    return data.toString();
  }
}

class CancelInvoiceController extends GetxController {
  var isSubmitting = false.obs;

  Future<void> cancelInvoice(String irn, String reasonCode) async {
    isSubmitting.value = true;
    final req = InvoiceCancelRequest(irn: irn, reasonCode: reasonCode);
    await ApiService.cancelInvoice(
      req,
      onSuccess: (r) => Get.snackbar('Success', 'Invoice cancelled.'),
      onFailure: (e, r) => Get.snackbar('Error', 'Failed to cancel invoice.'),
    );
    isSubmitting.value = false;
  }
}
