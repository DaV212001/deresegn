import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/invoice_history_model.dart';

class InvoicePdfService {
  static final _numFmt = NumberFormat('#,##0.00');

  static String _n(dynamic v, [String fallback = 'N/A']) =>
      (v == null || v.toString().trim().isEmpty) ? fallback : v.toString().trim();

  static String _fmt(dynamic v) {
    if (v == null) return '0.00';
    final d = double.tryParse(v.toString());
    return d != null ? _numFmt.format(d) : _n(v, '0.00');
  }

  // ── Ethiopic Calendar Conversion ─────────────────────────────────
  static (int, int, int) gregorianToEthiopic(int year, int month, int day) {
    final int a = (14 - month) ~/ 12;
    final int y = year + 4800 - a;
    final int m = month + 12 * a - 3;
    final int jdn = day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
    final int r = (jdn - 1723856) % 1461;
    final int n = (r % 365) + 365 * (r ~/ 1460);
    final int ethYear = 4 * ((jdn - 1723856) ~/ 1461) + (r ~/ 365) - (r ~/ 1460);
    final int ethMonth = (n ~/ 30) + 1;
    final int ethDay = (n % 30) + 1;
    return (ethYear, ethMonth, ethDay);
  }

  static String toEthiopicDate(DateTime date) {
    const months = [
      '', 'Meskerem', 'Tikimt', 'Hidar', 'Tahsas', 'Tir', 'Yakatit',
      'Megabit', 'Miyazya', 'Ginbot', 'Sene', 'Hamle', 'Nehase', 'Pagume'
    ];
    final (ethYear, ethMonth, ethDay) = gregorianToEthiopic(date.year, date.month, date.day);
    final monthName = (ethMonth >= 1 && ethMonth <= 13) ? months[ethMonth] : '';
    return '$ethDay $monthName $ethYear E.C.';
  }

  // ── Amharic Words Conversion ─────────────────────────────────────
  static String amountInWordsAmharic(double amount) {
    const ones = [
      '', 'አንድ', 'ሁለት', 'ሦስት', 'አራት', 'አምስት', 'ስድስት', 'ሰባት', 'ስምንት', 'ዘጠኝ', 'አስር',
      'አስራ አንድ', 'አስራ ሁለት', 'አስራ ሦስት', 'አስራ አራት', 'አስራ አምስት', 'አስራ ስድስት', 'አስራ ሰባት', 'አስራ ስምንት', 'አስራ ዘጠኝ'
    ];
    const tens = ['', '', 'ሃያ', 'ሠላሳ', 'አርባ', 'ሀምሳ', 'ስድሳ', 'ሰባ', 'ሰማንያ', 'ዘጠና'];

    String twoDigits(int n) {
      if (n == 0) return '';
      if (n < 20) return ones[n];
      final t = tens[n ~/ 10];
      final o = ones[n % 10];
      return o.isNotEmpty ? '$t $o' : t;
    }

    String threeDigits(int n) {
      if (n == 0) return '';
      final h = n ~/ 100;
      final rem = n % 100;
      String res = '';
      if (h > 0) {
        res = '${ones[h]} መቶ';
      }
      if (rem > 0) {
        final t = twoDigits(rem);
        res = res.isNotEmpty ? '$res $t' : t;
      }
      return res;
    }

    final int birr = amount.floor();
    final int cents = ((amount - birr) * 100).round();
    if (birr == 0 && cents == 0) return 'ዜሮ ብር';

    final List<String> parts = [];
    final int bill = birr ~/ 1000000000;
    final int remBill = birr % 1000000000;
    if (bill > 0) {
      parts.add('${threeDigits(bill)} ቢሊዮን');
    }

    final int mill = remBill ~/ 1000000;
    final int remMill = remBill % 1000000;
    if (mill > 0) {
      parts.add('${threeDigits(mill)} ሚሊዮን');
    }

    final int thous = remMill ~/ 1000;
    final int remThous = remMill % 1000;
    if (thous > 0) {
      final thStr = threeDigits(thous);
      parts.add('$thStr ሺህ');
    }

    if (remThous > 0) {
      parts.add(threeDigits(remThous));
    }

    String birrStr = parts.isNotEmpty ? '${parts.join(' ')} ብር' : (cents > 0 ? 'ዜሮ ብር' : '');
    String centsStr = cents > 0 ? 'ከ ${twoDigits(cents)} ሳንቲም' : '';

    return '$birrStr $centsStr'.trim();
  }

  // ── English Words Conversion ─────────────────────────────────────
  static String amountInWordsEnglish(double amount) {
    if (amount <= 0) return 'Zero Birr';
    final int birr = amount.floor();
    final int cents = ((amount - birr) * 100).round();

    const ones = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
      'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eightteen', 'Nineteen'
    ];
    const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

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

  static pw.ThemeData? _cachedTheme;

  static Future<pw.ThemeData> loadPdfTheme() async {
    if (_cachedTheme != null) return _cachedTheme!;

    pw.Font? baseFont;
    pw.Font? boldFont;
    pw.Font? ethiopicRegular;
    pw.Font? ethiopicBold;

    try {
      final baseData = await rootBundle.load('assets/fonts/AppFont-Regular.ttf');
      baseFont = pw.Font.ttf(baseData);
    } catch (e) {
      debugPrint('Base font load error: $e');
    }

    try {
      final boldData = await rootBundle.load('assets/fonts/AppFont-Bold.ttf');
      boldFont = pw.Font.ttf(boldData);
    } catch (e) {
      debugPrint('Bold font load error: $e');
    }

    try {
      final regData = await rootBundle.load('assets/fonts/NotoSansEthiopic-Regular.ttf');
      ethiopicRegular = pw.Font.ttf(regData);
    } catch (e) {
      debugPrint('Ethiopic regular font load error: $e');
    }

    try {
      final boldData = await rootBundle.load('assets/fonts/NotoSansEthiopic-Bold.ttf');
      ethiopicBold = pw.Font.ttf(boldData);
    } catch (e) {
      debugPrint('Ethiopic bold font load error: $e');
    }

    _cachedTheme = pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
      fontFallback: [
        ?ethiopicRegular,
        ?ethiopicBold,
      ],
    );
    return _cachedTheme!;
  }

  static pw.Widget buildCancelledStamp() {
    return pw.Center(
      child: pw.Opacity(
        opacity: 0.22,
        child: pw.Transform.rotateBox(
          angle: 0.40, // ~23 degrees counter-clockwise upward tilt
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColors.red800,
                width: 3.5,
              ),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
            ),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'CANCELLED',
                  style: pw.TextStyle(
                    fontSize: 48,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red800,
                    letterSpacing: 4,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'ተሰርዟል',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red800,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<Uint8List> generate(
    InvoiceSummary invoice, {
    bool isPaymentReceipt = false,
    String? overrideDocNumber,
    String? overrideIrnTitle,
    String? overrideIrn,
    String? overrideQr,
    String? overrideReferenceIrn,
    bool? isCancelled,
  }) async {
    final pdfTheme = await loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);

    await generateIntoDocument(
      pdf,
      invoice,
      isPaymentReceipt: isPaymentReceipt,
      overrideDocNumber: overrideDocNumber,
      overrideIrnTitle: overrideIrnTitle,
      overrideIrn: overrideIrn,
      overrideQr: overrideQr,
      overrideReferenceIrn: overrideReferenceIrn,
      isCancelled: isCancelled,
    );

    return pdf.save();
  }

  static Future<void> generateIntoDocument(
    pw.Document pdf,
    InvoiceSummary invoice, {
    bool isPaymentReceipt = false,
    String? overrideDocNumber,
    String? overrideIrnTitle,
    String? overrideIrn,
    String? overrideQr,
    String? overrideReferenceIrn,
    bool? isCancelled,
  }) async {
    final bool effectiveCancelled = isCancelled ?? invoice.isCancelled;



    final payload = invoice.requestPayload ?? {};

    // ── Extract Data ────────────────────────────────────────────────
    final seller = (payload['SellerDetails'] as Map<String, dynamic>?) ?? {};
    final buyer = (payload['BuyerDetails'] as Map<String, dynamic>?) ?? {};
    final docDet = (payload['DocumentDetails'] as Map<String, dynamic>?) ?? {};
    final valDet = (payload['ValueDetails'] as Map<String, dynamic>?) ?? {};
    final payDet = (payload['PaymentDetails'] as Map<String, dynamic>?) ?? {};
    final refDet = (payload['ReferenceDetails'] as Map<String, dynamic>?) ?? {};
    final srcSys = (payload['SourceSystem'] as Map<String, dynamic>?) ?? {};
    final items = (payload['ItemList'] as List<dynamic>?) ?? [];

    final docNumber = overrideDocNumber ?? _n(docDet['DocumentNumber'] ?? invoice.documentNumber);
    final rawDateStr = _n(docDet['Date'] ?? invoice.createdAt);
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(rawDateStr);
    } catch (_) {
      parsedDate = DateTime.now();
    }
    final gregorianDate = DateFormat('yyyy-MM-dd').format(parsedDate);
    final timeStr = DateFormat('HH:mm:ss').format(parsedDate);
    final ethiopicDate = toEthiopicDate(parsedDate);

    final txType = _n(payload['TransactionType'] ?? invoice.transactionType, 'B2C');
    final irnTitle = overrideIrnTitle ?? 'IRN:';
    final irn = overrideIrn ?? _n(invoice.irn);
    final sysNumber = _n(srcSys['SystemNumber'], '8FF7BDE512');
    final cashier = _n(srcSys['CashierName'], 'Mekanehiwot Mengistu');
    final payMode = _n(payDet['Mode'], 'CASH');

    final docType = _n(docDet['Type'], 'INV').toUpperCase();
    final payTerm = _n(payDet['PaymentTerm'], 'IMMEDIATE').toUpperCase();
    final previousIrn = overrideReferenceIrn ?? _n(refDet['PreviousIrn'], '');

    // ── Dynamic Item Level Recalculations ───────────────────────────
    double calcGross = 0.0;
    double calcDiscount = 0.0;
    double calcExcise = 0.0;
    double calcTaxableBase = 0.0;
    double calcVat15 = 0.0;
    double calcNonTaxable = 0.0;

    for (final it in items) {
      final item = it is Map<String, dynamic> ? it : <String, dynamic>{};
      final q = double.tryParse(item['Quantity']?.toString() ?? '1') ?? 1.0;
      final p = double.tryParse(item['UnitPrice']?.toString() ?? '0') ?? 0.0;
      final disc = double.tryParse(item['Discount']?.toString() ?? '0') ?? 0.0;
      final ext = double.tryParse(item['ExciseTaxValue']?.toString() ?? '0') ?? 0.0;
      final code = (item['TaxCode'] ?? '').toString().toUpperCase();

      final gross = q * p;
      calcGross += gross;
      calcDiscount += disc;
      calcExcise += ext;

      final afterDisc = gross - disc;
      final isZeroOrExempt = code.contains('0') ||
          code.contains('EX') ||
          code.contains('ZERO') ||
          code.contains('EXMT');

      if (!isZeroOrExempt) {
        final base = afterDisc + ext;
        calcTaxableBase += base;
        final taxAmt = double.tryParse(item['TaxAmount']?.toString() ?? '') ?? (base * 0.15);
        calcVat15 += taxAmt;
      } else {
        calcNonTaxable += afterDisc;
      }
    }

    final double grossTotal = valDet['TotalAmount'] != null
        ? (double.tryParse(valDet['TotalAmount'].toString()) ?? calcGross)
        : (calcGross > 0 ? calcGross : (double.tryParse((valDet['TotalValue'] ?? invoice.totals.totalValue ?? '0').toString()) ?? 0.0));
    final double discountTotal = valDet['Discount'] != null
        ? (double.tryParse(valDet['Discount'].toString()) ?? calcDiscount)
        : calcDiscount;
    final double subTotal = grossTotal - discountTotal;
    final double exciseTotal = valDet['ExciseValue'] != null
        ? (double.tryParse(valDet['ExciseValue'].toString()) ?? calcExcise)
        : calcExcise;
    final double taxableTotal = valDet['TaxableAmount'] != null
        ? (double.tryParse(valDet['TaxableAmount'].toString()) ?? calcTaxableBase)
        : (calcTaxableBase > 0 ? calcTaxableBase : subTotal);
    final double vat15Total = valDet['TaxValue'] != null
        ? (double.tryParse(valDet['TaxValue'].toString()) ?? calcVat15)
        : (calcVat15 > 0 ? calcVat15 : (taxableTotal * 0.15));
    final double nonTaxableTotal = valDet['NonTaxableAmount'] != null
        ? (double.tryParse(valDet['NonTaxableAmount'].toString()) ?? calcNonTaxable)
        : calcNonTaxable;

    final double grandTotal = valDet['TotalValue'] != null
        ? (double.tryParse(valDet['TotalValue'].toString()) ?? (taxableTotal + vat15Total + nonTaxableTotal))
        : (double.tryParse((invoice.totals.totalValue ?? '0').toString()) ?? (taxableTotal + vat15Total + nonTaxableTotal));

    final double incomeWithhold = double.tryParse((valDet['IncomeWithholdValue'] ?? '0').toString()) ?? 0.0;
    final double txnWithhold = double.tryParse((valDet['TransactionWithholdValue'] ?? '0').toString()) ?? 0.0;
    final double totalWithheld = incomeWithhold + txnWithhold;
    final double netPayable = grandTotal - totalWithheld;

    // ── Titles ──────────────────────────────────────────────────────
    String amharicTitle;
    String englishTitle;
    if (docType == 'CRE' || docType == 'CN') {
      amharicTitle = 'የታክስ ክሬዲት ኖት';
      englishTitle = 'Tax Credit Note';
    } else if (docType == 'DEB' || docType == 'DN') {
      amharicTitle = 'የታክስ ዴቢት ሰነድ';
      englishTitle = 'Tax Debit Note';
    } else if (docType == 'TWTH') {
      amharicTitle = 'ከተከፋይ ሒሳብ ላይ ለተቀነሰ ግብር የተሰጠ ደረሰኝ';
      englishTitle = 'Withholding tax on payment';
    } else if (payTerm == 'CREDIT' || payMode.toUpperCase() == 'CREDIT' || payTerm.contains('NET') || payTerm.contains('DAY')) {
      amharicTitle = 'የዱቤ ሽያጭ ታክስ ደረሰኝ';
      englishTitle = 'Credit Sales VAT Invoice';
    } else {
      amharicTitle = 'እጅ በእጅ የሽያጭ ደረሰኝ-ተአታ/ኤክሳይዝ ታክስ ኢንቮይስ';
      englishTitle = 'Cash Sales VAT/EXCISE TAX Invoice';
    }

    // ── Images ──────────────────────────────────────────────────────
    pw.MemoryImage? logoImage;
    try {
      final imgBytes = await rootBundle.load('assets/mss.png');
      logoImage = pw.MemoryImage(imgBytes.buffer.asUint8List());
    } catch (_) {
      try {
        final f = File('assets/mss.png');
        if (f.existsSync()) {
          logoImage = pw.MemoryImage(f.readAsBytesSync());
        }
      } catch (_) {}
    }

    pw.MemoryImage? qrImage;
    try {
      final qrToUse = overrideQr ?? invoice.signedQr;
      if (qrToUse != null && qrToUse.isNotEmpty) {
        qrImage = pw.MemoryImage(base64Decode(qrToUse));
      }
    } catch (e) {
      debugPrint('QR decode error: $e');
    }

    // ── Styles & Colors ─────────────────────────────────────────────
    const borderColor = PdfColors.black;
    const borderSide = pw.BorderSide(color: borderColor, width: 0.7);
    final textStyleRegular = const pw.TextStyle(fontSize: 7, color: PdfColors.black);
    final textStyleBold = pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.black);
    final textStyleSmall = const pw.TextStyle(fontSize: 6.5, color: PdfColors.black);

    final sellerLegalName = _n(seller['LegalName'] ?? seller['TradeName'], 'Micro Sun & Solution PLC');
    final buyerLegalName = _n(buyer['LegalName'] ?? invoice.buyer.legalName, 'Walking Customer');

    // ── Build Document Page ─────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          buildForeground: effectiveCancelled
              ? (ctx) => buildCancelledStamp()
              : null,
        ),
        build: (context) => [
          // ── Outer Box Section by Section ──────────────────────────
          // 1. Top Header Banner
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: borderSide,
                top: borderSide,
                right: borderSide,
                bottom: borderSide,
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Left Logo box
                pw.Container(
                  width: 95,
                  height: 58,
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.all(4),
                  child: logoImage != null
                      ? pw.Image(logoImage, height: 44, fit: pw.BoxFit.contain)
                      : pw.Text(
                          sellerLegalName,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                        ),
                ),
                pw.Container(width: 0.7, height: 58, color: borderColor),
                // Center Company Info box
                pw.Expanded(
                  child: pw.Container(
                    height: 58,
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          'POS System',
                          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          sellerLegalName,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
                        ),
                        if (_n(seller['Zone'] ?? seller['City']).isNotEmpty && _n(seller['Zone'] ?? seller['City']) != 'N/A')
                          pw.Text(
                            _n(seller['Zone'] ?? seller['City']),
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                      ],
                    ),
                  ),
                ),
                pw.Container(width: 0.7, height: 58, color: borderColor),
                // Right Invoice Details box
                pw.Container(
                  width: 160,
                  height: 58,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('የደረሰኝ ቁጥር', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Invoice No:', style: textStyleSmall),
                          pw.Text(docNumber, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('ቀን', style: textStyleSmall),
                          pw.Text(ethiopicDate, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Date', style: textStyleSmall),
                          pw.Text(gregorianDate, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('ሰዓት / Time:', style: textStyleSmall),
                          pw.Text(timeStr, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Title, IRN & QR Row
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: borderSide,
                right: borderSide,
                bottom: borderSide,
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(amharicTitle, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 1),
                      pw.Text(englishTitle, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 1),
                      pw.Text('የሽያጭ አይነት ($txType)', style: const pw.TextStyle(fontSize: 7.5)),
                      pw.SizedBox(height: 5),
                      pw.Align(
                        alignment: pw.Alignment.centerLeft,
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(
                                text: '$irnTitle ',
                                style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                              ),
                              pw.TextSpan(
                                text: irn,
                                style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.blue800),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Align(
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'System Number: $sysNumber',
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Container(
                  width: 68,
                  height: 68,
                  child: qrImage != null
                      ? pw.Image(qrImage, fit: pw.BoxFit.contain)
                      : (irn.isNotEmpty && irn != 'N/A'
                          ? pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: irn,
                            )
                          : pw.SizedBox()),
                ),
              ],
            ),
          ),

          // 3. Party Section (ከ/From and ለ/To)
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: borderSide,
                right: borderSide,
                bottom: borderSide,
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left: Seller (ከ/From)
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(7),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('ከ/From: $sellerLegalName', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('አድራሻ / Address', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        _partyRow('ከተማ / City:', _n(seller['City']), 'ዞን / Zone:', _n(seller['Zone'] ?? seller['Wereda']), textStyleSmall),
                        _partyRow('ወረዳ / Woreda:', _n(seller['Wereda']), 'ቀበሌ / Kebele:', _n(seller['Kebele']), textStyleSmall),
                        _partySingle('የሻጭ ስልክ ቁጥር / Seller\'s Phone Number:', _n(seller['Phone']), textStyleSmall),
                        _partySingle('የሻጭ ኢሜይል / Seller\'s Email:', _n(seller['Email']), textStyleSmall),
                        _partySingle('የሻጭ ተ.እ.ታ ቁጥር / Seller\'s VAT Reg.No:', _n(seller['VatNumber']), textStyleSmall),
                        _partyRow('TIN:', _n(seller['Tin']), 'Sub-TIN:', _n(seller['SubTin']), textStyleSmall),
                      ],
                    ),
                  ),
                ),
                pw.Container(width: 0.7, color: borderColor),
                // Right: Buyer (ለ/To)
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(7),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('ለ/To: $buyerLegalName', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('አድራሻ / Address', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        _partyRow('ከተማ / City:', _n(buyer['City'] ?? invoice.buyer.city), 'ዞን / Zone:', _n(buyer['Zone'] ?? buyer['Wereda']), textStyleSmall),
                        _partyRow('ወረዳ / Woreda:', _n(buyer['Wereda']), 'ቀበሌ / Kebele:', _n(buyer['Kebele']), textStyleSmall),
                        _partySingle('የገዢ ስልክ ቁጥር / Buyer\'s Phone Number:', _n(buyer['Phone'] ?? invoice.buyer.phone), textStyleSmall),
                        _partySingle('የገዢ ኢሜይል / Buyer\'s Email:', _n(buyer['Email'] ?? invoice.buyer.email), textStyleSmall),
                        _partySingle('የገዢ ተ.እ.ታ ቁጥር / Buyer\'s VAT Reg.No:', _n(buyer['VatNumber']), textStyleSmall),
                        _partyRow('TIN:', _n(buyer['Tin'] ?? invoice.buyer.tin), 'Sub-TIN:', _n(buyer['SubTin']), textStyleSmall),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Line Items Table with minimum 3 rows padding (ERCA Item 4)
          _buildItemsTable(items, textStyleSmall, textStyleRegular, textStyleBold, borderSide),

          // 5. Totals Block (ERCA Standard Hierarchy)
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: borderSide,
                right: borderSide,
                bottom: borderSide,
              ),
            ),
            child: pw.Column(
              children: [
                _buildTotalRow('ድምር / Total', _numFmt.format(grossTotal), borderSide, textStyleRegular),
                _buildTotalRow('የቅናሽ መጠን / Discount Amount', _numFmt.format(discountTotal), borderSide, textStyleRegular),
                _buildTotalRow('የሚከፈልበት ድምር / Sub Total', _numFmt.format(subTotal), borderSide, textStyleRegular),
                _buildTotalRow('ኤክሳይዝ ታክስ / Excise Tax', _numFmt.format(exciseTotal), borderSide, textStyleRegular),
                _buildTotalRow('ተ.እ.ታክስ የሚከፈልበት ድምር / Taxable Total', _numFmt.format(taxableTotal), borderSide, textStyleRegular),
                _buildTotalRow('VAT15 ታክስ / VAT15 Tax rate (15%)', _numFmt.format(vat15Total), borderSide, textStyleRegular),
                _buildTotalRow('ታክስ የማይከፈልበት ድምር / Non-taxable Amount', _numFmt.format(nonTaxableTotal), borderSide, textStyleRegular),
                _buildTotalRow('ጠቅላላ ዋጋ ከታክስ ጋር / Total including Tax', _numFmt.format(grandTotal), borderSide, textStyleBold),
                if (totalWithheld > 0) ...[
                  _buildTotalRow('ጠቅላላ የተያዘ መጠን / Total Withheld Amount', _numFmt.format(incomeWithhold), borderSide, textStyleRegular),
                  _buildTotalRow('ጠቅላላ የተያዘ መጠን ተ.እ / Total VAT Withheld Amount', _numFmt.format(txnWithhold), borderSide, textStyleRegular),
                  _buildTotalRow('ተጣራ የሚከፈል / Net Payable', _numFmt.format(netPayable), borderSide, textStyleBold),
                ],
              ],
            ),
          ),

          // 6. In Words Section
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: borderSide,
                right: borderSide,
                bottom: borderSide,
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('በፊደል ብር / IN WORDS (AMHARIC)', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        amountInWordsAmharic(netPayable > 0 ? netPayable : grandTotal),
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                pw.Container(width: 0.7, height: 26, color: borderColor),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('IN WORDS (ENGLISH)', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        amountInWordsEnglish(netPayable > 0 ? netPayable : grandTotal),
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 7. Payment & Signatures 3-Column Section
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: borderSide,
                right: borderSide,
                bottom: borderSide,
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Col 1: Payment Mode
                pw.Expanded(
                  child: pw.Container(
                    height: 52,
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('የክፍያ ሁኔታ / Mode of Payment', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                        pw.Spacer(),
                        pw.Text('አይነት / Type:', style: textStyleSmall),
                        pw.Text(payMode, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                pw.Container(width: 0.7, height: 52, color: borderColor),
                // Col 2: Seller Information & Signature
                pw.Expanded(
                  child: pw.Container(
                    height: 52,
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('የሻጭ መረጃ / Seller Information', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                        pw.Spacer(),
                        pw.Text('የተቀባይ (ሻጭ) ስምና ፊርማ / Seller Name & Signature:', style: textStyleSmall),
                        pw.Text(cashier, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        pw.Container(height: 0.5, color: PdfColors.grey400),
                      ],
                    ),
                  ),
                ),
                pw.Container(width: 0.7, height: 52, color: borderColor),
                // Col 3: Receiver Information & Signature
                pw.Expanded(
                  child: pw.Container(
                    height: 52,
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('የተቀባይ መረጃ / Receiver Information', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                        pw.Spacer(),
                        pw.Text('የተቀባይ ስምና ፊርማ / Receiver Name & Signature:', style: textStyleSmall),
                        pw.Text(buyerLegalName, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        pw.Container(height: 0.5, color: PdfColors.grey400),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 8. Reference Box (For Credit / Debit Notes - ERCA Sample invoice-395.pdf / 401.pdf)
          if ((docType == 'CRE' || docType == 'DEB' || docType == 'CN' || docType == 'DN') && previousIrn.isNotEmpty)
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: borderSide,
                  right: borderSide,
                  bottom: borderSide,
                ),
              ),
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('ማጣቀሻ / Reference:', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                  pw.SizedBox(height: 1),
                  pw.Text(previousIrn, style: const pw.TextStyle(fontSize: 7, color: PdfColors.black)),
                ],
              ),
            ),

          // 9. Bottom Salutation Note
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: borderSide,
                right: borderSide,
                bottom: borderSide,
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'Thank you for choosing $sellerLegalName!',
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────
  static pw.Widget _partyRow(String l1, String v1, String l2, String v2, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.8),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Row(
              children: [
                pw.Text('$l1 ', style: style),
                pw.Expanded(child: pw.Text(v1, style: style.copyWith(fontWeight: pw.FontWeight.bold))),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Row(
              children: [
                pw.Text('$l2 ', style: style),
                pw.Expanded(child: pw.Text(v2, style: style.copyWith(fontWeight: pw.FontWeight.bold))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _partySingle(String label, String value, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.8),
      child: pw.Row(
        children: [
          pw.Text('$label ', style: style),
          pw.Expanded(child: pw.Text(value, style: style.copyWith(fontWeight: pw.FontWeight.bold))),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(
    List<dynamic> items,
    pw.TextStyle textStyleSmall,
    pw.TextStyle textStyleRegular,
    pw.TextStyle textStyleBold,
    pw.BorderSide borderSide,
  ) {
    const colWidths = [
      pw.FixedColumnWidth(22), // S.N
      pw.FlexColumnWidth(3),   // Description
      pw.FixedColumnWidth(38), // Nature
      pw.FixedColumnWidth(28), // UoM
      pw.FixedColumnWidth(28), // Qty
      pw.FixedColumnWidth(48), // Unit Price
      pw.FixedColumnWidth(38), // Tax Code
      pw.FixedColumnWidth(36), // Excise
      pw.FixedColumnWidth(42), // Discount
      pw.FixedColumnWidth(54), // Total Amount
    ];

    const headerLabels = [
      'ተ.ቁ\nS.N',
      'የዕቃው አይነት\nDescription',
      'ምድብ\nNature',
      'መለኪያ\nUoM',
      'ብዛት\nQty',
      'የአንዱ ዋጋ\nUnit Price',
      'ታክስ ኮድ\nTax Code',
      'ኤክሳይዝ\nExcise',
      'ቅናሽ\nItem Discount',
      'ጠቅላላ ዋጋ\nTotal Amount',
    ];

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.white),
      children: headerLabels.map((h) {
        return pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
          child: pw.Text(
            h,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
          ),
        );
      }).toList(),
    );

    final List<pw.TableRow> dataRows = [];

    // Add actual items
    for (int i = 0; i < items.length; i++) {
      final item = items[i] is Map<String, dynamic> ? items[i] : <String, dynamic>{};
      final q = double.tryParse(item['Quantity']?.toString() ?? '1') ?? 1.0;
      final p = double.tryParse(item['UnitPrice']?.toString() ?? '0') ?? 0.0;
      final disc = double.tryParse(item['Discount']?.toString() ?? '0') ?? 0.0;
      final ext = double.tryParse(item['ExciseTaxValue']?.toString() ?? '0') ?? 0.0;
      final gross = q * p;

      dataRows.add(
        pw.TableRow(
          children: [
            _cell('${i + 1}', align: pw.TextAlign.center),
            _cell(_n(item['ProductDescription'])),
            _cell(_n(item['NatureOfSupplies'], 'goods'), align: pw.TextAlign.center),
            _cell(_n(item['Unit'], 'PCS'), align: pw.TextAlign.center),
            _cell(q.toStringAsFixed(1), align: pw.TextAlign.right),
            _cell(_fmt(p), align: pw.TextAlign.right),
            _cell(_n(item['TaxCode'], 'VAT15'), align: pw.TextAlign.center),
            _cell(_fmt(ext), align: pw.TextAlign.right),
            _cell(_fmt(disc), align: pw.TextAlign.right),
            _cell(_fmt(gross), align: pw.TextAlign.right),
          ],
        ),
      );
    }

    // ERCA Compliance Requirement 4: Pad table with empty boxes up to at least 3 rows
    for (int i = items.length; i < 3; i++) {
      dataRows.add(
        pw.TableRow(
          children: [
            _cell('${i + 1}', align: pw.TextAlign.center),
            _cell(''),
            _cell(''),
            _cell(''),
            _cell(''),
            _cell(''),
            _cell(''),
            _cell(''),
            _cell(''),
            _cell(''),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.7),
      columnWidths: Map.fromEntries(colWidths.asMap().entries.map((e) => MapEntry(e.key, e.value))),
      children: [
        headerRow,
        ...dataRows,
      ],
    );
  }

  static pw.Widget _cell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      alignment: align == pw.TextAlign.right
          ? pw.Alignment.centerRight
          : (align == pw.TextAlign.center ? pw.Alignment.center : pw.Alignment.centerLeft),
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 3),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.black),
      ),
    );
  }

  static pw.Widget _buildTotalRow(
    String label,
    String value,
    pw.BorderSide borderSide,
    pw.TextStyle style,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.4)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(label, style: style),
          pw.SizedBox(width: 25),
          pw.Container(
            width: 75,
            alignment: pw.Alignment.centerRight,
            child: pw.Text(value, style: style),
          ),
        ],
      ),
    );
  }
}
