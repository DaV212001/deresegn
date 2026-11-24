import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/invoice_history_model.dart';
import '../models/receipt_models.dart';
import '../services/api_service.dart';
import '../services/invoice_pdf_service.dart';
import '../services/receipt_pdf_service.dart';
import '../services/thermal_receipt_pdf_service.dart';

class PdfPreviewScreen extends StatefulWidget {
  final Uint8List? pdfBytes;
  final String title;
  final String? irn;
  final String? documentNumber;
  final bool isCancelled;
  final InvoiceSummary? invoice;
  final ReceiptSummary? receipt;
  final InvoiceSummary? parentInvoice;
  final bool isWithholding;
  final Future<Uint8List> Function(ReceiptPaperFormat format)? formatGenerator;
  final ReceiptPaperFormat? initialFormat;

  const PdfPreviewScreen({
    super.key,
    this.pdfBytes,
    required this.title,
    this.irn,
    this.documentNumber,
    this.isCancelled = false,
    this.invoice,
    this.receipt,
    this.parentInvoice,
    this.isWithholding = false,
    this.formatGenerator,
    this.initialFormat,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  static const String _prefKey = 'preferred_receipt_format';
  late ReceiptPaperFormat _selectedFormat;
  Uint8List? _currentPdfBytes;
  bool _isLoading = false;

  bool get _canSwitchFormat =>
      widget.invoice != null ||
      (widget.receipt != null && widget.parentInvoice != null) ||
      widget.formatGenerator != null;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.initialFormat ?? ReceiptPaperFormat.a4;
    _currentPdfBytes = widget.pdfBytes;
    _initFormat();
  }

  Future<void> _initFormat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      ReceiptPaperFormat format = _selectedFormat;
      if (widget.initialFormat != null) {
        format = widget.initialFormat!;
      } else if (saved != null) {
        if (saved == 'roll80') {
          format = ReceiptPaperFormat.roll80;
        } else if (saved == 'roll58') {
          format = ReceiptPaperFormat.roll58;
        } else {
          format = ReceiptPaperFormat.a4;
        }
      }

      if (_canSwitchFormat && (_currentPdfBytes == null || format != _selectedFormat)) {
        await _loadFormatBytes(format);
      } else if (_currentPdfBytes == null) {
        await _loadFormatBytes(format);
      }
    } catch (_) {
      if (_currentPdfBytes == null && _canSwitchFormat) {
        await _loadFormatBytes(_selectedFormat);
      }
    }
  }

  Future<void> _loadFormatBytes(ReceiptPaperFormat format) async {
    setState(() {
      _isLoading = true;
      _selectedFormat = format;
    });

    try {
      Uint8List? bytes;
      if (widget.formatGenerator != null) {
        bytes = await widget.formatGenerator!(format);
      } else if (widget.invoice != null) {
        if (format == ReceiptPaperFormat.a4) {
          if (widget.receipt != null) {
            final pdfTheme = await InvoicePdfService.loadPdfTheme();
            final pdf = pw.Document(theme: pdfTheme);
            await InvoicePdfService.generateIntoDocument(pdf, widget.invoice!, isCancelled: widget.isCancelled);
            await ReceiptPdfService.generateIntoDocument(pdf, widget.receipt!, widget.invoice!, isCancelled: widget.isCancelled);
            bytes = await pdf.save();
          } else {
            bytes = await InvoicePdfService.generate(
              widget.invoice!,
              isCancelled: widget.isCancelled,
            );
          }
        } else {
          bytes = await ThermalReceiptPdfService.generateInvoiceReceipt(
            widget.invoice!,
            paperFormat: format,
            isCancelled: widget.isCancelled,
          );
        }
      } else if (widget.receipt != null && widget.parentInvoice != null) {
        if (format == ReceiptPaperFormat.a4) {
          bytes = await ReceiptPdfService.generate(
            widget.receipt!,
            widget.parentInvoice!,
            isWithholding: widget.isWithholding,
            isCancelled: widget.isCancelled,
          );
        } else {
          bytes = await ThermalReceiptPdfService.generateVoucherReceipt(
            widget.receipt!,
            widget.parentInvoice!,
            paperFormat: format,
            isWithholding: widget.isWithholding,
            isCancelled: widget.isCancelled,
          );
        }
      }

      if (mounted) {
        setState(() {
          if (bytes != null) _currentPdfBytes = bytes;
          _isLoading = false;
        });

        // Persist preference
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKey, format.name);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Get.snackbar(
          'Format Switch Error',
          'Could not generate format: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade800,
          colorText: Colors.white,
        );
      }
    }
  }

  void _showNotifyDialog(BuildContext context) {
    if (_currentPdfBytes == null) return;
    String selectedChannel = 'sms';
    bool resend = false;
    final theme = Theme.of(context);

    Get.dialog(
      StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  Icons.send_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Send to Buyer',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deliver this invoice directly to the buyer via MoR notification channels.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Delivery Channel',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('SMS (Text message with link)'),
                    value: 'sms',
                    groupValue: selectedChannel,
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedChannel = val);
                    },
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Email (Invoice PDF attachment)'),
                    value: 'email',
                    groupValue: selectedChannel,
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedChannel = val);
                    },
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Both (SMS & Email)'),
                    value: 'both',
                    groupValue: selectedChannel,
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedChannel = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Replace PDF on file & re-send',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: resend,
                    onChanged: (val) {
                      setModalState(() => resend = val ?? false);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  Get.back();
                  _executeNotification(context, selectedChannel, resend);
                },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Send'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeNotification(
    BuildContext context,
    String channel,
    bool resend,
  ) async {
    if (_currentPdfBytes == null) return;
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    void handleSuccess(Map<String, dynamic> data) {
      if (Get.isDialogOpen ?? false) Get.back();

      final message = data['message']?.toString() ?? 'Notification processed.';
      final isSkipped = message.toLowerCase().contains('skipped') ||
          message.toLowerCase().contains('no phone');

      Get.snackbar(
        isSkipped ? 'Notification Skipped' : 'Notification Sent',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: isSkipped ? Colors.amber.shade900 : Colors.green.shade800,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    }

    void handleFailure(Object error, dynamic response) {
      if (Get.isDialogOpen ?? false) Get.back();

      String errorMsg = error.toString();
      if (response != null && response.data is Map && response.data['message'] != null) {
        errorMsg = response.data['message'].toString();
      }

      Get.snackbar(
        'Delivery Failed',
        errorMsg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    }

    if (widget.isCancelled) {
      await ApiService.notifyInvoiceCancellation(
        pdfBytes: _currentPdfBytes!,
        irn: widget.irn,
        documentNumber: widget.documentNumber,
        channel: channel,
        resend: resend,
        onSuccess: handleSuccess,
        onFailure: handleFailure,
      );
    } else {
      await ApiService.notifyInvoiceRegistration(
        pdfBytes: _currentPdfBytes!,
        irn: widget.irn,
        documentNumber: widget.documentNumber,
        channel: channel,
        resend: resend,
        onSuccess: handleSuccess,
        onFailure: handleFailure,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDocIdentifier = (widget.irn != null && widget.irn!.isNotEmpty) ||
        (widget.documentNumber != null && widget.documentNumber!.isNotEmpty);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        iconTheme: IconThemeData(
          color: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
        ),
        actions: [
          if (hasDocIdentifier)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () => _showNotifyDialog(context),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text(
                  'Send to Buyer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_canSwitchFormat)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.print_outlined,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Print / Receipt Format:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ReceiptPaperFormat>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      segments: const [
                        ButtonSegment(
                          value: ReceiptPaperFormat.a4,
                          label: Text(
                            'A4',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                          ),
                          icon: Icon(Icons.description_outlined, size: 14),
                          tooltip: 'A4 Standard Sheet',
                        ),
                        ButtonSegment(
                          value: ReceiptPaperFormat.roll80,
                          label: Text(
                            '80mm',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                          ),
                          icon: Icon(Icons.receipt_long_outlined, size: 14),
                          tooltip: 'POS Thermal 80mm Roll',
                        ),
                        ButtonSegment(
                          value: ReceiptPaperFormat.roll58,
                          label: Text(
                            '58mm',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                          ),
                          icon: Icon(Icons.receipt_outlined, size: 14),
                          tooltip: 'POS Thermal 58mm Roll',
                        ),
                      ],
                      selected: {_selectedFormat},
                      onSelectionChanged: (newSelection) {
                        if (newSelection.isNotEmpty) {
                          _loadFormatBytes(newSelection.first);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: theme.primaryColor),
                        const SizedBox(height: 12),
                        Text(
                          'Rendering ${_selectedFormat == ReceiptPaperFormat.a4 ? 'A4 PDF' : '${_selectedFormat == ReceiptPaperFormat.roll80 ? '80mm' : '58mm'} Thermal Slip'}...',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : (_currentPdfBytes != null)
                    ? PdfPreview(
                        key: ValueKey('${_selectedFormat.name}_${_currentPdfBytes!.length}'),
                        build: (format) => _currentPdfBytes!,
                        allowPrinting: true,
                        allowSharing: true,
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        canDebug: false,
                        initialPageFormat: _selectedFormat == ReceiptPaperFormat.a4
                            ? PdfPageFormat.a4
                            : (_selectedFormat == ReceiptPaperFormat.roll80
                                ? const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity)
                                : const PdfPageFormat(57 * PdfPageFormat.mm, double.infinity)),
                        pdfFileName: '${widget.title.replaceAll(' ', '_')}_${_selectedFormat.name}.pdf',
                      )
                    : const Center(
                        child: Text('No PDF data available'),
                      ),
          ),
        ],
      ),
    );
  }
}
