import 'dart:convert';
import 'package:flutter/material.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/invoice_history_model.dart';
import '../models/receipt_models.dart';
import 'invoice_pdf_service.dart';

class ReceiptPdfService {
  static final _numFmt = NumberFormat('#,##0.00');

  static String _n(dynamic v, [String fallback = 'N/A']) =>
      (v == null || v.toString().isEmpty) ? fallback : v.toString();

  static String _fmt(dynamic v) {
    final d = double.tryParse(v?.toString() ?? '');
    return d != null ? _numFmt.format(d) : _n(v, '0.00');
  }

  static Future<Uint8List> generate(
    ReceiptSummary receipt,
    InvoiceSummary invoice, {
    bool isWithholding = false,
  }) async {
    final pdfTheme = await InvoicePdfService.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);

    await generateIntoDocument(pdf, receipt, invoice, isWithholding: isWithholding);
    return pdf.save();
  }

  static Future<void> generateIntoDocument(
    pw.Document pdf,
    ReceiptSummary receipt,
    InvoiceSummary invoice, {
    bool isWithholding = false,
  }) async {
    final rPayload = receipt.requestPayload ?? {};

    final checkWithholding = isWithholding ||
        rPayload.containsKey('WithholdDetail') ||
        rPayload['Reason']?.toString().toLowerCase().contains('withholding') == true ||
        rPayload['ReceiptType']?.toString().toUpperCase() == 'TWTH';

    if (checkWithholding) {
      await _generateWithholdingReceipt(pdf, receipt, invoice);
    } else {
      await _generateCashReceiptVoucher(pdf, receipt, invoice);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 1. CASH RECEIPT VOUCHER (CRB)
  // ─────────────────────────────────────────────────────────────
  static Future<void> _generateCashReceiptVoucher(
    pw.Document pdf,
    ReceiptSummary receipt,
    InvoiceSummary invoice,
  ) async {
    final rPayload = receipt.requestPayload ?? {};
    final iPayload = invoice.requestPayload ?? {};

    final seller = (iPayload['SellerDetails'] as Map<String, dynamic>?) ?? {};
    final buyer = (iPayload['BuyerDetails'] as Map<String, dynamic>?) ?? {};
    final sysSys = (rPayload['SourceSystemType'] != null)
        ? rPayload
        : iPayload['SourceSystem'] ?? {};

    final receiptNumber = _n(
      rPayload['ReceiptNumber'] ?? receipt.receiptNumber ?? receipt.id?.toString(),
      'CRV-${DateTime.now().millisecondsSinceEpoch}',
    );
    final rrn = _n(rPayload['RRN'] ?? receipt.rrn, 'RRN-${DateTime.now().millisecondsSinceEpoch}');
    final receiptDate = _n(rPayload['ReceiptDate'] ?? receipt.createdAt, DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now()));
    final txType = _n(iPayload['TransactionType'] ?? invoice.transactionType, 'B2C');
    final sysNumber = _n(sysSys['SystemNumber'] ?? sysSys['SourceSystemNumber'], 'TERM-01-POS');
    final reason = _n(rPayload['Reason'], 'Payment for goods purchased');

    final txnDetails = (rPayload['TransactionDetails'] as Map<String, dynamic>?) ?? {};
    final payMode = _n(txnDetails['ModeOfPayment'] ?? iPayload['PaymentDetails']?['Mode'], 'CASH');

    final collectedAmount = double.tryParse(rPayload['CollectedAmount']?.toString() ?? '') ??
        double.tryParse(invoice.totals.totalValue ?? '0') ??
        0.0;

    // Load Letterhead
    pw.MemoryImage? letterheadImage;
    try {
      final imgBytes = await rootBundle.load('assets/deresegn_letterhead.png');
      letterheadImage = pw.MemoryImage(imgBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Letterhead load error: $e');
    }

    // QR image
    pw.MemoryImage? qrImage;
    try {
      final qrToUse = receipt.qr ?? invoice.signedQr;
      if (qrToUse != null && qrToUse.isNotEmpty) {
        qrImage = pw.MemoryImage(base64Decode(qrToUse));
      }
    } catch (e) {
      debugPrint('QR decode error: $e');
    }

    const headerBg = PdfColor.fromInt(0xFF0D253A);
    const accentBg = PdfColor.fromInt(0xFFE8F0F8);
    const divider = PdfColor.fromInt(0xFFCCCCCC);
    const bodyText = PdfColor.fromInt(0xFF222222);
    const white = PdfColors.white;

    final styleBody = pw.TextStyle(fontSize: 8, color: bodyText);
    final styleBold = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: bodyText);
    final styleSmall = pw.TextStyle(fontSize: 7, color: bodyText);

    // Invoices list
    final List<dynamic> rawInvoices = (rPayload['Invoices'] as List<dynamic>?) ?? [];
    final List<Map<String, dynamic>> invoicesList = rawInvoices.isNotEmpty
        ? rawInvoices.map((e) => e as Map<String, dynamic>).toList()
        : [
            {
              'InvoiceIRN': receipt.invoiceIrn ?? invoice.irn ?? 'IRN-PENDING',
              'PaymentCoverage': (rPayload['PaymentCoverage'] ?? 'FULL'),
              'TotalAmount': invoice.totals.totalValue ?? collectedAmount.toStringAsFixed(2),
              'RemainingAmount': '0.00',
              'InvoicePaidAmount': collectedAmount.toStringAsFixed(2),
            }
          ];

    double totalPaid = 0.0;
    for (final inv in invoicesList) {
      final p = double.tryParse((inv['InvoicePaidAmount'] ?? inv['PaidAmount'] ?? collectedAmount).toString()) ?? collectedAmount;
      totalPaid += p;
    }

    pw.Widget kvParty(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 85, child: pw.Text(label, style: styleSmall)),
              pw.Text(': ', style: styleSmall),
              pw.Expanded(child: pw.Text(value, style: styleBold)),
            ],
          ),
        );

    pdf.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(26, 46, 26, 40),
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
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Top Banner ──────────────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(width: 90, height: 70),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: headerBg,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                _n(seller['LegalName'] ?? seller['TradeName'], 'Micro Sun & Solution PLC'),
                                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: white),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                '${_n(seller['City'], 'Addis Ababa')} ${_n(seller['Wereda'], '')}'.trim(),
                                style: pw.TextStyle(fontSize: 7, color: white),
                              ),
                              pw.Text(
                                'Tel: ${_n(seller['Phone'], '+251 91 105 8179')}  |  Email: ${_n(seller['Email'], 'contact@deresegn.com')}',
                                style: pw.TextStyle(fontSize: 7, color: white),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'ገንዘብ መቀበያ ደረሰኝ\nCash Receipt Voucher',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: white),
                              ),
                              pw.SizedBox(height: 3),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: pw.BoxDecoration(
                                  color: const PdfColor.fromInt(0xFFFAA61A),
                                  borderRadius: pw.BorderRadius.circular(3),
                                ),
                                child: pw.Text(
                                  'የሽያጭ አይነት ($txType)',
                                  style: pw.TextStyle(fontSize: 7, color: PdfColors.black, fontWeight: pw.FontWeight.bold),
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
            pw.SizedBox(height: 8),

            // ── Metadata Bar & QR ──────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: accentBg,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: divider, width: 0.5),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text('RRN: ', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                            pw.Expanded(
                              child: pw.Text(rrn, style: pw.TextStyle(fontSize: 7, color: bodyText)),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                        pw.Row(
                          children: [
                            pw.Text('System Number: ', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                            pw.Text(sysNumber, style: pw.TextStyle(fontSize: 7, color: bodyText)),
                            pw.SizedBox(width: 14),
                            pw.Text('Receipt #: ', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                            pw.Text(receiptNumber, style: pw.TextStyle(fontSize: 7, color: bodyText)),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                        pw.Row(
                          children: [
                            pw.Text('Date / ቀን: ', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                            pw.Text(receiptDate, style: pw.TextStyle(fontSize: 7, color: bodyText)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (qrImage != null) ...[
                    pw.SizedBox(width: 10),
                    pw.Image(qrImage, width: 55, height: 55),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            // ── Party Grid (From / To) ─────────────────────────────
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: divider, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // FROM
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: const pw.BoxDecoration(
                        color: accentBg,
                        borderRadius: pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(4),
                          bottomLeft: pw.Radius.circular(4),
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('ከ / From (Seller):', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: headerBg)),
                          pw.Text(_n(seller['LegalName'] ?? seller['TradeName'], 'Micro Sun & Solution PLC'), style: styleBold),
                          pw.SizedBox(height: 3),
                          kvParty('ከተማ / City', _n(seller['City'], 'Addis Ababa')),
                          kvParty('ዞን / Zone', _n(seller['Zone'] ?? seller['Wereda'], 'Kirkos')),
                          kvParty('ቀበሌ / Kebele', _n(seller['Kebele'])),
                          kvParty('የተ.እ.ታ ቁጥር / VAT No', _n(seller['VatNumber'] ?? seller['Vrn'])),
                          kvParty('TIN ቁጥር', _n(seller['Tin'])),
                        ],
                      ),
                    ),
                  ),
                  pw.Container(width: 0.5, color: divider),
                  // TO
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('ለ / To (Customer):', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: headerBg)),
                          pw.Text(_n(buyer['LegalName'] ?? invoice.buyer.legalName, 'Walk-in Retail Customer'), style: styleBold),
                          pw.SizedBox(height: 3),
                          kvParty('ከተማ / City', _n(buyer['City'] ?? invoice.buyer.city)),
                          kvParty('ዞን / Zone', _n(buyer['Zone'] ?? buyer['Wereda'])),
                          kvParty('ቀበሌ / Kebele', _n(buyer['Kebele'])),
                          kvParty('የተ.እ.ታ ቁጥር / VAT No', _n(buyer['VatNumber'] ?? buyer['Vrn'])),
                          kvParty('TIN ቁጥር', _n(buyer['Tin'] ?? invoice.buyer.tin)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            // ── Payment Reason Box ────────────────────────────────
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: divider, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Payment Reason / የክፍያ ምክንያት: ', style: styleSmall),
                      pw.Text(reason, style: styleBold),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Mode of Payment / የክፍያ ሁኔታ: ', style: styleSmall),
                      pw.Text(payMode, style: styleBold),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Collected Amount / የተሰበሰበው መጠን: ', style: styleSmall),
                      pw.Text('${_fmt(collectedAmount)} ETB', style: styleBold),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // ── Invoices Table ─────────────────────────────────────
            pw.Text('Invoices / ደረሰኞች:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: headerBg)),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: divider, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3.5),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: headerBg),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('IRN', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: white), textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Payment Coverage', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: white), textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Total Amount', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: white), textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Remaining Amount', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: white), textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Paid Amount', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: white), textAlign: pw.TextAlign.center),
                    ),
                  ],
                ),
                ...invoicesList.map((inv) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_n(inv['InvoiceIRN'] ?? inv['IRN']), style: pw.TextStyle(fontSize: 6.5, color: bodyText)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_n(inv['PaymentCoverage'], 'FULL'), style: styleSmall, textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_fmt(inv['TotalAmount']), style: styleSmall, textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_fmt(inv['RemainingAmount'] ?? '0.00'), style: styleSmall, textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_fmt(inv['InvoicePaidAmount'] ?? inv['PaidAmount'] ?? collectedAmount), style: styleSmall, textAlign: pw.TextAlign.right),
                      ),
                    ],
                  );
                }).toList(),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: accentBg),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('ጠቅላላ የተከፈለ መጠን / Total Paid:', style: styleBold),
                    ),
                    pw.SizedBox(),
                    pw.SizedBox(),
                    pw.SizedBox(),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('${_fmt(totalPaid)} ETB', style: styleBold, textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // ── Totals Box ─────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: divider, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Invoices: ${invoicesList.length}', style: styleBold),
                      pw.SizedBox(height: 2),
                      pw.Text('Total Collected: ${_fmt(collectedAmount)} ETB', style: styleBody),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Receipt Amount / የደረሰኝ መጠን:', style: styleSmall),
                      pw.SizedBox(height: 2),
                      pw.Text('${_fmt(collectedAmount)} ETB', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: headerBg)),
                    ],
                  ),
                ],
              ),
            ),

            pw.Spacer(),

            // ── Footer ─────────────────────────────────────────────
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: divider, width: 0.5)),
              ),
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generated by Deresegn eBridge System  |  ${_n(seller['LegalName'] ?? seller['TradeName'])}', style: styleSmall),
                  pw.Text('Printed: ${DateFormat('MMM dd yyyy HH:mm').format(DateTime.now())}  |  Page 1 of 1', style: styleSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. WITHHOLDING TAX RECEIPT
  // ─────────────────────────────────────────────────────────────
  static Future<void> _generateWithholdingReceipt(
    pw.Document pdf,
    ReceiptSummary receipt,
    InvoiceSummary invoice,
  ) async {
    final rPayload = receipt.requestPayload ?? {};
    final iPayload = invoice.requestPayload ?? {};

    final seller = (iPayload['SellerDetails'] as Map<String, dynamic>?) ?? {};
    final buyer = (iPayload['BuyerDetails'] as Map<String, dynamic>?) ?? {};
    final sysSys = (rPayload['SourceSystemType'] != null)
        ? rPayload
        : iPayload['SourceSystem'] ?? {};

    final receiptNumber = _n(
      rPayload['ReceiptNumber'] ?? receipt.receiptNumber,
      'WH-${DateTime.now().millisecondsSinceEpoch}',
    );
    final counter = _n(rPayload['ReceiptCounter'] ?? '1');
    final reason = _n(rPayload['Reason'] ?? 'Tax Withholding');
    final typeCode = 'TWTH';
    final receiptDate = _n(rPayload['ReceiptDate'] ?? receipt.createdAt, DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now()));

    final sysType = _n(sysSys['SystemType'] ?? rPayload['SourceSystemType'], 'POS');
    final sysNumber = _n(sysSys['SystemNumber'] ?? rPayload['SourceSystemNumber'], 'TERM-01-POS');
    final currency = _n(rPayload['ReceiptCurrency'], 'ETB');

    final wDet = (rPayload['WithholdDetail'] as Map<String, dynamic>?) ?? {};
    final wIncome = double.tryParse(wDet['IncomeWithholdValue']?.toString() ?? '') ??
        double.tryParse(wDet['WithholdingAmount']?.toString() ?? '') ??
        0.0;
    final wTxn = double.tryParse(wDet['TransactionWithholdValue']?.toString() ?? '0') ?? 0.0;
    final withheldAmount = (wIncome + wTxn > 0) ? (wIncome + wTxn) : (wIncome > 0 ? wIncome : 250.00);

    final valDet = (iPayload['ValueDetails'] as Map<String, dynamic>?) ?? {};
    final preTaxAmount = double.tryParse(wDet['PreTaxAmount']?.toString() ?? '') ??
        double.tryParse(valDet['TotalValue']?.toString() ?? '') ??
        double.tryParse(invoice.totals.totalValue ?? '0') ??
        0.0;

    // Load Letterhead
    pw.MemoryImage? letterheadImage;
    try {
      final imgBytes = await rootBundle.load('assets/deresegn_letterhead.png');
      letterheadImage = pw.MemoryImage(imgBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Letterhead load error: $e');
    }

    // QR image
    pw.MemoryImage? qrImage;
    try {
      final qrToUse = receipt.qr ?? invoice.signedQr;
      if (qrToUse != null && qrToUse.isNotEmpty) {
        qrImage = pw.MemoryImage(base64Decode(qrToUse));
      }
    } catch (e) {
      debugPrint('QR decode error: $e');
    }

    const headerBg = PdfColor.fromInt(0xFF0D253A);
    const accentBg = PdfColor.fromInt(0xFFE8F0F8);
    const divider = PdfColor.fromInt(0xFFCCCCCC);
    const bodyText = PdfColor.fromInt(0xFF222222);
    const white = PdfColors.white;

    final styleBody = pw.TextStyle(fontSize: 8, color: bodyText);
    final styleBold = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: bodyText);
    final styleSmall = pw.TextStyle(fontSize: 7, color: bodyText);

    pw.Widget buildWithholdingPartyBlock(
      String enTitle,
      String amTitle,
      Map<String, dynamic> data, {
      bool isWithholdingAgent = false,
    }) {
      final name = _n(data['LegalName'] ?? data['TradeName'] ?? data['Name']);
      final city = _n(data['City']);
      final kebele = _n(data['Kebele']);
      final zone = _n(data['Zone'] ?? data['Wereda']);
      final houseNo = _n(data['HouseNo']);
      final woreda = _n(data['Woreda'] ?? data['Wereda']);
      final vrn = _n(data['VatNumber'] ?? data['Vrn']);
      final tin = _n(data['Tin']);

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('$amTitle / $enTitle:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: headerBg)),
          pw.Text(name, style: styleBold),
          pw.SizedBox(height: 3),
          pw.Text('ከተማ City/Town: $city', style: styleSmall),
          pw.Text('ቀበሌ Kebele: $kebele   ቤት ቁጥር H/No: $houseNo', style: styleSmall),
          pw.Text('ዞን Zone: $zone   ወረዳ Woreda: $woreda', style: styleSmall),
          pw.Text(
            isWithholdingAgent
                ? 'የግብር ከፋይ ተ.እ.ታ ቁጥር Withholding Agent VAT Reg.No: $vrn'
                : 'የግብር ከፋይ ተ.እ.ታ ቁጥር Taxpayer VAT Reg.No: $vrn',
            style: styleSmall,
          ),
          pw.Text(
            isWithholdingAgent
                ? 'የግብር ከፋይ መለያ ቁጥር Withholding Agent TIN: $tin'
                : 'የግብር ከፋይ መለያ ቁጥር Taxpayer TIN: $tin',
            style: styleSmall,
          ),
        ],
      );
    }

    pdf.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(26, 46, 26, 40),
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
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Top banner
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(width: 90, height: 70),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: headerBg,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                _n(seller['LegalName'] ?? seller['TradeName'], 'Micro Sun & Solution PLC'),
                                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: white),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Address: ${_n(seller['City'], 'Addis Ababa')}',
                                style: pw.TextStyle(fontSize: 7, color: white),
                              ),
                              pw.Text(
                                'Tel: ${_n(seller['Phone'], '+251 91 105 8179')}  |  Email: ${_n(seller['Email'], 'contact@deresegn.com')}',
                                style: pw.TextStyle(fontSize: 7, color: white),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'ከተከፋይ ሒሳብ ላይ ለተቀነሰ ግብር የተሰጠ ደረሰኝ\nWithholding tax on payment',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: white),
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
            pw.SizedBox(height: 8),

            // Metadata row
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: accentBg,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: divider, width: 0.5),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Receipt #: $receiptNumber', style: styleBold),
                        pw.SizedBox(height: 2),
                        pw.Text('Counter: $counter  |  Type: $typeCode', style: styleSmall),
                        pw.SizedBox(height: 2),
                        pw.Text('Reason: $reason', style: styleSmall),
                        pw.SizedBox(height: 2),
                        pw.Text('Date / ቀን: $receiptDate', style: styleSmall),
                      ],
                    ),
                  ),
                  if (qrImage != null) ...[
                    pw.SizedBox(width: 10),
                    pw.Image(qrImage, width: 55, height: 55),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // From / To sections
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: divider, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: buildWithholdingPartyBlock('Withholding Agent', 'ከ', seller, isWithholdingAgent: true),
                  ),
                  pw.Container(width: 0.5, color: divider),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: buildWithholdingPartyBlock('Taxpayer', 'ለ', buyer, isWithholdingAgent: false),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Withholding Table
            pw.Table(
              border: pw.TableBorder.all(color: divider, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: headerBg),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('የደረሰኝ ቁጥር\nInvoice Doc. Number', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: white), textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('የገንዘብ ዓይነት\nInvoice Currency', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: white), textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('ከታክስ በፊት ያለው ዋጋ\nPre Tax Amount', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: white), textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('ተይዞ የቀረ መጠን\nWithheld Amount', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: white), textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('ጠቅላላ ዋጋ\nTotal Amount', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: white), textAlign: pw.TextAlign.center),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(_n(rPayload['InvoiceDetail']?['InvoiceDocNumber'] ?? invoice.documentNumber, receiptNumber), style: styleSmall, textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(currency, style: styleSmall, textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(_fmt(preTaxAmount), style: styleSmall, textAlign: pw.TextAlign.right),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(_fmt(withheldAmount), style: styleSmall, textAlign: pw.TextAlign.right),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(_fmt(preTaxAmount), style: styleSmall, textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: divider, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('ጠቅላላ የደረሰኝ መጠን / Total ETB:', style: styleBold),
                      pw.Text('${_fmt(preTaxAmount)} ETB', style: styleBold),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('በገዥ ተይዞ የቀረ መጠን / Withheld Amount:', style: styleBold),
                      pw.Text('${_fmt(withheldAmount)} ETB', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: headerBg)),
                    ],
                  ),
                ],
              ),
            ),

            pw.Spacer(),

            // Footer
            pw.Text('የስርዓት አይነት System Type: $sysType   |   የስርዓት ቁጥር System Number: $sysNumber', style: styleSmall),
            pw.SizedBox(height: 2),
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: divider, width: 0.5)),
              ),
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generated by Deresegn eBridge System', style: styleSmall),
                  pw.Text('Printed: ${DateFormat('MMM dd yyyy HH:mm').format(DateTime.now())}  |  Page 1 of 1', style: styleSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
