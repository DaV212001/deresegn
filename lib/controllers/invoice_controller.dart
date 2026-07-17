import 'dart:convert';

import 'package:deresegn/config/dio_config.dart';
import 'package:dio/dio.dart' as dio_lib;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../config/app_settings.dart';
import '../config/config_preference.dart';
import '../models/invoice_history_model.dart';
import '../models/invoice_models.dart';
import '../screens/invoice_detail_screen.dart';
import '../services/api_service.dart';
import 'invoice_history_controller.dart';

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
      onSuccess: (supplies) {
        availableSupplies.assignAll(supplies);
        isLoadingSupplies.value = false;
      },
      onFailure: (error, response) {
        isLoadingSupplies.value = false;
        Logger().e('Failed to fetch supplies: $error');
      },
    );
  }

  Future<void> saveItemToCatalog(InvoiceItem item) async {
    final supply = SupplyItem(
      itemCode: item.itemCode.isNotEmpty
          ? item.itemCode
          : "ITEM-${DateTime.now().millisecondsSinceEpoch}",
      productDescription: item.description,
      natureOfSupplies: item.natureOfSupplies,
      unitPrice: item.unitPrice,
      unit: item.unit,
      taxCode: item.taxCategory.code,
      discount: 0,
      exciseTaxRate: item.exciseRate * 100, // Assuming API expects percentage
      isExciseTaxable: item.isExciseTaxable,
    );

    await ApiService.createSupply(
      supply,
      onSuccess: (response) {
        Get.snackbar('Success', 'Item saved to catalog');
        fetchSupplies();
      },
      onFailure: (error, response) {
        Get.snackbar('Error', 'Failed to save item to catalog');
      },
    );
  }

  Future<void> updateSupply(String id, InvoiceItem item) async {
    final supply = SupplyItem(
      id: id,
      itemCode: item.itemCode,
      productDescription: item.description,
      natureOfSupplies: item.natureOfSupplies,
      unitPrice: item.unitPrice,
      unit: item.unit,
      taxCode: item.taxCategory.code,
      discount: 0,
      exciseTaxRate: item.exciseRate * 100,
      isExciseTaxable: item.isExciseTaxable,
    );

    await ApiService.updateSupply(
      id,
      supply,
      onSuccess: (response) {
        Get.snackbar('Success', 'Item updated in catalog');
        fetchSupplies();
      },
      onFailure: (error, response) {
        Get.snackbar('Error', 'Failed to update item in catalog');
      },
    );
  }

  Future<void> deleteSupply(String id) async {
    await ApiService.deleteSupply(
      id,
      onSuccess: (response) {
        Get.snackbar('Success', 'Item deleted from catalog');
        fetchSupplies();
      },
      onFailure: (error, response) {
        Get.snackbar('Error', 'Failed to delete item from catalog');
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
    if (items.isEmpty || buyerName.value.isEmpty || buyerTin.value.isEmpty) {
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

    final request = InvoiceRegisterRequest(
      documentDetails: {
        "DocumentNumber": nextDocNumber.toString(),
        "Type": "INV",
        "Reason": "Reason:-",
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
        "HouseNumber": "101",
        "IdNumber": "3333367896666",
        "Tin": buyerTin.value,
        "Email": "customer@buyer.com",
        "Phone": "+251944310004",
        "City": city,
        "Region": "1",
        "Country": "1",
        "Kebele": "NearAirport",
        "Wereda": "13",
        "VatNumber": "43256663343256663322",
      },
      itemList: itemListMap,
      valueDetails: {
        "TotalValue": grandTotal.toStringAsFixed(2),
        "TaxValue": totalVat.toStringAsFixed(2),
        "Discount": totalDiscount.toStringAsFixed(2),
        "ExciseValue": totalExcise.toStringAsFixed(2),
        "InvoiceCurrency": "ETB",
        "IncomeWithholdValue": incomeWithholdValue.value,
        "TransactionWithholdValue": txnWithholdValue.value,
      },
      paymentDetails: {
        "PaymentTerm": paymentMode.value,
        "Mode": paymentMode.value,
      },
      referenceDetails: {
        "RelatedDocument": null,
        "PreviousIrn": "null",
      }, // TODO: revert to null once backend schema is fixed
      version: "1",
    );

    await _sendInvoiceRequest(request);
  }

  Future<void> registerSampleInvoice() async {
    isSubmitting.value = true;
    final int nextDocNumber = await _getNextDocumentNumber();

    final tin = await ConfigPreference.getTin() ?? '0000037187';

    final request = InvoiceRegisterRequest(
      documentDetails: {
        "DocumentNumber": nextDocNumber.toString(),
        "Type": "INV",
        "Reason": "Reason:-",
        "Date": _formatInvoiceDate(DateTime.now()),
      },
      transactionType: "B2C",
      sourceSystem: {
        "SystemType": "POS",
        "CashierName": "Default Cashier",
        "SystemNumber": "F86A66EF99",
        "InvoiceCounter": nextDocNumber,
        "SalesPersonName": "Default Sales Person",
      },
      sellerDetails: {
        "Tin": tin,
        "LegalName": "Micro Sun & Solution PLC",
        "City": "101",
        "Zone": null,
        "Kebele": null,
        "SubTin": null,
        "SubCity": null,
        "Locality": null,
        "HouseNumber": null,
        "Wereda": "13",
        "Region": "1",
        "Email": "amanuielt@mssmea.com",
        "Phone": "+251947990585",
        "Country": "1",
        "TradeName": "MicroSun&SolutionPLC",
        "VatNumber": "43256663343256663322",
      },
      buyerDetails: {
        "Zone": null,
        "SubTin": null,
        "SubCity": null,
        "Locality": null,
        "LegalName": "Walk-in Customer",
        "IdType": "KID",
        "HouseNumber": "101",
        "IdNumber": "3333367896666",
        "Tin": "0088514835",
        "Email": "customer@buyer.com",
        "Phone": "+251944310004",
        "City": "101",
        "Region": "1",
        "Country": "1",
        "Kebele": "NearAirport",
        "Wereda": "13",
        "VatNumber": "43256663343256663322",
      },
      itemList: [
        {
          // "HarmonizationCode": null,
          "LineNumber": 1,
          "NatureOfSupplies": "goods",
          "UnitPrice": "796.68",
          "TotalLineAmount": "3664.73",
          "PreTaxValue": "3186.72",
          "Unit": "PCS",
          "TaxCode": "VAT15",
          "TaxAmount": "478.01",
          "Quantity": "4.00",
          "Discount": "0.00",
          "ExciseTaxValue": 0,
          "ProductDescription": "ALD-CHR-805BIT60",
          "ItemCode": "100-JR1-873",
        },
      ],
      valueDetails: {
        "TotalValue": "3664.73",
        "TaxValue": "478.01",
        "Discount": "0.00",
        "ExciseValue": "0.00",

        "ExchangeRate": null,
        "InvoiceCurrency": "ETB",
        "IncomeWithholdValue": "0.00",
        "TransactionWithholdValue": "0.00",
      },
      paymentDetails: {"PaymentTerm": "CASH", "Mode": "CASH"},
      referenceDetails: {"RelatedDocument": null, "PreviousIrn": "null"},
      version: "1",
    );
    await _sendInvoiceRequest(request);
  }

  String? _extractExpectedValue(dynamic responseData) {
    if (responseData is Map && responseData['body'] is List) {
      for (var item in responseData['body']) {
        if (item is Map && item['errorMessage'] is List) {
          for (var msg in item['errorMessage']) {
            final match = RegExp(
              r'expected\s*:\s*(\d+)',
            ).firstMatch(msg.toString());
            if (match != null) {
              return match.group(1);
            }
          }
        }
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
        final String irn = (data != null && data['irn'] != null)
            ? data['irn']
            : "mock_irn_fallback_${DateTime.now().millisecondsSinceEpoch}";

        generatedQrCode.value = irn;
        Get.snackbar('Success', 'Invoice registered successfully.');
        isSubmitting.value = false;

        // Fetch the invoice from history to ensure we have full details for the prompt
        InvoiceSummary? registeredInvoice;
        try {
          final historyController = Get.put(InvoiceHistoryController());
          await historyController.fetchInvoices(refresh: true);
          if (historyController.invoices.isNotEmpty) {
            registeredInvoice = historyController.invoices.firstWhere(
              (inv) => inv.irn == irn,
              orElse: () => historyController.invoices.first,
            );
          }
        } catch (e) {
          Logger().e('Error fetching registered invoice: $e');
        }

        clearForm();

        if (registeredInvoice != null) {
          _showPostRegistrationDialog(registeredInvoice);
        }
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

  void _showPostRegistrationDialog(InvoiceSummary invoice) {
    Get.dialog(
      barrierDismissible: false,
      Dialog(
        backgroundColor: const Color(0xFF1F1F1F),
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
              const Text(
                'Invoice Registered',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Invoice #${invoice.documentNumber} for ${invoice.buyer.legalName} has been successfully registered.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
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
                    color: Colors.white.withOpacity(0.5),
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
      backgroundColor: const Color(0xFFFF3366).withOpacity(0.1),
      colorText: Colors.white,
    );
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
