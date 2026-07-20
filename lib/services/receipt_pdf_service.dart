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
    InvoiceSummary invoice,
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

    await generateIntoDocument(pdf, receipt, invoice);
    return pdf.save();
  }

  static Future<void> generateIntoDocument(
    pw.Document pdf,
    ReceiptSummary receipt,
    InvoiceSummary invoice,
  ) async {
    final rPayload = receipt.requestPayload ?? {};
    final iPayload = invoice.requestPayload ?? {};

    // ── Extract data ──────────────────────────────────────────────
    final seller = (iPayload['SellerDetails'] as Map<String, dynamic>?) ?? {};
    final buyer = (iPayload['BuyerDetails'] as Map<String, dynamic>?) ?? {};
    final sysSys = (rPayload['SourceSystemType'] != null)
        ? rPayload
        : iPayload['SourceSystem'] ?? {};

    final isWithholding =
        rPayload.containsKey('WithholdDetail') ||
        rPayload['Reason']?.toString().toLowerCase().contains('withholding') ==
            true;

    final receiptNumber = _n(
      rPayload['ReceiptNumber'] ?? receipt.receiptNumber,
    );

    if (!isWithholding) {
      await InvoicePdfService.generateIntoDocument(
        pdf,
        invoice,
        isPaymentReceipt: true,
        overrideDocNumber: receiptNumber,
        overrideIrnTitle: 'RRN:',
        overrideIrn: _n(receipt.rrn),
        overrideQr: receipt.qr,
        overrideReferenceIrn: receipt.invoiceIrn,
      );
      return;
    }

    final counter = _n(rPayload['ReceiptCounter'] ?? receipt.receiptNumber);
    final reason = _n(rPayload['Reason'] ?? 'Payment');
    final typeCode = isWithholding
        ? 'TWTH'
        : _n(rPayload['ReceiptType'], 'Payment');
    final receiptDate = _n(rPayload['ReceiptDate'] ?? receipt.createdAt);

    final sysType = _n(
      sysSys['SystemType'] ?? rPayload['SourceSystemType'],
      'POS',
    );
    final sysNumber = _n(
      sysSys['SystemNumber'] ?? rPayload['SourceSystemNumber'],
    );

    final currency = _n(rPayload['ReceiptCurrency'], 'ETB');

    // Withholding values
    final wDet = (rPayload['WithholdDetail'] as Map<String, dynamic>?) ?? {};
    final wIncome =
        double.tryParse(wDet['IncomeWithholdValue']?.toString() ?? '0') ?? 0.0;
    final wTxn =
        double.tryParse(wDet['TransactionWithholdValue']?.toString() ?? '0') ??
        0.0;
    final withheldAmount = wIncome + wTxn;

    // Invoice totals
    final valDet = (iPayload['ValueDetails'] as Map<String, dynamic>?) ?? {};
    final preTaxAmount =
        double.tryParse(valDet['TotalValue']?.toString() ?? '0') ?? 0.0;

    // ── Colors & styles ───────────────────────────────────────────
    const bodyText = PdfColor.fromInt(0xFF000000);
    const white = PdfColors.white;

    final styleBody = pw.TextStyle(fontSize: 8, color: bodyText);
    final styleBold = pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      color: bodyText,
    );
    final styleSmall = pw.TextStyle(fontSize: 7, color: bodyText);

    // ── Address Block Widget ──────────────────────────────────────
    pw.Widget _buildPartyBlock(
      String enTitle,
      String amTitle,
      Map<String, dynamic> data, {
      bool isWithholdingAgent = false,
    }) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(amTitle, style: styleBody),
          pw.Text('$enTitle: ${_n(data['Name'])}', style: styleBold),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'ከተማ City/Town ${_n(data['City'])}',
                  style: styleSmall,
                ),
              ),
            ],
          ),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'ቀበሌ Kebele ${_n(data['Kebele'])}',
                  style: styleSmall,
                ),
              ),
            ],
          ),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'ዞን Zone/Sub city ${_n(data['Zone'])}',
                  style: styleSmall,
                ),
              ),
            ],
          ),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'ቤት ቁጥር H/No ${_n(data['HouseNo'])}',
                  style: styleSmall,
                ),
              ),
            ],
          ),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'ወረዳ Woreda ${_n(data['Woreda'])}',
                  style: styleSmall,
                ),
              ),
            ],
          ),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  isWithholdingAgent
                      ? 'የግብር ከፋይ ተ.እ.ታ ቁጥር Withholding Agent VAT Reg.No ${_n(data['Vrn'])}'
                      : 'የግብር ከፋይ ተ.እ.ታ ቁጥር Taxpayer VAT Reg.No ${_n(data['Vrn'])}',
                  style: styleSmall,
                ),
              ),
            ],
          ),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  isWithholdingAgent
                      ? 'የግብር ከፋይ መለያ ቁጥር Withholding Agent TIN ${_n(data['Tin'])}'
                      : 'የግብር ከፋይ መለያ ቁጥር Taxpayer TIN ${_n(data['Tin'])}',
                  style: styleSmall,
                ),
              ),
            ],
          ),
        ],
      );
    }

    // ── Build page ────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Company Header (Standard ERCA text format)
            pw.Text(
              _n(seller['Name'], 'WISCOM System Technology PLC'),
              style: styleBold.copyWith(fontSize: 10),
            ),
            pw.Text('Address: ${_n(seller['Address'])}', style: styleBody),
            pw.Text('Tel: ${_n(seller['PhoneNo'])}', style: styleBody),
            pw.SizedBox(height: 10),

            if (isWithholding) ...[
              pw.Text(
                'ከተከፋይ ሒሳብ ላይ ለተቀነሰ ግብር የተሰጠ ደረሰኝ',
                style: styleBold.copyWith(fontSize: 11),
              ),
              pw.Text(
                'Withholding tax on payment',
                style: styleBold.copyWith(fontSize: 10),
              ),
            ] else ...[
              pw.Text('የክፍያ ደረሰኝ', style: styleBold.copyWith(fontSize: 11)),
              pw.Text(
                'PAYMENT RECEIPT',
                style: styleBold.copyWith(fontSize: 10),
              ),
            ],

            pw.SizedBox(height: 6),
            pw.Text('Receipt #: $receiptNumber', style: styleBody),
            pw.Text('Counter: $counter', style: styleBody),
            pw.Text('Reason: $reason', style: styleBody),
            pw.Text('Type: $typeCode', style: styleBody),

            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                pw.Text('ቀን:   ', style: styleBody),
                pw.Text(
                  receiptDate,
                  style: styleBody,
                ), // Amharic date omitted for simplicity
              ],
            ),
            pw.Row(
              children: [
                pw.Text('Date: ', style: styleBody),
                pw.Text(receiptDate, style: styleBody),
              ],
            ),
            pw.SizedBox(height: 16),

            // From / To sections
            _buildPartyBlock(
              'From',
              'ከ',
              seller,
              isWithholdingAgent: isWithholding,
            ),
            pw.SizedBox(height: 12),
            _buildPartyBlock('To', 'ለ', buyer, isWithholdingAgent: false),
            pw.SizedBox(height: 16),

            if (isWithholding) ...[
              // Withholding Table
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'የደረሰኝ ቁጥር\nInvoice Doc. Number',
                          style: styleBold,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'የገንዘብ ዓይነት\nInvoice Currency',
                          style: styleBold,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'ከታክስ በፊት ያለው ዋጋ\nPre Tax Amount',
                          style: styleBold,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'ተይዞ የቀረ መጠን\nWithheld Amount',
                          style: styleBold,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'ጠቅላላ ዋጋ\nTotal Amount',
                          style: styleBold,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          receiptNumber,
                          style: styleBody,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          currency,
                          style: styleBody,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          _numFmt.format(preTaxAmount),
                          style: styleBody,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          _numFmt.format(withheldAmount),
                          style: styleBody,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          '',
                          style: styleBody,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Withholding Summary
              pw.Row(
                children: [
                  pw.Text('ጠቅላላ የደረሰኝ መጠን / Total ETB', style: styleBold),
                ],
              ),
              pw.Row(
                children: [
                  pw.Text(
                    'በገዥ ተይዞ የቀረ መጠን / Withheld Amount   ',
                    style: styleBold,
                  ),
                  pw.Text(_numFmt.format(withheldAmount), style: styleBold),
                ],
              ),
            ],

            // Standard receipt delegation now happens at the start of the method.
            pw.Spacer(),

            // Footer
            pw.Text('የስርዓት አይነት System Type $sysType', style: styleBody),
            pw.Text('የስርዓት ቁጥር System Number $sysNumber', style: styleBody),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated by Deresegn eBridge System',
              style: styleSmall.copyWith(fontStyle: pw.FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
