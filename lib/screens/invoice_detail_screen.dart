import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/invoice_controller.dart';
import '../controllers/receipt_controller.dart';
import '../models/invoice_history_model.dart';
import '../services/invoice_pdf_service.dart';
import '../services/receipt_pdf_service.dart';
import 'pdf_preview_screen.dart';

class InvoiceDetailScreen extends StatelessWidget {
  final InvoiceSummary invoice;

  InvoiceDetailScreen({Key? key, required this.invoice}) : super(key: key) {
    if (invoice.irn != null) {
      Get.put(
        ReceiptFetchController(invoiceIrn: invoice.irn!),
        tag: invoice.irn,
      );
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
    final reasonController = TextEditingController();

    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                'Cancel Invoice',
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Provide a reason code to cancel this invoice on the tax authority logs.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: reasonController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  labelText: 'Reason Code (e.g. 1)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Obx(
                () => ElevatedButton(
                  onPressed: controller.isSubmitting.value
                      ? null
                      : () {
                          if (reasonController.text.isNotEmpty) {
                            controller
                                .cancelInvoice(
                                  invoice.irn!,
                                  reasonController.text,
                                )
                                .then((_) => Navigator.pop(context));
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3366),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: controller.isSubmitting.value
                      ? CircularProgressIndicator(
                          color: theme.colorScheme.onPrimary,
                        )
                      : const Text(
                          'Submit Cancellation',
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
  }

  void _showSalesReceiptBottomSheet(BuildContext context) {
    if (invoice.irn == null) {
      Get.snackbar('Error', 'Cannot register a receipt without an IRN.');
      return;
    }

    final controller = Get.put(ReceiptController());
    final amountController = TextEditingController();

    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                'Register Sales Receipt',
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Register cash collections applied to this Invoice.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  labelText: 'Collected Amount (ETB)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
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
                                )
                                .then((_) => Navigator.pop(context));
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFB3),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: controller.isSubmittingReceipt.value
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          'Register Sales Receipt',
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
  }

  void _showWithholdingBottomSheet(BuildContext context) {
    if (invoice.irn == null) {
      Get.snackbar('Error', 'Cannot register withholding without an IRN.');
      return;
    }

    final controller = Get.put(ReceiptController());
    final pretaxController = TextEditingController();

    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                'Register Withholding',
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Submit dynamic 2% withholding tax adjustments for this invoice.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: pretaxController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  labelText: 'Pre-Tax Amount (ETB)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Obx(
                () => ElevatedButton(
                  onPressed: controller.isSubmittingWithholding.value
                      ? null
                      : () {
                          final pretax =
                              double.tryParse(pretaxController.text) ?? 0;
                          if (pretax > 0) {
                            controller
                                .registerWithholding(
                                  invoice.irn!,
                                  invoice.buyer.tin ?? '',
                                  pretax,
                                )
                                .then((_) => Navigator.pop(context));
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFB3),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: controller.isSubmittingWithholding.value
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          'Register 2% Withholding',
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
  }

  Future<void> _generateAndSharePdf(
    BuildContext context,
    ThemeData theme,
  ) async {
    Get.dialog(
      const Center(child: CircularProgressIndicator(color: Color(0xFF00FFB3))),
      barrierDismissible: false,
    );
    try {
      final bytes = await InvoicePdfService.generate(invoice);
      Get.back();

      Get.to(
        () => PdfPreviewScreen(
          pdfBytes: bytes,
          title: 'Invoice ${invoice.documentNumber ?? invoice.id}',
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
                color: isHighlight
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                fontSize: isHighlight ? 16 : 14,
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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  Text(
                    'summary'.tr,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  _buildInfoRow(
                    context,
                    'date'.tr,
                    _formatDate(invoice.createdAt),
                  ),
                  _buildInfoRow(
                    context,
                    'status'.tr,
                    invoice.status ?? 'unknown'.tr,
                  ),
                  const Divider(color: Color(0xFF333333), height: 32),
                  _buildInfoRow(
                    context,
                    'total_value'.tr,
                    '${invoice.totals.totalValue ?? '0.00'} $currency',
                    isHighlight: true,
                  ),
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
                        style: const TextStyle(
                          color: Color(0xFF00FFB3),
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
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: CupertinoIcons.clear_circled,
                    title: 'cancel'.tr,
                    color: const Color(0xFFFF3366),
                    onTap: () => _showCancelBottomSheet(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: CupertinoIcons.money_dollar,
                    title: 'receipt'.tr,
                    color: const Color(0xFF00FFB3),
                    onTap: () => _showSalesReceiptBottomSheet(context),
                  ),
                ),
                // const SizedBox(width: 12),
                // Expanded(
                //   child: _ActionCard(
                //     icon: CupertinoIcons.percent,
                //     title: 'withholding'.tr,
                //     color: const Color(0xFF00FFB3),
                //     onTap: () => _showWithholdingBottomSheet(context),
                //   ),
                // ),
              ],
            ),
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
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00FFB3)),
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
                        ? const Color(0xFF00FFB3)
                        : Colors.orange;
                    final statusText = receipt.status == 'A'
                        ? 'Active'
                        : receipt.status ?? 'Unknown';
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
                          _buildInfoRow(
                            context,
                            'amount'.tr,
                            '${receipt.requestPayload?['CollectedAmount'] ?? '0.00'} ETB',
                            isHighlight: true,
                          ),
                          _buildInfoRow(
                            context,
                            'date'.tr,
                            _formatDate(receipt.requestPayload?['ReceiptDate']),
                          ),
                          _buildInfoRow(
                            context,
                            'mode_of_payment'.tr,
                            receipt.requestPayload?['TransactionDetails']?['ModeOfPayment'] ??
                                'Unknown',
                          ),
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
