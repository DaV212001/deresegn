import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/invoice_history_model.dart';

class InvoicePdfService {
  static final _numFmt = NumberFormat('#,##0.00');

  static String _n(dynamic v, [String fallback = 'N/A']) =>
      (v == null || v.toString().isEmpty) ? fallback : v.toString();

  static String _fmt(dynamic v) {
    final d = double.tryParse(v?.toString() ?? '');
    return d != null ? _numFmt.format(d) : _n(v, '0.00');
  }

  static String _amountInWords(double amount) {
    if (amount <= 0) return 'Zero Birr';
    final int birr = amount.floor();
    final int cents = ((amount - birr) * 100).round();

    const ones = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight',
      'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
      'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen',
    ];
    const tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty',
      'Sixty', 'Seventy', 'Eighty', 'Ninety',
    ];

    String threeDigits(int n) {
      if (n == 0) return '';
      if (n < 20) return ones[n];
      if (n < 100) {
        return '${tens[n ~/ 10]}${n % 10 != 0 ? ' ${ones[n % 10]}' : ''}';
      }
      return '${ones[n ~/ 100]} Hundred${n % 100 != 0 ? ' ${threeDigits(n % 100)}' : ''}';
    }

    String convert(int n) {
      if (n == 0) return 'Zero';
      String result = '';
      if (n >= 1000000) {
        result += '${threeDigits(n ~/ 1000000)} Million ';
        n %= 1000000;
      }
      if (n >= 1000) {
        result += '${threeDigits(n ~/ 1000)} Thousand ';
        n %= 1000;
      }
      if (n > 0) result += threeDigits(n);
      return result.trim();
    }

    String words = '${convert(birr)} Birr';
    if (cents > 0) words += ' and ${convert(cents)} Cents';
    return words;
  }

  static Future<Uint8List> generate(InvoiceSummary invoice) async {
    // ── Load Ethiopic font from bundled assets ────────────────────
    pw.Font? ethiopicRegular;
    try {
      final regData = await rootBundle.load(
          'assets/fonts/NotoSansEthiopic-Regular.ttf');
      ethiopicRegular = pw.Font.ttf(regData);
    } catch (e) {
      debugPrint('Ethiopic font load error: $e');
    }

    final List<pw.Font> fontFallback = [
      if (ethiopicRegular != null) ethiopicRegular,
    ];

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        fontFallback: fontFallback,
      ),
    );
    final payload = invoice.requestPayload ?? {};

    // ── Extract data ──────────────────────────────────────────────
    final seller = (payload['SellerDetails'] as Map<String, dynamic>?) ?? {};
    final buyer  = (payload['BuyerDetails']  as Map<String, dynamic>?) ?? {};
    final docDet = (payload['DocumentDetails'] as Map<String, dynamic>?) ?? {};
    final valDet = (payload['ValueDetails']    as Map<String, dynamic>?) ?? {};
    final payDet = (payload['PaymentDetails']  as Map<String, dynamic>?) ?? {};
    final srcSys = (payload['SourceSystem']    as Map<String, dynamic>?) ?? {};
    final items  = (payload['ItemList'] as List<dynamic>?) ?? [];

    final docNumber  = _n(docDet['DocumentNumber'] ?? invoice.documentNumber);
    final docDate    = _n(docDet['Date'] ?? invoice.createdAt);
    final txType     = _n(payload['TransactionType'] ?? invoice.transactionType, 'B2C');
    final irn        = _n(invoice.irn);
    final sysNumber  = _n(srcSys['SystemNumber']);
    final cashier    = _n(srcSys['CashierName']);
    final payMode    = _n(payDet['Mode']);

    final totalValue    = _fmt(valDet['TotalValue']    ?? invoice.totals.totalValue);
    final taxValue      = _fmt(valDet['TaxValue']      ?? invoice.totals.taxValue);
    final discountValue = _fmt(valDet['Discount']      ?? invoice.totals.discount ?? '0.00');
    final exciseValue   = _fmt(valDet['ExciseValue']   ?? invoice.totals.exciseValue ?? '0.00');
    final incomeWithholdValue = valDet['IncomeWithholdValue'] ?? '0.00';
    final txnWithholdValue = valDet['TransactionWithholdValue'] ?? '0.00';
    final grandTotal    = double.tryParse(
        (valDet['TotalValue'] ?? invoice.totals.totalValue ?? '0').toString()) ?? 0.0;

    // ── QR image ─────────────────────────────────────────────────
    pw.MemoryImage? qrImage;
    try {
      if (invoice.signedQr != null && invoice.signedQr!.isNotEmpty) {
        qrImage = pw.MemoryImage(base64Decode(invoice.signedQr!));
      }
    } catch (e) {
      debugPrint('QR decode error: $e');
    }

    // ── Colors & styles ───────────────────────────────────────────
    const headerBg   = PdfColor.fromInt(0xFF1A3A5C);
    const accentBg   = PdfColor.fromInt(0xFFE8F0F8);
    const irnBg      = PdfColor.fromInt(0xFFF5F5F5);
    const tableHead  = PdfColor.fromInt(0xFF2C5282);
    const divider    = PdfColor.fromInt(0xFFCCCCCC);
    const bodyText   = PdfColor.fromInt(0xFF222222);
    const white      = PdfColors.white;

    final styleBody  = pw.TextStyle(fontSize: 8, color: bodyText);
    final styleBold  = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: bodyText);
    final styleSmall = pw.TextStyle(fontSize: 7, color: bodyText);
    final styleWhite = pw.TextStyle(fontSize: 8, color: white, fontWeight: pw.FontWeight.bold);

    // ── Helpers ───────────────────────────────────────────────────
    pw.Widget kv(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 90,
                child: pw.Text(label, style: styleSmall),
              ),
              pw.Text(': ', style: styleSmall),
              pw.Expanded(child: pw.Text(value, style: styleBold)),
            ],
          ),
        );

    pw.Widget summaryRow(String label, String value, {bool bold = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: bold ? styleBold : styleBody),
              pw.Text(value,
                  style: bold
                      ? pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: bodyText)
                      : styleBody),
            ],
          ),
        );

    // ── Build page ────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => _buildHeader(
          seller: seller,
          txType: txType,
          docNumber: docNumber,
          docDate: docDate,
          irn: irn,
          sysNumber: sysNumber,
          styleWhite: styleWhite,
          styleBody: styleBody,
          styleBold: styleBold,
          styleSmall: styleSmall,
          headerBg: headerBg,
          accentBg: accentBg,
          irnBg: irnBg,
          divider: divider,
          white: white,
          bodyText: bodyText,
        ),
        footer: (ctx) => _buildFooter(ctx, seller, cashier, styleSmall),
        build: (ctx) => [
          pw.SizedBox(height: 8),

          // ── Party Grid ───────────────────────────────────────────
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
                    padding: const pw.EdgeInsets.all(10),
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
                        pw.Text('FROM: / ከ:',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromInt(0xFF1A3A5C))),
                        pw.Text(
                            _n(seller['LegalName'] ?? seller['TradeName'], 'Seller'),
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: bodyText)),
                        pw.SizedBox(height: 4),
                        kv('ከተማ / City',
                            _n(seller['City'])),
                        kv('ቀበሌ / Kebele',
                            _n(seller['Kebele'])),
                        kv('ዞን/ክፍለ ከተማ / Zone',
                            _n(seller['Zone'] ?? seller['Wereda'])),
                        kv('የተ.ኢ.ታ ቁጥር / VAT Reg.No',
                            _n(seller['VatNumber'])),
                        kv('የማብር መለያ ቁጥር / TIN',
                            _n(seller['Tin'])),
                        kv('ስ.ቁ / Phone',
                            _n(seller['Phone'])),
                        kv('ኢሜይል / Email',
                            _n(seller['Email'])),
                      ],
                    ),
                  ),
                ),
                pw.Container(width: 0.5, color: divider),
                // TO
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TO: / ወደ:',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromInt(0xFF1A3A5C))),
                        pw.Text(
                            _n(buyer['LegalName'] ?? invoice.buyer.legalName,
                                'Customer'),
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: bodyText)),
                        pw.SizedBox(height: 4),
                        kv('ከተማ / City',
                            _n(buyer['City'] ?? invoice.buyer.city)),
                        kv('ቀበሌ / Kebele',
                            _n(buyer['Kebele'])),
                        kv('ዞን/ክፍለ ከተማ / Zone',
                            _n(buyer['Zone'] ?? buyer['Wereda'])),
                        kv('የተ.ኢ.ታ ቁጥር / VAT Reg.No',
                            _n(buyer['VatNumber'])),
                        kv('የማብር መለያ ቁጥር / TIN',
                            _n(buyer['Tin'] ?? invoice.buyer.tin)),
                        kv('ስ.ቁ / Phone',
                            _n(buyer['Phone'] ?? invoice.buyer.phone)),
                        kv('ኢሜይል / Email',
                            _n(buyer['Email'] ?? invoice.buyer.email)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 10),

          // ── Line Items Table ──────────────────────────────────────
          _buildItemsTable(items, styleSmall, styleBody, tableHead, white, divider, bodyText),

          pw.SizedBox(height: 10),

          // ── Financial Summary ─────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left: payment
              pw.Expanded(
                flex: 3,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: accentBg,
                    border: pw.Border.all(color: divider, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('የክፍያ ሁኔታ / Payment Info',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromInt(0xFF1A3A5C))),
                      pw.SizedBox(height: 6),
                      kv('Mode of Payment / የክፍያ ሁኔታ', payMode),
                      kv('Cashier / ገንዘብ ተቀባይ', cashier),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              // Right: totals
              pw.Expanded(
                flex: 4,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: divider, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    children: [
                      summaryRow('ድምር / Total ETB', '$totalValue ETB'),
                      summaryRow('ኤክሳይዝ / Excise Tax', '$exciseValue ETB'),
                      summaryRow('የቅናሽ መጠን / Discount', '$discountValue ETB'),
                      summaryRow(
                          'ተ.ኢ.ታ / VAT 15%', '$taxValue ETB'),
                      if (double.tryParse(incomeWithholdValue.toString()) != null && double.parse(incomeWithholdValue.toString()) > 0)
                        summaryRow('የገቢ ግብር ቅናሽ / Income Withhold', '${_fmt(incomeWithholdValue)} ETB'),
                      if (double.tryParse(txnWithholdValue.toString()) != null && double.parse(txnWithholdValue.toString()) > 0)
                        summaryRow('የግብይት ግብር ቅናሽ / Txn Withhold', '${_fmt(txnWithholdValue)} ETB'),
                      pw.Divider(color: divider, thickness: 0.5),
                      summaryRow(
                        'ጠቅላላ ዋጋ ከታክስ ጋር / Grand Total',
                        '${_numFmt.format(grandTotal)} ETB',
                        bold: true,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          color: irnBg,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          'ጠቅላላ ዋጋ ከታክስ ጋር (በፈደል):\n${_amountInWords(grandTotal)}',
                          style: pw.TextStyle(
                              fontSize: 7,
                              fontStyle: pw.FontStyle.italic,
                              color: bodyText),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 12),

          // ── QR & IRN Footer ───────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: irnBg,
              border: pw.Border.all(color: divider, width: 0.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (qrImage != null) ...[
                  pw.Image(qrImage, width: 90, height: 90),
                  pw.SizedBox(width: 12),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'This is an electronically generated fiscal invoice.',
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(0xFF1A3A5C)),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('IRN: $irn',
                          style: pw.TextStyle(
                              fontSize: 6.5,
                              color: bodyText)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Powered by ${_n(seller['LegalName'] ?? seller['TradeName'], 'Micro Sun & Solution PLC')}',
                        style: pw.TextStyle(
                            fontSize: 7,
                            fontStyle: pw.FontStyle.italic,
                            color: PdfColor.fromInt(0xFF666666)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Page Header widget ──────────────────────────────────────────
  static pw.Widget _buildHeader({
    required Map<String, dynamic> seller,
    required String txType,
    required String docNumber,
    required String docDate,
    required String irn,
    required String sysNumber,
    required pw.TextStyle styleWhite,
    required pw.TextStyle styleBody,
    required pw.TextStyle styleBold,
    required pw.TextStyle styleSmall,
    required PdfColor headerBg,
    required PdfColor accentBg,
    required PdfColor irnBg,
    required PdfColor divider,
    required PdfColor white,
    required PdfColor bodyText,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Top banner
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: headerBg,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Company info
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_n(seller['LegalName'] ?? seller['TradeName'], 'Micro Sun & Solution PLC'),
                        style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: white)),
                    pw.SizedBox(height: 3),
                    pw.Text(
                        '${_n(seller['City'], 'Addis Ababa')} ${_n(seller['Wereda'], '')}'.trim(),
                        style: pw.TextStyle(fontSize: 7, color: white)),
                    pw.Text(
                        'Tel: ${_n(seller['Phone'], '+251947990585')}  |  Email: ${_n(seller['Email'], 'amanuielt@mssmea.com')}',
                        style: pw.TextStyle(fontSize: 7, color: white)),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              // Doc title
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'እጅ በጅ የሽያጭ ደረሰኝ\nCASH SALES VAT/EXCISE TAX Invoice',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: white),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFF2A6DB5),
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.Text('Sale Type: $txType',
                          style: pw.TextStyle(fontSize: 8, color: white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Metadata bar
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          color: accentBg,
          child: pw.Row(
            children: [
              _metaCell('Doc. No. / ቁጥር', docNumber, styleBold, styleSmall),
              pw.SizedBox(width: 16),
              _metaCell('ቀን / Date', docDate, styleBold, styleSmall),
              pw.SizedBox(width: 16),
              _metaCell('System No.', sysNumber, styleBold, styleSmall),
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: irnBg,
                  borderRadius: pw.BorderRadius.circular(3),
                  border: pw.Border.all(color: divider, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('IRN:',
                        style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold,
                            color: bodyText)),
                    pw.Text(irn,
                        style: pw.TextStyle(fontSize: 6, color: bodyText)),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 4),
      ],
    );
  }

  static pw.Widget _metaCell(
      String label, String value, pw.TextStyle bold, pw.TextStyle small) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: small),
        pw.Text(value, style: bold),
      ],
    );
  }

  // ── Items Table ─────────────────────────────────────────────────
  static pw.Widget _buildItemsTable(
    List<dynamic> items,
    pw.TextStyle styleSmall,
    pw.TextStyle styleBody,
    PdfColor tableHead,
    PdfColor white,
    PdfColor divider,
    PdfColor bodyText,
  ) {
    const headers = [
      'ቁ.\nNo.',
      'የዕቃው አይነት\nDescription',
      'ምድብ\nNature',
      'መለኪያ\nUoM',
      'ብዛት\nQty',
      'የአንዱ ዋጋ\nUnit Price',
      'ታክስ ኮድ\nTax Code',
      'ኤክሳይዝ\nExcise',
      'ቅናሽ\nDiscount',
      'ጠቅላላ ዋጋ\nTotal Amount',
    ];

    final colWidths = [
      pw.FixedColumnWidth(22),
      pw.FlexColumnWidth(3),
      pw.FixedColumnWidth(38),
      pw.FixedColumnWidth(28),
      pw.FixedColumnWidth(30),
      pw.FixedColumnWidth(48),
      pw.FixedColumnWidth(38),
      pw.FixedColumnWidth(38),
      pw.FixedColumnWidth(38),
      pw.FixedColumnWidth(50),
    ];

    final headerCells = headers
        .map(
          (h) => pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
            color: tableHead,
            child: pw.Text(
              h,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  fontSize: 6.5,
                  fontWeight: pw.FontWeight.bold,
                  color: white),
            ),
          ),
        )
        .toList();

    final dataRows = items.asMap().entries.map((entry) {
      final i = entry.key;
      final item = entry.value as Map<String, dynamic>;
      final bg = i.isOdd
          ? PdfColor.fromInt(0xFFF9FBFF)
          : PdfColors.white;

      pw.Widget cell(String v,
              {pw.TextAlign align = pw.TextAlign.left}) =>
          pw.Container(
            alignment: align == pw.TextAlign.right
                ? pw.Alignment.centerRight
                : pw.Alignment.centerLeft,
            color: bg,
            padding:
                const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
            child: pw.Text(v,
                style: pw.TextStyle(fontSize: 7, color: bodyText)),
          );

      return pw.TableRow(children: [
        cell('${i + 1}', align: pw.TextAlign.right),
        cell(_n(item['ProductDescription'])),
        cell(_n(item['NatureOfSupplies'])),
        cell(_n(item['Unit'])),
        cell(_n(item['Quantity']), align: pw.TextAlign.right),
        cell(_n(item['UnitPrice']), align: pw.TextAlign.right),
        cell(_n(item['TaxCode'])),
        cell(_n(item['ExciseTaxValue'], '0.00'), align: pw.TextAlign.right),
        cell(_n(item['Discount'], '0.00'), align: pw.TextAlign.right),
        cell(_n(item['TotalLineAmount']), align: pw.TextAlign.right),
      ]);
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: divider, width: 0.4),
      columnWidths: Map.fromEntries(
          colWidths.asMap().entries.map((e) => MapEntry(e.key, e.value))),
      children: [
        pw.TableRow(children: headerCells),
        ...dataRows,
      ],
    );
  }

  // ── Page Footer ─────────────────────────────────────────────────
  static pw.Widget _buildFooter(
      pw.Context ctx, Map<String, dynamic> seller, String cashier, pw.TextStyle styleSmall) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            top: pw.BorderSide(color: PdfColor.fromInt(0xFFCCCCCC), width: 0.5)),
      ),
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Powered by ${_n(seller['LegalName'] ?? seller['TradeName'], 'Micro Sun & Solution PLC')}  |  '
            'Invoice Printed: ${DateFormat('MMM dd yyyy HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 6.5, color: PdfColor.fromInt(0xFF666666)),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style:
                pw.TextStyle(fontSize: 6.5, color: PdfColor.fromInt(0xFF666666)),
          ),
        ],
      ),
    );
  }
}
