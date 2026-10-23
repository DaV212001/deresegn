import 'package:flutter/services.dart';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/invoice_controller.dart';
import '../controllers/receipt_controller.dart';
import '../models/invoice_history_model.dart';
import '../services/cancelled_invoices_storage.dart';
import '../services/invoice_pdf_service.dart';
import '../services/receipt_pdf_service.dart';
import 'invoice_generator_screen.dart';
import 'pdf_preview_screen.dart';

class InvoiceDetailScreen extends StatelessWidget {
  final InvoiceSummary invoice;
  late final Rx<InvoiceSummary> invoiceRx;
  late final RxBool isCancelledRx;
  late final RxString cancellationReasonRx;

  InvoiceDetailScreen({Key? key, required this.invoice}) : super(key: key) {
    invoiceRx = invoice.obs;
    isCancelledRx = (invoice.isCancelled ||
        (invoice.irn != null && CancelledInvoicesStorage.isCancelled(invoice.irn))).obs;
    final cachedReason = invoice.irn != null ? CancelledInvoicesStorage.getReason(invoice.irn) : null;
    final effectiveReason = invoice.cancellationReasonDescription ??
        (cachedReason != null ? _formatReasonCode(cachedReason) : '');
    cancellationReasonRx = effectiveReason.obs;
    if (invoice.irn != null) {
      Get.put(
        ReceiptFetchController(invoiceIrn: invoice.irn!),
        tag: invoice.irn,
      );
    }
  }

  String _formatReasonCode(String code) {
    switch (code) {
      case '1':
        return 'reason_code_1'.tr;
      case '2':
        return 'reason_code_2'.tr;
      case '3':
        return 'reason_code_3'.tr;
      case '4':
        return 'reason_code_4'.tr;
      default:
        return code;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM dd, yyyy HH:mm').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  void _showCancelBottomSheet(BuildContext context) {
    if (invoice.irn == null) {
      Get.snackbar('Error', 'Cannot cancel an invoice without an IRN.');
      return;
    }

    final controller = Get.put(CancelInvoiceController());
    String selectedReasonCode = '1';

    final reasonOptions = [
      {'code': '1', 'label': 'reason_code_1'.tr},
      {'code': '2', 'label': 'reason_code_2'.tr},
      {'code': '3', 'label': 'reason_code_3'.tr},
      {'code': '4', 'label': 'reason_code_4'.tr},
    ];

    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'cancel'.tr,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a valid reason code to register cancellation on MoR servers.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: selectedReasonCode,
                    isExpanded: true,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      labelText: 'cancellation_reason_code'.tr,
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: theme.inputDecorationTheme.fillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: reasonOptions.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt['code'],
                        child: Text(opt['label']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedReasonCode = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  Obx(
                    () => ElevatedButton(
                      onPressed: controller.isSubmitting.value
                          ? null
                          : () async {
                              final success = await controller.cancelInvoice(
                                invoice.irn!,
                                selectedReasonCode,
                              );
                              if (success) {
                                isCancelledRx.value = true;
                                cancellationReasonRx.value = _formatReasonCode(selectedReasonCode);
                                invoiceRx.value = invoiceRx.value.copyWith(
                                  status: 'C',
                                  cancellationReason: selectedReasonCode,
                                );
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: const Color(0xFFD32F2F),
                      ),
                      child: controller.isSubmitting.value
                          ? CircularProgressIndicator(
                              color: theme.colorScheme.onPrimary,
                            )
                          : Text(
                              'cancel'.tr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSalesReceiptBottomSheet(BuildContext context) {
    if (invoice.irn == null) {
      Get.snackbar('Error', 'Cannot register a receipt without an IRN.');
      return;
    }

    final controller = Get.put(ReceiptController());
    final amountController = TextEditingController(
      text: invoice.totals.totalValue ?? '',
    );
    final refController = TextEditingController();
    final providerController = TextEditingController();
    String selectedMode = 'CASH';

    final paymentModes = ['CASH', 'CHEQUE', 'CPO', 'CARD', 'BANK_TRANSFER'];

    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'receipt'.tr,
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Register sales receipt collection for this invoice.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                      decoration: InputDecoration(
                        labelText: 'amount'.tr,
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: theme.inputDecorationTheme.fillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedMode,
                      isExpanded: true,
                      dropdownColor: theme.cardColor,
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                      decoration: InputDecoration(
                        labelText: 'mode_of_payment'.tr,
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: theme.inputDecorationTheme.fillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: paymentModes.map((mode) {
                        return DropdownMenuItem<String>(
                          value: mode,
                          child: Text(mode),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedMode = val;
                          });
                        }
                      },
                    ),
                    if (selectedMode != 'CASH') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: refController,
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        decoration: InputDecoration(
                          labelText: 'reference_no'.tr,
                          labelStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: theme.inputDecorationTheme.fillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: providerController,
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        decoration: InputDecoration(
                          labelText: 'payment_provider'.tr,
                          labelStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: theme.inputDecorationTheme.fillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Obx(
                      () => ElevatedButton(
                        onPressed: controller.isSubmittingReceipt.value
                            ? null
                            : () {
                                if (amountController.text.isNotEmpty) {
                                  controller
                                      .registerSalesReceipt(
                                        invoice.irn!,
                                        amountController.text,
                                        invoice.documentNumber ?? '',
                                        invoice.totals.totalValue ??
                                            amountController.text,
                                        modeOfPayment: selectedMode,
                                        referenceNumber: refController.text,
                                        paymentServiceProvider:
                                            providerController.text,
                                      )
                                      .then((_) => Navigator.pop(context));
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: controller.isSubmittingReceipt.value
                            ? CircularProgressIndicator(
                                color: theme.colorScheme.onPrimary,
                              )
                            : Text(
                                'receipt'.tr,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ignore: unused_element
  void _showWithholdingBottomSheet(BuildContext context) {
    if (invoice.irn == null) {
      Get.snackbar('Error', 'Cannot register withholding without an IRN.');
      return;
    }

    final controller = Get.put(ReceiptController());
    final valDet = invoice.requestPayload?['ValueDetails'] as Map<String, dynamic>?;
    final defaultPreTax = valDet?['TaxableAmount'] ?? invoice.totals.totalValue ?? '20000.00';
    final pretaxController = TextEditingController(text: defaultPreTax.toString());

    String selectedNature = 'goods';
    double currentRate = 0.03;

    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final pretax = double.tryParse(pretaxController.text) ?? 0.0;
            final withholdAmount = pretax * currentRate;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ከተከፋይ ሒሳብ ላይ ለተቀነሰ ግብር ደረሰኝ',
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Record Buyer-Issued Withholding Certificate (MoR Proclamation No. 1395/2025)',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('ዕቃዎች / Goods (3%)'),
                          selected: selectedNature == 'goods',
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                selectedNature = 'goods';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('አገልግሎቶች / Services (3%)'),
                          selected: selectedNature == 'services',
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                selectedNature = 'services';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedNature == 'goods'
                        ? 'Statutory threshold: Supplies worth ≥ 20,000 ETB'
                        : 'Statutory threshold: Service contracts ≥ 10,000 ETB',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pretaxController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'የግብር መነሻ ድምር / Pre-Tax Amount (ETB)',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: theme.inputDecorationTheme.fillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('የተያዘ ግብር / Withheld (3%):', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${withholdAmount.toStringAsFixed(2)} ETB',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Obx(
                    () => ElevatedButton(
                      onPressed: controller.isSubmittingWithholding.value
                          ? null
                          : () {
                              final amount = double.tryParse(pretaxController.text) ?? 0.0;
                              if (amount > 0) {
                                controller
                                    .registerWithholding(
                                      invoice.irn!,
                                      invoice.buyer.tin ?? '',
                                      amount,
                                      natureOfSupplies: selectedNature,
                                      rate: currentRate,
                                    )
                                    .then((_) {
                                      if (Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }
                                    });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: controller.isSubmittingWithholding.value
                          ? CircularProgressIndicator(
                              color: theme.colorScheme.onPrimary,
                            )
                          : const Text(
                              'Record Buyer Withholding Certificate',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _generateAndSharePdf(
    BuildContext context,
    ThemeData theme,
  ) async {
    Get.dialog(
      Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      ),
      barrierDismissible: false,
    );
    try {
      final currentInvoice = invoiceRx.value;
      final bytes = await InvoicePdfService.generate(
        currentInvoice,
        isCancelled: isCancelledRx.value || currentInvoice.isCancelled,
      );
      Get.back();

      Get.to(
        () => PdfPreviewScreen(
          pdfBytes: bytes,
          title: 'Invoice ${currentInvoice.documentNumber ?? currentInvoice.id}',
        ),
      );
    } catch (e) {
      Get.back();
      Get.snackbar(
        'Error',
        'Failed to generate PDF: $e',
        backgroundColor: theme.colorScheme.error.withOpacity(0.1),
        colorText: theme.colorScheme.onError,
      );
    }
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    bool isHighlight = false,
    bool isCancelled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isCancelled
                    ? const Color(0xFFD32F2F)
                    : isHighlight
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                fontSize: isHighlight ? 16 : 14,
                decoration: isCancelled ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    String? status,
    ThemeData theme, {
    bool isCancelled = false,
  }) {
    Color bgColor;
    Color textColor;
    Color borderColor;
    String text;
    IconData icon;

    final effectiveCancelled = isCancelled ||
        status?.toUpperCase() == 'C' ||
        status?.toUpperCase() == 'CANCELLED';

    if (effectiveCancelled) {
      bgColor = const Color(0xFFD32F2F).withOpacity(0.12);
      textColor = const Color(0xFFD32F2F);
      borderColor = const Color(0xFFD32F2F).withOpacity(0.35);
      text = 'cancelled'.tr;
      icon = Icons.cancel_outlined;
    } else if (status?.toUpperCase() == 'A' || status?.toUpperCase() == 'ACTIVE') {
      bgColor = const Color(0xFF2E7D32).withOpacity(0.12);
      textColor = const Color(0xFF2E7D32);
      borderColor = const Color(0xFF2E7D32).withOpacity(0.35);
      text = 'active'.tr;
      icon = Icons.check_circle_outline;
    } else {
      bgColor = Colors.grey.withOpacity(0.15);
      textColor = Colors.grey.shade700;
      borderColor = Colors.grey.withOpacity(0.3);
      text = status ?? 'unknown'.tr;
      icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTypeBadge(
    String rawType,
    String displayType,
    ThemeData theme,
  ) {
    Color textColor;
    Color bgColor;

    switch (rawType.toUpperCase()) {
      case 'CREDIT_SALE':
        textColor = const Color(0xFF1E88E5);
        bgColor = const Color(0xFF1E88E5).withOpacity(0.18);
        break;
      case 'CREDIT_NOTE':
        textColor = const Color(0xFFFB8C00);
        bgColor = const Color(0xFFFB8C00).withOpacity(0.18);
        break;
      case 'DEBIT_NOTE':
        textColor = const Color(0xFF8E24AA);
        bgColor = const Color(0xFF8E24AA).withOpacity(0.18);
        break;
      case 'WITHHOLDING':
        textColor = const Color(0xFF00ACC1);
        bgColor = const Color(0xFF00ACC1).withOpacity(0.18);
        break;
      case 'CASH_SALE':
      default:
        textColor = const Color(0xFF43A047);
        bgColor = const Color(0xFF43A047).withOpacity(0.18);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.35), width: 0.8),
      ),
      child: Text(
        displayType,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCopyableRefIrnRow(BuildContext context, String fullIrn) {
    final String displayIrn = fullIrn.length > 20
        ? '${fullIrn.substring(0, 10)}...${fullIrn.substring(fullIrn.length - 8)}'
        : fullIrn;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'ref_invoice_irn'.tr,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: fullIrn));
              Get.snackbar(
                'Copied',
                'Reference IRN copied to clipboard',
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 2),
                backgroundColor: Theme.of(context).cardColor,
                colorText: Theme.of(context).textTheme.bodyLarge?.color,
                margin: const EdgeInsets.all(16),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayIrn,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = invoice.totals.currency ?? 'ETB';
    final itemsList =
        (invoice.requestPayload?['ItemList'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'invoice_details'.tr,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color:
                theme.appBarTheme.foregroundColor ??
                theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        automaticallyImplyLeading: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
              color: Color(0xFF4FC3F7),
            ),
            tooltip: 'Preview PDF',
            onPressed: () => _generateAndSharePdf(context, Theme.of(context)),
          ),
          if (invoice.irn != null && invoice.irn!.isNotEmpty)
            Obx(() {
              if (isCancelledRx.value) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'Adjustment Notes',
                onSelected: (value) {
                  if (value == 'credit_note') {
                    Get.to(
                      () => InvoiceGeneratorScreen(
                        initialDocumentType: 'CREDIT_NOTE',
                        referenceInvoice: invoiceRx.value,
                      ),
                    );
                  } else if (value == 'debit_note') {
                    Get.to(
                      () => InvoiceGeneratorScreen(
                        initialDocumentType: 'DEBIT_NOTE',
                        referenceInvoice: invoiceRx.value,
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'credit_note',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.remove_circle_outline, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Text('Issue Credit Note (CRE)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'debit_note',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('Issue Debit Note (DEB)'),
                      ],
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(() {
              final isCancelled = isCancelledRx.value;
              final reason = cancellationReasonRx.value;
              if (!isCancelled) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFD32F2F).withOpacity(0.55),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F).withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cancel_rounded,
                        color: Color(0xFFD32F2F),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'cancelled'.tr.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFFD32F2F),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD32F2F).withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'ተሰርዟል',
                                  style: TextStyle(
                                    color: Color(0xFFD32F2F),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'invoice_cancelled_notice'.tr,
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
                              fontSize: 12,
                            ),
                          ),
                          if (reason.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFD32F2F).withOpacity(0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '${'cancellation_reason'.tr}: $reason',
                                style: const TextStyle(
                                  color: Color(0xFFD32F2F),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'summary'.tr,
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Obx(() => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDocumentTypeBadge(
                            invoice.rawDocumentType,
                            invoice.documentType,
                            theme,
                          ),
                          const SizedBox(width: 6),
                          _buildStatusBadge(
                            isCancelledRx.value ? 'C' : invoice.status,
                            theme,
                            isCancelled: isCancelledRx.value,
                          ),
                        ],
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    context,
                    'invoice_type'.tr,
                    invoice.documentType,
                  ),
                  _buildInfoRow(
                    context,
                    'buyer'.tr,
                    invoice.buyer.legalName ?? 'N/A',
                  ),
                  _buildInfoRow(
                    context,
                    'buyer_tin'.tr,
                    invoice.buyer.tin ?? 'N/A',
                  ),
                  _buildInfoRow(
                    context,
                    'document_no'.tr,
                    invoice.documentNumber ?? 'N/A',
                  ),
                  if (invoice.referenceIrn != null)
                    _buildCopyableRefIrnRow(
                      context,
                      invoice.referenceIrn!,
                    ),
                  _buildInfoRow(
                    context,
                    'date'.tr,
                    _formatDate(invoice.createdAt),
                  ),
                  Obx(() {
                    final isCancelled = isCancelledRx.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'status'.tr,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          _buildStatusBadge(
                            isCancelled ? 'C' : invoice.status,
                            theme,
                            isCancelled: isCancelled,
                          ),
                        ],
                      ),
                    );
                  }),
                  Obx(() {
                    final reason = cancellationReasonRx.value;
                    if (!isCancelledRx.value || reason.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return _buildInfoRow(
                      context,
                      'cancellation_reason'.tr,
                      reason,
                    );
                  }),
                  const Divider(color: Color(0xFF333333), height: 32),
                  Obx(() => _buildInfoRow(
                    context,
                    'total_value'.tr,
                    '${invoiceRx.value.totals.totalValue ?? '0.00'} $currency',
                    isHighlight: true,
                    isCancelled: isCancelledRx.value,
                  )),
                  _buildInfoRow(
                    context,
                    'tax_value'.tr,
                    '${invoice.totals.taxValue ?? '0.00'} $currency',
                  ),
                  _buildInfoRow(
                    context,
                    'discount'.tr,
                    '${invoice.totals.discount ?? '0.00'} $currency',
                  ),
                ],
              ),
            ),

            if (invoice.signedQr != null) ...[
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.memory(
                    base64Decode(invoice.signedQr!),
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.qr_code,
                      size: 150,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'IRN: ${invoice.irn ?? 'N/A'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ),
            ],

            if (itemsList.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'line_items'.tr,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...itemsList.map((item) {
                final Map<String, dynamic> itemMap =
                    item as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              itemMap['ProductDescription']?.toString() ??
                                  'Item',
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${itemMap['Quantity']} x ${itemMap['UnitPrice']} $currency',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${itemMap['TotalLineAmount']} $currency',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],

            const SizedBox(height: 32),
            Text(
              'actions'.tr,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              final isCancelled = isCancelledRx.value;
              return Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: isCancelled
                          ? Icons.block
                          : CupertinoIcons.clear_circled,
                      title: isCancelled
                          ? 'cancelled'.tr
                          : 'cancel'.tr,
                      color: isCancelled
                          ? Colors.grey
                          : const Color(0xFFFF3366),
                      onTap: isCancelled
                          ? () => Get.snackbar(
                                'Notice',
                                'invoice_already_cancelled'.tr,
                                snackPosition: SnackPosition.BOTTOM,
                              )
                          : () => _showCancelBottomSheet(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      icon: CupertinoIcons.money_dollar,
                      title: 'receipt'.tr,
                      color: isCancelled
                          ? Colors.grey
                          : Theme.of(context).primaryColor,
                      onTap: isCancelled
                          ? () => Get.snackbar(
                                'Notice',
                                'Cannot issue receipts for a cancelled invoice.',
                                snackPosition: SnackPosition.BOTTOM,
                              )
                          : () => _showSalesReceiptBottomSheet(context),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 32),
            if (invoice.irn != null) ...[
              Text(
                'associated_receipts'.tr,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Obx(() {
                final controller = Get.find<ReceiptFetchController>(
                  tag: invoice.irn,
                );
                if (controller.isLoading.value) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  );
                }
                if (controller.errorMessage.isNotEmpty) {
                  return Center(
                    child: Text(
                      controller.errorMessage.value,
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (controller.receipts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'no_receipts_found'.tr,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return Column(
                  children: controller.receipts.map((receipt) {
                    final statusColor = receipt.status == 'A'
                        ? Theme.of(context).primaryColor
                        : Colors.orange;
                    final statusText = receipt.status == 'A'
                        ? 'Active'
                        : receipt.status ?? 'Unknown';

                    final rPayload = receipt.requestPayload ?? {};
                    final bool isWht = rPayload.containsKey('WithholdDetail') ||
                        (receipt.receiptNumber != null && receipt.receiptNumber!.toUpperCase().contains('WHT')) ||
                        (receipt.morId != null && receipt.morId!.toUpperCase().contains('WHT')) ||
                        rPayload['Reason']?.toString().toLowerCase().contains('withholding') == true ||
                        rPayload['ReceiptType']?.toString().toUpperCase() == 'TWTH';

                    final wDet = (rPayload['WithholdDetail'] as Map<String, dynamic>?) ?? {};
                    final String typeLabel = isWht ? 'Withholding Tax (WHT)' : 'Cash Receipt (CRB)';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.4,
                                child: Text(
                                  'R #${receipt.receiptNumber ?? 'N/A'}',
                                  style: TextStyle(
                                    color: theme.textTheme.bodyLarge?.color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(CupertinoIcons.printer),
                                    color: theme.primaryColor,
                                    onPressed: () async {
                                      final bytes =
                                          await ReceiptPdfService.generate(
                                            receipt,
                                            invoice,
                                          );
                                      if (!context.mounted) return;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PdfPreviewScreen(
                                            pdfBytes: bytes,
                                            title:
                                                'Receipt ${receipt.receiptNumber ?? receipt.id}',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (isWht) ...[
                            _buildInfoRow(
                              context,
                              'type'.tr,
                              typeLabel,
                            ),
                            _buildInfoRow(
                              context,
                              'withholding'.tr,
                              '${wDet['WithholdingAmount'] ?? wDet['IncomeWithholdValue'] ?? '0.00'} ETB',
                              isHighlight: true,
                            ),
                            _buildInfoRow(
                              context,
                              'የግብር መነሻ / Pre-Tax',
                              '${wDet['PreTaxAmount'] ?? invoice.totals.totalValue ?? '0.00'} ETB',
                            ),
                            _buildInfoRow(
                              context,
                              'Withholding Agent TIN',
                              '${rPayload['BuyerTIN'] ?? invoice.buyer.tin ?? 'N/A'}',
                            ),
                            _buildInfoRow(
                              context,
                              'date'.tr,
                              _formatDate(rPayload['ReceiptDate'] ?? receipt.createdAt),
                            ),
                          ] else ...[
                            _buildInfoRow(
                              context,
                              'type'.tr,
                              typeLabel,
                            ),
                            _buildInfoRow(
                              context,
                              'amount'.tr,
                              '${rPayload['CollectedAmount'] ?? invoice.totals.totalValue ?? '0.00'} ETB',
                              isHighlight: true,
                            ),
                            _buildInfoRow(
                              context,
                              'date'.tr,
                              _formatDate(rPayload['ReceiptDate'] ?? receipt.createdAt),
                            ),
                            _buildInfoRow(
                              context,
                              'mode_of_payment'.tr,
                              rPayload['TransactionDetails']?['ModeOfPayment'] ?? 'CASH',
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
