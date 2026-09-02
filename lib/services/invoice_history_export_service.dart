import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/invoice_history_model.dart';
import '../screens/pdf_preview_screen.dart';
import 'invoice_pdf_service.dart';

class InvoiceHistoryExportService {
  static final _numFmt = NumberFormat('#,##0.00');
  static final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  static final _shortDateFmt = DateFormat('MMM dd, yyyy');

  /// Generate a clean, Excel-compatible CSV string with UTF-8 BOM
  static Uint8List generateCsvBytes(List<InvoiceSummary> invoices) {
    final buffer = StringBuffer();

    // UTF-8 BOM for Excel compatibility
    buffer.write('\uFEFF');

    // CSV Header
    final headers = [
      'Invoice ID',
      'IRN',
      'Document Number',
      'Date',
      'Status',
      'Buyer Name',
      'Buyer TIN',
      'Buyer Phone',
      'Buyer Email',
      'Buyer City',
      'Transaction Type',
      'Currency',
      'Subtotal',
      'Excise Tax',
      'Discount',
      'VAT Tax',
      'Income Withholding',
      'Txn Withholding',
      'Grand Total',
    ];

    buffer.writeln(headers.map(_escapeCsv).join(','));

    for (final inv in invoices) {
      final payload = inv.requestPayload ?? {};
      final valDet = (payload['ValueDetails'] as Map<String, dynamic>?) ?? {};
      final docDet =
          (payload['DocumentDetails'] as Map<String, dynamic>?) ?? {};

      final docNum = inv.documentNumber ?? docDet['DocumentNumber'] ?? 'N/A';
      final dateStr = inv.createdAt ?? docDet['Date'] ?? '';
      String formattedDate = dateStr;
      try {
        if (dateStr.isNotEmpty) {
          formattedDate = _dateFmt.format(DateTime.parse(dateStr).toLocal());
        }
      } catch (_) {}

      final statusStr = inv.status == 'A'
          ? 'Active'
          : (inv.status == 'C' ? 'Cancelled' : (inv.status ?? 'Unknown'));

      final subtotal = valDet['TotalValue'] ?? inv.totals.totalValue ?? '0.00';
      final excise = valDet['ExciseValue'] ?? inv.totals.exciseValue ?? '0.00';
      final discount = valDet['Discount'] ?? inv.totals.discount ?? '0.00';
      final tax = valDet['TaxValue'] ?? inv.totals.taxValue ?? '0.00';
      final incomeWithhold = valDet['IncomeWithholdValue'] ?? '0.00';
      final txnWithhold = valDet['TransactionWithholdValue'] ?? '0.00';
      final grandTotal =
          inv.totals.totalValue ?? valDet['TotalValue'] ?? '0.00';

      final row = [
        inv.id.toString(),
        inv.irn ?? 'N/A',
        docNum,
        formattedDate,
        statusStr,
        inv.buyer.legalName ?? 'Walk-in / N/A',
        inv.buyer.tin ?? 'N/A',
        inv.buyer.phone ?? '',
        inv.buyer.email ?? '',
        inv.buyer.city ?? '',
        inv.transactionType ?? payload['TransactionType'] ?? 'B2C',
        inv.totals.currency ?? 'ETB',
        subtotal.toString(),
        excise.toString(),
        discount.toString(),
        tax.toString(),
        incomeWithhold.toString(),
        txnWithhold.toString(),
        grandTotal.toString(),
      ];

      buffer.writeln(row.map(_escapeCsv).join(','));
    }

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static String _escapeCsv(dynamic field) {
    if (field == null) return '""';
    final str = field.toString();
    if (str.contains(',') ||
        str.contains('"') ||
        str.contains('\n') ||
        str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return '"$str"';
  }

  /// Share or save CSV file
  static Future<void> exportAndShareCsv(
    List<InvoiceSummary> invoices, {
    String? filename,
  }) async {
    final bytes = generateCsvBytes(invoices);
    final fname =
        filename ??
        'invoice_history_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    await Printing.sharePdf(bytes: bytes, filename: fname);
  }

  /// Generate a multi-page PDF summary report with the Deresegn letterhead
  static Future<Uint8List> generateHistoryReportPdf(
    List<InvoiceSummary> invoices, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdfTheme = await InvoicePdfService.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);

    pw.MemoryImage? letterheadImage;
    try {
      final imgBytes = await rootBundle.load('assets/deresegn_letterhead.png');
      letterheadImage = pw.MemoryImage(imgBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Letterhead image error: $e');
    }

    // Calculate report statistics
    int totalCount = invoices.length;
    int activeCount = 0;
    int cancelledCount = 0;
    double grandTotalSum = 0.0;
    double totalTaxSum = 0.0;

    for (final inv in invoices) {
      if (inv.status == 'A') activeCount++;
      if (inv.status == 'C') cancelledCount++;
      final total = double.tryParse(inv.totals.totalValue ?? '0') ?? 0.0;
      final tax = double.tryParse(inv.totals.taxValue ?? '0') ?? 0.0;
      grandTotalSum += total;
      totalTaxSum += tax;
    }

    String dateRangeText = (startDate != null && endDate != null)
        ? '${_shortDateFmt.format(startDate)} - ${_shortDateFmt.format(endDate)}'
        : 'All Available Records (${DateFormat('MMM yyyy').format(DateTime.now())})';

    const headerBg = PdfColor.fromInt(0xFF0D253A);
    const accentBg = PdfColor.fromInt(0xFFE8F0F8);
    const tableHead = PdfColor.fromInt(0xFF0D253A);
    const divider = PdfColor.fromInt(0xFFCCCCCC);
    const bodyText = PdfColor.fromInt(0xFF222222);
    const white = PdfColors.white;

    final styleBody = pw.TextStyle(fontSize: 7.5, color: bodyText);
    final styleBold = pw.TextStyle(
      fontSize: 7.5,
      fontWeight: pw.FontWeight.bold,
      color: bodyText,
    );
    final styleSmall = pw.TextStyle(fontSize: 6.5, color: bodyText);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(26, 46, 26, 50),
          buildBackground: (context) {
            if (letterheadImage != null) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(letterheadImage, fit: pw.BoxFit.cover),
              );
            }
            return pw.SizedBox();
          },
        ),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Top banner: Left space reserved for letterhead logo, right space contains branded banner
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(width: 90, height: 70),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: pw.BoxDecoration(
                        color: headerBg,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Left: Company Info
                          pw.Expanded(
                            flex: 3,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Deresegn',
                                  style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                    color: white,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Addis Ababa, Ethiopia',
                                  style: pw.TextStyle(
                                    fontSize: 7,
                                    color: white,
                                  ),
                                ),
                                pw.Text(
                                  'Tel: +251 91 105 8179  |  Email: contact@deresegn.com',
                                  style: pw.TextStyle(
                                    fontSize: 7,
                                    color: white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          // Right: Document Title & Badge
                          pw.Expanded(
                            flex: 3,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text(
                                  'የደረሰኞች ታሪክ ማጠቃለያ ሪፖርት\nINVOICE HISTORY REPORT',
                                  textAlign: pw.TextAlign.right,
                                  style: pw.TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: white,
                                  ),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: pw.BoxDecoration(
                                    color: const PdfColor.fromInt(0xFFFAA61A),
                                    borderRadius: pw.BorderRadius.circular(3),
                                  ),
                                  child: pw.Text(
                                    'Report: History Summary',
                                    style: pw.TextStyle(
                                      fontSize: 7,
                                      color: PdfColors.black,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              // Metadata row
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: accentBg,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: divider, width: 0.5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Date Range / የጊዜ ገደብ', style: styleSmall),
                        pw.Text(dateRangeText, style: styleBold),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Generated / የተዘጋጀበት', style: styleSmall),
                        pw.Text(
                          _dateFmt.format(DateTime.now()),
                          style: styleBold,
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Total Invoices / ጠቅላላ', style: styleSmall),
                        pw.Text('$totalCount', style: styleBold),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Active / Cancelled', style: styleSmall),
                        pw.Text(
                          '$activeCount / $cancelledCount',
                          style: styleBold,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
            ],
          );
        },
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: divider, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Deresegn Electronic Invoicing System  |  Confidential',
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    color: PdfColor.fromInt(0xFF666666),
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    color: PdfColor.fromInt(0xFF666666),
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) => [
          // Stat summary cards
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF9FBFF),
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: divider, width: 0.5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Total Invoices',
                  '$totalCount',
                  styleSmall,
                  styleBold,
                ),
                pw.Container(width: 0.5, height: 24, color: divider),
                _buildStatItem('Active', '$activeCount', styleSmall, styleBold),
                pw.Container(width: 0.5, height: 24, color: divider),
                _buildStatItem(
                  'Cancelled',
                  '$cancelledCount',
                  styleSmall,
                  styleBold,
                ),
                pw.Container(width: 0.5, height: 24, color: divider),
                _buildStatItem(
                  'Total Tax',
                  '${_numFmt.format(totalTaxSum)} ETB',
                  styleSmall,
                  styleBold,
                ),
                pw.Container(width: 0.5, height: 24, color: divider),
                _buildStatItem(
                  'Grand Total',
                  '${_numFmt.format(grandTotalSum)} ETB',
                  styleSmall,
                  styleBold.copyWith(color: PdfColor.fromInt(0xFF0D253A)),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          // Invoices Table
          _buildInvoicesTable(
            invoices,
            styleSmall,
            styleBody,
            tableHead,
            white,
            divider,
            bodyText,
          ),
          pw.SizedBox(height: 8),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildStatItem(
    String label,
    String value,
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle,
  ) {
    return pw.Column(
      children: [
        pw.Text(label, style: labelStyle),
        pw.SizedBox(height: 2),
        pw.Text(value, style: valueStyle),
      ],
    );
  }

  static pw.Widget _buildInvoicesTable(
    List<InvoiceSummary> invoices,
    pw.TextStyle styleSmall,
    pw.TextStyle styleBody,
    PdfColor tableHead,
    PdfColor white,
    PdfColor divider,
    PdfColor bodyText,
  ) {
    const headers = [
      '#',
      'Date / ቀን',
      'Doc Number',
      'IRN (Full / ሙሉ ቁጥር)',
      'Buyer / ገዢ',
      'TIN',
      'Status',
      'Tax (ETB)',
      'Total (ETB)',
    ];

    final colWidths = [
      const pw.FixedColumnWidth(16),
      const pw.FixedColumnWidth(58),
      const pw.FixedColumnWidth(60),
      const pw.FlexColumnWidth(3.0),
      const pw.FlexColumnWidth(2.2),
      const pw.FixedColumnWidth(50),
      const pw.FixedColumnWidth(36),
      const pw.FixedColumnWidth(52),
      const pw.FixedColumnWidth(58),
    ];

    final headerCells = headers
        .map(
          (h) => pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            color: tableHead,
            child: pw.Text(
              h,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
                color: white,
              ),
            ),
          ),
        )
        .toList();

    final dataRows = invoices.asMap().entries.map((entry) {
      final i = entry.key;
      final inv = entry.value;
      final bg = i.isOdd ? PdfColor.fromInt(0xFFF9FBFF) : PdfColors.white;

      String dateStr = inv.createdAt ?? '';
      try {
        if (dateStr.isNotEmpty) {
          dateStr = DateFormat(
            'MM/dd/yy HH:mm',
          ).format(DateTime.parse(dateStr).toLocal());
        }
      } catch (_) {}

      final docNum = inv.documentNumber ?? 'N/A';
      final fullIrn = inv.irn ?? 'N/A';
      final buyerName = inv.buyer.legalName ?? 'Walk-in Customer';
      final buyerTin = inv.buyer.tin ?? 'N/A';
      final statusStr = inv.status == 'A'
          ? 'Active'
          : (inv.status == 'C' ? 'Cancelled' : (inv.status ?? ''));
      final taxVal = _numFmt.format(
        double.tryParse(inv.totals.taxValue ?? '0') ?? 0,
      );
      final totalVal = _numFmt.format(
        double.tryParse(inv.totals.totalValue ?? '0') ?? 0,
      );

      pw.Widget cell(
        String v, {
        pw.TextAlign align = pw.TextAlign.left,
        bool isStatus = false,
        double fontSize = 6.5,
      }) {
        PdfColor textColor = bodyText;
        if (isStatus) {
          textColor = inv.status == 'A'
              ? PdfColor.fromInt(0xFF007A33)
              : PdfColor.fromInt(0xFFD32F2F);
        }
        return pw.Container(
          alignment: align == pw.TextAlign.right
              ? pw.Alignment.centerRight
              : (align == pw.TextAlign.center
                    ? pw.Alignment.center
                    : pw.Alignment.centerLeft),
          color: bg,
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2.5),
          child: pw.Text(
            v,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isStatus ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: textColor,
            ),
          ),
        );
      }

      return pw.TableRow(
        children: [
          cell('${i + 1}', align: pw.TextAlign.center),
          cell(dateStr),
          cell(docNum),
          cell(fullIrn, fontSize: 5.5),
          cell(buyerName),
          cell(buyerTin),
          cell(statusStr, align: pw.TextAlign.center, isStatus: true),
          cell(taxVal, align: pw.TextAlign.right),
          cell(totalVal, align: pw.TextAlign.right),
        ],
      );
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: divider, width: 0.4),
      columnWidths: Map.fromEntries(
        colWidths.asMap().entries.map((e) => MapEntry(e.key, e.value)),
      ),
      children: [
        pw.TableRow(children: headerCells),
        ...dataRows,
      ],
    );
  }

  /// Open Preview Screen for History Report using Get.showOverlay
  static Future<void> previewHistoryReport(
    List<InvoiceSummary> invoices, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final pdfBytes = await Get.showOverlay<Uint8List>(
        asyncFunction: () => generateHistoryReportPdf(
          invoices,
          startDate: startDate,
          endDate: endDate,
        ),
        loadingWidget: Center(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'exporting'.tr,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      Get.to(
        () => PdfPreviewScreen(
          pdfBytes: pdfBytes,
          title: 'Invoice History Report',
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        '${'export_failed'.tr}: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
