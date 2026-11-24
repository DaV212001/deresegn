import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/app_settings.dart';
import '../config/config_preference.dart';
import '../models/invoice_history_model.dart';
import '../models/receipt_models.dart';
import 'invoice_pdf_service.dart';

enum ReceiptPaperFormat {
  a4,
  roll80,
  roll58,
}

class CompanyProfileOverride {
  final String? tin;
  final String? tradeName;
  final String? legalName;
  final String? vatNumber;
  final String? address;
  final String? phone;
  final String? cashierName;
  final String? systemNumber;

  const CompanyProfileOverride({
    this.tin,
    this.tradeName,
    this.legalName,
    this.vatNumber,
    this.address,
    this.phone,
    this.cashierName,
    this.systemNumber,
  });
}

class _SellerProfile {
  final String tin;
  final String name;
  final String vat;
  final String address;
  final String cashier;
  final String sourceNo;
  final String serialNo;

  _SellerProfile({
    required this.tin,
    required this.name,
    required this.vat,
    required this.address,
    required this.cashier,
    required this.sourceNo,
    required this.serialNo,
  });
}

class ThermalReceiptPdfService {
  static final _numFmt = NumberFormat('#,##0.00');

  static String _n(dynamic v, [String fallback = 'N/A']) =>
      (v == null || v.toString().trim().isEmpty) ? fallback : v.toString().trim();

  static String _fmt(dynamic v) {
    if (v == null) return '0.00';
    final d = double.tryParse(v.toString());
    return d != null ? _numFmt.format(d) : _n(v, '0.00');
  }

  /// Dashed divider for thermal receipts matching standard thermal paper layout
  static pw.Widget _dashedLine({double thickness = 0.6}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Divider(
        borderStyle: pw.BorderStyle.dashed,
        thickness: thickness,
        color: PdfColors.black,
      ),
    );
  }

  /// Solid thin divider
  static pw.Widget _solidLine({double thickness = 0.6}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Divider(
        thickness: thickness,
        color: PdfColors.black,
      ),
    );
  }

  /// Dynamically resolves the issuing company's authentic details from the invoice payload,
  /// with automatic fallback to the user's stored company configuration (AppSettings / ConfigPreference).
  static Future<_SellerProfile> _resolveSellerProfile(
    Map<String, dynamic> seller,
    Map<String, dynamic> sysSys, {
    String? cashierOverride,
    CompanyProfileOverride? override,
  }) async {
    String? appTin;
    String? appTradeName;
    String? appVat;
    String? appCashier;
    String? appSystemNumber;
    String? branchPhone;

    try {
      appTin = await ConfigPreference.getTin();
    } catch (_) {}
    try {
      appTradeName = await AppSettings.getTradeName();
    } catch (_) {}
    try {
      appVat = await AppSettings.getVatNumber();
    } catch (_) {}
    try {
      appCashier = await AppSettings.getCashierName();
    } catch (_) {}
    try {
      appSystemNumber = await AppSettings.getSystemNumber();
    } catch (_) {}
    try {
      branchPhone = ConfigPreference.getBranchPhone();
    } catch (_) {}

    // 1. Resolve TIN
    String tin = override?.tin ?? _n(seller['Tin'] ?? seller['TIN'], '');
    if (tin.isEmpty || tin == 'N/A' || tin == '0046246548') {
      tin = (appTin != null && appTin.isNotEmpty) ? appTin : '0000037187';
    }

    // 2. Resolve Trade / Legal Name
    String name = override?.tradeName ??
        override?.legalName ??
        _n(seller['TradeName'] ?? seller['LegalName'], '');
    if (name.isEmpty || name == 'N/A' || name.toLowerCase().contains('zowi')) {
      name = (appTradeName != null && appTradeName.isNotEmpty)
          ? appTradeName
          : 'Micro Sun & Solution PLC';
    }

    // 3. Resolve VAT
    String vat = override?.vatNumber ?? _n(seller['VatRegistrationNumber'] ?? seller['VatNumber'], '');
    if (vat.isEmpty || vat == 'N/A' || vat == '43756663343756663322') {
      vat = (appVat != null && appVat.isNotEmpty) ? appVat : '';
    }

    // 4. Resolve Address & Phone
    final region = _n(seller['Region'], '');
    final woreda = _n(seller['Woreda'] ?? seller['Wereda'], '');
    final city = _n(seller['City'], '');
    final phone = override?.phone ?? _n(seller['Telephone'] ?? seller['Phone'] ?? branchPhone, '');

    final List<String> addressParts = [];
    if (override?.address != null && override!.address!.isNotEmpty) {
      addressParts.add(override.address!);
    } else {
      if (city.isNotEmpty && city != 'N/A') addressParts.add(city);
      if (region.isNotEmpty && region != 'N/A') addressParts.add('Region $region');
      if (woreda.isNotEmpty && woreda != 'N/A') addressParts.add('Woreda $woreda');
    }
    if (phone.isNotEmpty && phone != 'N/A') addressParts.add('Phone: $phone');
    final address = addressParts.join(', ');

    // 5. Resolve Cashier
    String cashier = override?.cashierName ??
        _n(cashierOverride ?? seller['Cashier'] ?? sysSys['OperatorName'] ?? sysSys['CashierName'], '');
    if (cashier.isEmpty || cashier == 'N/A') {
      cashier = (appCashier != null && appCashier.isNotEmpty) ? appCashier : 'Cashier';
    }

    // 6. Resolve Source System & Serial Number
    String sourceNo = override?.systemNumber ??
        _n(sysSys['SourceSystemCode'] ?? sysSys['SourceNo'] ?? sysSys['SystemNumber'], '');
    if (sourceNo.isEmpty || sourceNo == 'N/A' || sourceNo == '50E6490108') {
      sourceNo = (appSystemNumber != null && appSystemNumber.isNotEmpty) ? appSystemNumber : 'F86A66EF99';
    }

    String serialNo = override?.systemNumber ??
        _n(sysSys['DeviceSerialNumber'] ?? sysSys['SerialNumber'] ?? sysSys['SourceSystemNumber'], '');
    if (serialNo.isEmpty || serialNo == 'N/A' || serialNo == 'F654600000098') {
      serialNo = (appSystemNumber != null && appSystemNumber.isNotEmpty) ? appSystemNumber : 'F86A66EF99';
    }

    return _SellerProfile(
      tin: tin,
      name: name,
      vat: vat,
      address: address,
      cashier: cashier,
      sourceNo: sourceNo,
      serialNo: serialNo,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. INVOICE THERMAL RECEIPT (Cash/Credit Invoice, Cancelled, CRE, DEB)
  // ─────────────────────────────────────────────────────────────
  static Future<Uint8List> generateInvoiceReceipt(
    InvoiceSummary invoice, {
    ReceiptPaperFormat paperFormat = ReceiptPaperFormat.roll80,
    bool? isCancelled,
    bool isPaymentReceipt = false,
    String? overrideDocNumber,
    String? overrideIrnTitle,
    String? overrideIrn,
    String? overrideQr,
    String? overrideReferenceIrn,
    CompanyProfileOverride? companyOverride,
  }) async {
    final pdfTheme = await InvoicePdfService.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);

    final bool is80mm = paperFormat == ReceiptPaperFormat.roll80;
    final pageFormat = is80mm
        ? PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm)
        : PdfPageFormat(57 * PdfPageFormat.mm, double.infinity, marginAll: 2.5 * PdfPageFormat.mm);

    final bool effectiveCancelled = isCancelled ?? invoice.isCancelled;
    final payload = invoice.requestPayload ?? {};

    final seller = (payload['SellerDetails'] as Map<String, dynamic>?) ??
        (payload['seller'] as Map<String, dynamic>?) ??
        {};
    final buyer = (payload['BuyerDetails'] as Map<String, dynamic>?) ??
        (payload['buyer'] as Map<String, dynamic>?) ??
        {};
    final sysSys = (payload['SourceSystem'] as Map<String, dynamic>?) ?? {};
    final docDet = (payload['DocumentDetails'] as Map<String, dynamic>?) ??
        (payload['documentDetails'] as Map<String, dynamic>?) ??
        {};
    final payDet = (payload['PaymentDetails'] as Map<String, dynamic>?) ??
        (payload['paymentDetails'] as Map<String, dynamic>?) ??
        {};
    final refDet = (payload['ReferenceDetails'] as Map<String, dynamic>?) ??
        (payload['referenceDetails'] as Map<String, dynamic>?) ??
        {};
    final valDet = (payload['ValueDetails'] as Map<String, dynamic>?) ??
        (payload['valueDetails'] as Map<String, dynamic>?) ??
        (payload['InvoiceTotals'] as Map<String, dynamic>?) ??
        (payload['Totals'] as Map<String, dynamic>?) ??
        (payload['totals'] as Map<String, dynamic>?) ??
        {};

    // Resolve issuing company details dynamically from user's company profile
    final sellerProfile = await _resolveSellerProfile(
      seller,
      sysSys,
      cashierOverride: payload['Cashier']?.toString(),
      override: companyOverride,
    );

    final rawType = docDet['Type'] ??
        docDet['type'] ??
        payload['DocumentType'] ??
        payload['InvoiceType'] ??
        invoice.transactionType;
    final docType = _n(rawType, 'INV').toUpperCase();

    final isCreditNote = docType.contains('CREDIT') || docType == 'CRE' || docType == 'CN';
    final isDebitNote = docType.contains('DEBIT') || docType == 'DEB' || docType == 'DN';
    final paymentMeans = _n(
      payDet['Mode'] ??
          payDet['mode'] ??
          payDet['PaymentMode'] ??
          payload['PaymentMeans'] ??
          payload['PaymentMode'],
      '',
    ).toUpperCase();
    final paymentTerm = _n(
      payDet['PaymentTerm'] ?? payDet['paymentTerm'] ?? payload['PaymentTerm'],
      'IMMEDIATE',
    ).toUpperCase();

    final isCreditInvoice = docType.contains('CREDIT_SALES') ||
        paymentTerm == 'CREDIT' ||
        paymentMeans == 'CREDIT' ||
        paymentTerm.contains('NET') ||
        paymentTerm.contains('DAY');

    final isB2B = (payload['TransactionType']?.toString().toUpperCase() == 'B2B') ||
        (invoice.transactionType?.toUpperCase() == 'B2B') ||
        (buyer['Tin'] != null && buyer['Tin'].toString().trim().isNotEmpty && buyer['Tin'].toString().trim() != 'null');

    // Dynamic typography scaling based on roll width (80mm vs 58mm)
    final double headerTinSize = is80mm ? 13 : 11;
    final double shopNameSize = is80mm ? 11 : 9.5;
    final double titleSize = is80mm ? 9.5 : 8.2;
    final double bodySize = is80mm ? 7.5 : 6.4;
    final double itemAmtSize = is80mm ? 8.0 : 6.8;
    final double taxSubSize = is80mm ? 6.5 : 5.6;
    final double totalSize = is80mm ? 11.5 : 9.8;
    final double qrSize = is80mm ? 130 : 98;
    final double footerSize = is80mm ? 6.5 : 5.5;

    // Load QR Image if available
    pw.MemoryImage? qrImage;
    try {
      final qrToUse = overrideQr ?? invoice.signedQr;
      if (qrToUse != null && qrToUse.isNotEmpty) {
        qrImage = pw.MemoryImage(base64Decode(qrToUse));
      }
    } catch (_) {}

    final rawDate = docDet['Date'] ??
        docDet['date'] ??
        payload['IssueDateTime'] ??
        payload['InvoiceDate'] ??
        invoice.createdAt ??
        invoice.ackDate;
    String formattedDate = 'N/A';
    if (rawDate != null) {
      try {
        final dt = DateTime.parse(rawDate.toString()).toLocal();
        formattedDate = DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);
      } catch (_) {
        try {
          final s = rawDate.toString();
          final parts = s.split('T');
          final dParts = parts[0].split('-');
          if (dParts.length == 3 && dParts[0].length == 2 && dParts[2].length == 4) {
            formattedDate = '${dParts[0]}/${dParts[1]}/${dParts[2]} ${parts.length > 1 ? parts[1] : ''}'.trim();
          } else {
            formattedDate = s;
          }
        } catch (_) {
          formattedDate = rawDate.toString();
        }
      }
    }

    final String docNo = _n(
      overrideDocNumber ??
          invoice.documentNumber ??
          docDet['DocumentNumber'] ??
          docDet['documentNumber'] ??
          payload['DocumentNumber'] ??
          payload['InvoiceNumber'] ??
          invoice.id.toString(),
      'N/A',
    );
    final String customerName = _n(
      buyer['LegalName'] ?? buyer['legal_name'] ?? buyer['TradeName'] ?? invoice.buyer.legalName,
      'Taxpayer P',
    );
    final rawCustomerTin = buyer['Tin'] ?? buyer['tin'] ?? buyer['TIN'] ?? invoice.buyer.tin;
    final String customerTin = (rawCustomerTin == null || rawCustomerTin.toString() == 'null')
        ? ''
        : rawCustomerTin.toString().trim();

    final rawParent = overrideReferenceIrn ??
        refDet['PreviousIrn'] ??
        refDet['previousIrn'] ??
        refDet['RelatedDocument']?['Irn'] ??
        refDet['relatedDocument']?['irn'] ??
        payload['PreviousIrn'] ??
        payload['RelatedDocument']?['Irn'] ??
        payload['OriginalInvoiceIrn'];
    final String parentIrn = (rawParent == null || rawParent.toString() == 'null' || rawParent.toString().trim().isEmpty)
        ? ''
        : rawParent.toString().trim();

    final String irn = _n(overrideIrn ?? invoice.irn, '');

    // Line items (supports MoR standard ItemList, InvoiceLines, LineItems, or root items)
    final rawLines = (payload['ItemList'] as List<dynamic>?) ??
        (payload['itemList'] as List<dynamic>?) ??
        (payload['InvoiceLines'] as List<dynamic>?) ??
        (payload['LineItems'] as List<dynamic>?) ??
        (payload['items'] as List<dynamic>?) ??
        (payload['Items'] as List<dynamic>?) ??
        [];

    // Item-level recalculations
    double calcGross = 0.0;
    double calcDiscount = 0.0;
    double calcExcise = 0.0;
    double calcVat15 = 0.0;

    for (final it in rawLines) {
      final item = it is Map<String, dynamic> ? it : <String, dynamic>{};
      final q = double.tryParse((item['Quantity'] ?? item['Qty'] ?? item['qty'] ?? '1').toString()) ?? 1.0;
      final p = double.tryParse((item['UnitPrice'] ?? item['Price'] ?? item['unitPrice'] ?? item['price'] ?? '0').toString()) ?? 0.0;
      final disc = double.tryParse((item['Discount'] ?? item['discount'] ?? '0').toString()) ?? 0.0;
      final ext = double.tryParse((item['ExciseTaxValue'] ?? item['ExciseAmount'] ?? item['exciseTaxValue'] ?? '0').toString()) ?? 0.0;
      final code = (item['TaxCode'] ?? item['TaxCategory'] ?? item['TaxRate'] ?? item['taxCode'] ?? '').toString().toUpperCase();

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
        final taxAmt = double.tryParse((item['TaxAmount'] ?? item['VatAmount'] ?? item['taxAmount'] ?? '').toString()) ?? (base * 0.15);
        calcVat15 += taxAmt;
      }
    }

    final double grossTotal = valDet['TotalAmount'] != null
        ? (double.tryParse(valDet['TotalAmount'].toString()) ?? calcGross)
        : (calcGross > 0
            ? calcGross
            : (double.tryParse((valDet['GrossAmount'] ?? valDet['SubTotal'] ?? valDet['TotalValue'] ?? invoice.totals.totalValue ?? '0').toString()) ?? 0.0));
    final double discountTotal = valDet['Discount'] != null
        ? (double.tryParse(valDet['Discount'].toString()) ?? calcDiscount)
        : (valDet['DiscountAmount'] != null
            ? (double.tryParse(valDet['DiscountAmount'].toString()) ?? calcDiscount)
            : calcDiscount);
    final double subTotal = grossTotal - discountTotal;
    final double exciseTotal = valDet['ExciseValue'] != null
        ? (double.tryParse(valDet['ExciseValue'].toString()) ?? calcExcise)
        : (valDet['ExciseTaxAmount'] != null || valDet['ExciseAmount'] != null
            ? (double.tryParse((valDet['ExciseTaxAmount'] ?? valDet['ExciseAmount']).toString()) ?? calcExcise)
            : (double.tryParse(invoice.totals.exciseValue ?? '0') ?? calcExcise));
    final double vat15Total = valDet['TaxValue'] != null
        ? (double.tryParse(valDet['TaxValue'].toString()) ?? calcVat15)
        : (valDet['VatAmount'] != null || valDet['TaxAmount'] != null
            ? (double.tryParse((valDet['VatAmount'] ?? valDet['TaxAmount']).toString()) ?? calcVat15)
            : (calcVat15 > 0 ? calcVat15 : (double.tryParse(invoice.totals.taxValue ?? '0') ?? 0.0)));
    final double grandTotal = valDet['TotalValue'] != null
        ? (double.tryParse(valDet['TotalValue'].toString()) ?? (subTotal + exciseTotal + vat15Total))
        : (valDet['TotalInvoiceAmount'] != null || valDet['GrandTotal'] != null
            ? (double.tryParse((valDet['TotalInvoiceAmount'] ?? valDet['GrandTotal']).toString()) ?? (subTotal + exciseTotal + vat15Total))
            : (double.tryParse(invoice.totals.totalValue ?? '0') ?? (subTotal + exciseTotal + vat15Total)));

    final paymentMode = paymentMeans.isNotEmpty ? paymentMeans : 'CASH';
    final cashTendered = double.tryParse(_n(payload['CashTendered'] ?? valDet['CashTendered'])) ?? grandTotal;
    final change = double.tryParse(_n(payload['Change'] ?? valDet['Change'])) ?? 0.0;

    // Title selection
    String amharicTitle;
    String englishTitle;
    if (effectiveCancelled) {
      amharicTitle = 'የዕቃ ሽያጭ ደረሰኝ / የ.አ.ታ/ ኤክሳይስ ታክስ (የተሰረዘ)';
      englishTitle = 'Cash Sales Invoice/VAT/Excise (Cancelled)';
    } else if (isCreditNote) {
      amharicTitle = 'የክሬዲት ማስታወሻ ደረሰኝ';
      englishTitle = 'Credit Note';
    } else if (isDebitNote) {
      amharicTitle = 'የዴቢት ማስታወሻ ደረሰኝ';
      englishTitle = 'Debit Note';
    } else if (isCreditInvoice) {
      amharicTitle = 'የብድር ሽያጭ ደረሰኝ';
      englishTitle = 'Credit Sales Invoice';
    } else {
      amharicTitle = 'የዕቃ ሽያጭ ደረሰኝ / የ.አ.ታ/ ኤክሳይስ ታክስ';
      englishTitle = 'Cash Sales Invoice/VAT/Excise';
    }

    final transactionTypeLabel = isB2B
        ? 'የግብይት ዓይነት / Transaction Type B2B'
        : 'የግብይት ዓይነት / Transaction Type B2C';

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // 1. Header (User Company TIN, Trade Name, VAT, Address, Date)
              pw.Center(
                child: pw.Text(
                  sellerProfile.tin,
                  style: pw.TextStyle(fontSize: headerTinSize, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Center(
                child: pw.Text(
                  sellerProfile.name,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: shopNameSize, fontWeight: pw.FontWeight.bold),
                ),
              ),
              if (sellerProfile.vat.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'VAT: ${sellerProfile.vat}',
                    style: pw.TextStyle(fontSize: bodySize),
                  ),
                ),
              if (sellerProfile.address.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    sellerProfile.address,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: bodySize),
                  ),
                ),
              pw.Center(
                child: pw.Text(
                  'Date: $formattedDate',
                  style: pw.TextStyle(fontSize: bodySize),
                ),
              ),
              _dashedLine(),

              // 2. Document Title & Transaction Classification
              pw.Center(
                child: pw.Text(
                  amharicTitle,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: titleSize, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  englishTitle,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: titleSize - 0.5, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  transactionTypeLabel,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: bodySize - 0.5),
                ),
              ),
              _solidLine(),

              // 3. Document Metadata (Doc No, Ref, Cashier, Customer, TIN)
              _buildMetaRow('Doc No.:', docNo, bodySize),
              if (parentIrn.isNotEmpty && parentIrn != 'N/A' && parentIrn != 'null') ...[
                _buildMetaRow('Ref:', parentIrn, bodySize - 1, isRef: true),
              ],
              _buildMetaRow('Cashier:', sellerProfile.cashier, bodySize),
              _buildMetaRow('Customer:', customerName, bodySize),
              if (customerTin.isNotEmpty)
                _buildMetaRow('Customer TIN:', customerTin, bodySize),
              _dashedLine(),

              // 4. Line Items Table Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text('Description', style: pw.TextStyle(fontSize: bodySize, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text('Qty Price', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: bodySize, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: bodySize, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              _solidLine(thickness: 0.4),

              // 5. Line Items Rows
              if (rawLines.isEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Center(
                    child: pw.Text('No items', style: pw.TextStyle(fontSize: bodySize)),
                  ),
                )
              else
                ...rawLines.map((line) {
                  final lMap = (line is Map<String, dynamic>) ? line : <String, dynamic>{};
                  final desc = _n(
                    lMap['ProductDescription'] ??
                        lMap['ItemName'] ??
                        lMap['Description'] ??
                        lMap['name'] ??
                        lMap['ItemCode'],
                    'Item',
                  );
                  final qty = _n(lMap['Quantity'] ?? lMap['Qty'] ?? lMap['qty'], '1');
                  final unitPrice = _fmt(lMap['UnitPrice'] ?? lMap['Price'] ?? lMap['unitPrice'] ?? lMap['price']);
                  final qNum = double.tryParse(qty.toString()) ?? 1.0;
                  final pNum = double.tryParse((lMap['UnitPrice'] ?? lMap['Price'] ?? lMap['unitPrice'] ?? lMap['price'] ?? '0').toString()) ?? 0.0;
                  final lineAmt = (lMap['PreTaxValue'] != null)
                      ? _fmt(lMap['PreTaxValue'])
                      : (lMap['LineAmount'] != null)
                          ? _fmt(lMap['LineAmount'])
                          : (lMap['TotalLineAmount'] != null)
                              ? _fmt(lMap['TotalLineAmount'])
                              : (lMap['Total'] != null || lMap['Amount'] != null)
                                  ? _fmt(lMap['Total'] ?? lMap['Amount'])
                                  : _fmt(qNum * pNum);
                  final taxCode = _n(
                    lMap['TaxCode'] ??
                        lMap['TaxCategory'] ??
                        lMap['TaxRate'] ??
                        lMap['taxCode'],
                    'VAT15',
                  );

                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              flex: 5,
                              child: pw.Text(desc, style: pw.TextStyle(fontSize: bodySize, fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Expanded(
                              flex: 3,
                              child: pw.Text(
                                '${qty}x $unitPrice',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(fontSize: bodySize),
                              ),
                            ),
                            pw.Expanded(
                              flex: 3,
                              child: pw.Text(
                                lineAmt,
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(fontSize: itemAmtSize, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 4, top: 1),
                          child: pw.Text(
                            'Tax: $taxCode',
                            style: pw.TextStyle(fontSize: taxSubSize, color: PdfColors.grey700),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              _dashedLine(),

              // 6. Summary Block
              _buildSummaryRow('Sub Total', _fmt(subTotal), bodySize),
              if (discountTotal > 0)
                _buildSummaryRow('Discount', '-${_fmt(discountTotal)}', bodySize),
              if (exciseTotal > 0)
                _buildSummaryRow('Excise Tax', _fmt(exciseTotal), bodySize),
              _buildSummaryRow('VAT15', _fmt(vat15Total), bodySize),
              _solidLine(thickness: 0.8),

              // Prominent Grand Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontSize: totalSize, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_fmt(grandTotal), style: pw.TextStyle(fontSize: totalSize, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              _solidLine(thickness: 0.8),

              // Item count & Payment Breakdown
              _buildSummaryRow('ITEM#', rawLines.isNotEmpty ? rawLines.length.toString() : '1', bodySize),
              _buildSummaryRow('Payment Mode', paymentMode, bodySize),
              if (paymentMode == 'CASH') ...[
                _buildSummaryRow('Cash Tendered', _fmt(cashTendered), bodySize),
                _buildSummaryRow('Change', _fmt(change), bodySize),
              ],
              pw.SizedBox(height: 6),

              // 7. Large Centered QR Code
              pw.Center(
                child: pw.Container(
                  width: qrSize,
                  height: qrSize,
                  child: qrImage != null
                      ? pw.Image(qrImage, fit: pw.BoxFit.contain)
                      : (irn.isNotEmpty && irn != 'N/A'
                          ? pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: irn,
                            )
                          : pw.SizedBox()),
                ),
              ),
              pw.SizedBox(height: 6),

              // 8. Fiscal & IRN Footer
              if (irn.isNotEmpty && irn != 'N/A') ...[
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('IRN:-', style: pw.TextStyle(fontSize: footerSize, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Text(
                  irn,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: footerSize - 0.5),
                ),
                pw.SizedBox(height: 2),
              ],
              _dashedLine(),

              _buildSummaryRow('Source No.:', sellerProfile.sourceNo, footerSize),
              _buildSummaryRow('Serial No.:', sellerProfile.serialNo, footerSize),
              _dashedLine(),

              pw.Center(
                child: pw.Text(
                  'Powered by Deresegn',
                  style: pw.TextStyle(fontSize: footerSize, fontStyle: pw.FontStyle.italic),
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────
  // 2. VOUCHER & WITHHOLDING THERMAL RECEIPT (CRV & WHT)
  // ─────────────────────────────────────────────────────────────
  static Future<Uint8List> generateVoucherReceipt(
    ReceiptSummary receipt,
    InvoiceSummary invoice, {
    ReceiptPaperFormat paperFormat = ReceiptPaperFormat.roll80,
    bool isWithholding = false,
    bool? isCancelled,
    CompanyProfileOverride? companyOverride,
  }) async {
    final pdfTheme = await InvoicePdfService.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);

    final bool is80mm = paperFormat == ReceiptPaperFormat.roll80;
    final pageFormat = is80mm
        ? PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm)
        : PdfPageFormat(57 * PdfPageFormat.mm, double.infinity, marginAll: 2.5 * PdfPageFormat.mm);

    final rPayload = receipt.requestPayload ?? {};
    final iPayload = invoice.requestPayload ?? {};

    final checkWithholding = isWithholding ||
        rPayload.containsKey('WithholdDetail') ||
        (receipt.receiptNumber != null && receipt.receiptNumber!.toUpperCase().contains('WHT')) ||
        (receipt.morId != null && receipt.morId!.toUpperCase().contains('WHT')) ||
        rPayload['Reason']?.toString().toLowerCase().contains('withholding') == true ||
        rPayload['ReceiptType']?.toString().toUpperCase() == 'TWTH';

    final seller = (iPayload['SellerDetails'] as Map<String, dynamic>?) ?? {};
    final buyer = (iPayload['BuyerDetails'] as Map<String, dynamic>?) ?? {};
    final sysSys = (rPayload['SourceSystemType'] != null)
        ? rPayload
        : (iPayload['SourceSystem'] as Map<String, dynamic>?) ?? {};

    // Resolve user's authentic company details
    final sellerProfile = await _resolveSellerProfile(
      seller,
      sysSys,
      cashierOverride: rPayload['Cashier']?.toString(),
      override: companyOverride,
    );

    // Typography
    final double headerTinSize = is80mm ? 13 : 11;
    final double shopNameSize = is80mm ? 11 : 9.5;
    final double titleSize = is80mm ? 9.5 : 8.2;
    final double bodySize = is80mm ? 7.5 : 6.4;
    final double totalSize = is80mm ? 11.5 : 9.8;
    final double qrSize = is80mm ? 130 : 98;
    final double footerSize = is80mm ? 6.5 : 5.5;

    // Load QR Image
    pw.MemoryImage? qrImage;
    try {
      final qrToUse = receipt.qr ?? invoice.signedQr;
      if (qrToUse != null && qrToUse.isNotEmpty) {
        qrImage = pw.MemoryImage(base64Decode(qrToUse));
      }
    } catch (_) {}

    final receiptNumber = _n(
      rPayload['ReceiptNumber'] ?? receipt.receiptNumber ?? receipt.id?.toString(),
      'REC-001',
    );
    final rrn = _n(rPayload['RRN'] ?? receipt.rrn, '');
    final invoiceIrn = _n(invoice.irn ?? receipt.invoiceIrn, '');
    final rawDateStr = _n(rPayload['ReceiptDate'] ?? receipt.createdAt ?? invoice.createdAt);
    String formattedDate = 'N/A';
    try {
      final dt = DateTime.parse(rawDateStr).toLocal();
      formattedDate = DateFormat('dd/MM/yyyy, h:mm:ss a').format(dt);
    } catch (_) {
      formattedDate = rawDateStr;
    }

    final invoiceDocNo = _n(invoice.documentNumber ?? iPayload['DocumentNumber'] ?? invoice.id.toString(), 'N/A');
    final invoiceDate = _n(invoice.createdAt ?? iPayload['IssueDateTime'], formattedDate);
    final buyerName = _n(buyer['LegalName'] ?? buyer['TradeName'] ?? invoice.buyer.legalName, 'Taxpayer P');
    final invoiceTotal = _fmt(invoice.totals.totalValue);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          if (checkWithholding) {
            // ──────────────── WITHHOLDING TAX RECEIPT ────────────────
            final wDetail = (rPayload['WithholdDetail'] as Map<String, dynamic>?) ?? {};
            
            // In Withholding Receipt, Withholding Agent (Buyer who deducted the tax) is the issuer
            String companyTin = _n(rPayload['BuyerTIN'] ?? buyer['Tin'] ?? buyer['TIN'], '');
            if (companyTin.isEmpty || companyTin == 'N/A' || companyTin == '0079140416') {
              companyTin = sellerProfile.tin;
            }

            String companyName = _n(buyer['LegalName'] ?? buyer['TradeName'], '');
            if (companyName.isEmpty || companyName == 'N/A' || companyName.contains('SantimPay')) {
              companyName = sellerProfile.name;
            }

            String companyVat = _n(buyer['VatRegistrationNumber'] ?? buyer['VatNumber'], '');
            if (companyVat.isEmpty || companyVat == 'N/A') {
              companyVat = sellerProfile.vat;
            }

            final preTaxAmount = _fmt(wDetail['InvoiceAmountExclTax'] ?? wDetail['PreTaxAmount'] ?? invoice.totals.totalValue);
            final withHeldAmount = _fmt(
              wDetail['WithholdingAmount'] ??
                  wDetail['IncomeWithholdValue'] ??
                  rPayload['CollectedAmount'],
            );

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Text(
                    companyTin,
                    style: pw.TextStyle(fontSize: headerTinSize, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    companyName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: shopNameSize, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                if (companyVat.isNotEmpty)
                  pw.Center(
                    child: pw.Text('VAT: $companyVat', style: pw.TextStyle(fontSize: bodySize)),
                  ),
                _dashedLine(),

                pw.Center(
                  child: pw.Text(
                    'ከተከፋይ ሂሳብ ላይ ለተቀነሰ ግብር የተሰጠ ደረሰኝ',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: titleSize, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    '(Withholding tax on payment)',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: titleSize - 0.5, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'ዓይነት / Withheld Type TWTH',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: bodySize),
                  ),
                ),
                _solidLine(),

                _buildMetaRow('Receipt No.:', receiptNumber, bodySize),
                _buildMetaRow('Date:', formattedDate, bodySize),
                _dashedLine(),

                _buildMetaRow('Invoice No.:', invoiceDocNo, bodySize),
                _buildMetaRow('Invoice Date:', invoiceDate, bodySize),
                _buildMetaRow('Invoice Total:', invoiceTotal, bodySize),
                if (invoiceIrn.isNotEmpty) ...[
                  pw.Text('Invoice IRN:', style: pw.TextStyle(fontSize: bodySize, fontWeight: pw.FontWeight.bold)),
                  pw.Text(invoiceIrn, style: pw.TextStyle(fontSize: footerSize)),
                  pw.SizedBox(height: 2),
                ],
                _dashedLine(),

                _buildMetaRow('Type', 'Transaction', bodySize),
                _buildSummaryRow('Pre-Tax Amount', preTaxAmount, bodySize),
                _solidLine(thickness: 0.8),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Withholding', style: pw.TextStyle(fontSize: totalSize, fontWeight: pw.FontWeight.bold)),
                    pw.Text(withHeldAmount, style: pw.TextStyle(fontSize: totalSize, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                _solidLine(thickness: 0.8),
                pw.SizedBox(height: 6),

                // QR Code
                pw.Center(
                  child: pw.Container(
                    width: qrSize,
                    height: qrSize,
                    child: qrImage != null
                        ? pw.Image(qrImage, fit: pw.BoxFit.contain)
                        : (rrn.isNotEmpty && rrn != 'N/A'
                            ? pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: rrn)
                            : (invoiceIrn.isNotEmpty
                                ? pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: invoiceIrn)
                                : pw.SizedBox())),
                  ),
                ),
                pw.SizedBox(height: 6),

                if (rrn.isNotEmpty && rrn != 'N/A') ...[
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text('RRN:-', style: pw.TextStyle(fontSize: footerSize, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Text(rrn, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: footerSize - 0.5)),
                  pw.SizedBox(height: 2),
                ],
                _dashedLine(),

                _buildSummaryRow('Serial No.:', sellerProfile.serialNo, footerSize),
                _dashedLine(),

                pw.Center(
                  child: pw.Text(
                    'Powered by Deresegn',
                    style: pw.TextStyle(fontSize: footerSize, fontStyle: pw.FontStyle.italic),
                  ),
                ),
                pw.SizedBox(height: 8),
              ],
            );
          } else {
            // ──────────────── SALES RECEIPT VOUCHER (User's Company is the Seller Issuer) ────────────────
            final collectedAmount = _fmt(rPayload['CollectedAmount'] ?? receipt.morId ?? invoice.totals.totalValue);
            final paymentMode = _n(rPayload['TransactionDetails']?['PaymentMethod'] ?? 'CASH', 'CASH');

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Text(
                    sellerProfile.tin,
                    style: pw.TextStyle(fontSize: headerTinSize, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    sellerProfile.name,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: shopNameSize, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                if (sellerProfile.vat.isNotEmpty)
                  pw.Center(
                    child: pw.Text('VAT: ${sellerProfile.vat}', style: pw.TextStyle(fontSize: bodySize)),
                  ),
                _dashedLine(),

                pw.Center(
                  child: pw.Text(
                    'የገንዘብ መቀበያ / Sales Receipt Voucher',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: titleSize, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                _solidLine(),

                _buildMetaRow('Receipt No.:', receiptNumber, bodySize),
                _buildMetaRow('Date:', formattedDate, bodySize),
                _buildMetaRow('Cashier:', sellerProfile.cashier, bodySize),
                _dashedLine(),

                _buildMetaRow('Invoice No.:', invoiceDocNo, bodySize),
                _buildMetaRow('Invoice Date:', invoiceDate, bodySize),
                _buildMetaRow('Buyer:', buyerName, bodySize),
                _buildMetaRow('Invoice Total:', invoiceTotal, bodySize),
                if (invoiceIrn.isNotEmpty) ...[
                  pw.Text('Invoice IRN:', style: pw.TextStyle(fontSize: bodySize, fontWeight: pw.FontWeight.bold)),
                  pw.Text(invoiceIrn, style: pw.TextStyle(fontSize: footerSize)),
                  pw.SizedBox(height: 2),
                ],
                _dashedLine(),

                _solidLine(thickness: 0.8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Amount', style: pw.TextStyle(fontSize: totalSize, fontWeight: pw.FontWeight.bold)),
                    pw.Text(collectedAmount, style: pw.TextStyle(fontSize: totalSize, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                _solidLine(thickness: 0.8),
                _buildSummaryRow('Payment Mode', paymentMode, bodySize),
                pw.SizedBox(height: 6),

                // QR Code
                pw.Center(
                  child: pw.Container(
                    width: qrSize,
                    height: qrSize,
                    child: qrImage != null
                        ? pw.Image(qrImage, fit: pw.BoxFit.contain)
                        : (rrn.isNotEmpty && rrn != 'N/A'
                            ? pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: rrn)
                            : (invoiceIrn.isNotEmpty
                                ? pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: invoiceIrn)
                                : pw.SizedBox())),
                  ),
                ),
                pw.SizedBox(height: 6),

                if (rrn.isNotEmpty && rrn != 'N/A') ...[
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text('RRN:-', style: pw.TextStyle(fontSize: footerSize, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Text(rrn, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: footerSize - 0.5)),
                  pw.SizedBox(height: 2),
                ],
                _dashedLine(),

                _buildSummaryRow('Serial No.:', sellerProfile.serialNo, footerSize),
                _dashedLine(),

                pw.Center(
                  child: pw.Text(
                    'Powered by Deresegn',
                    style: pw.TextStyle(fontSize: footerSize, fontStyle: pw.FontStyle.italic),
                  ),
                ),
                pw.SizedBox(height: 8),
              ],
            );
          }
        },
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────
  // Helper Widgets
  // ─────────────────────────────────────────────────────────────
  static pw.Widget _buildMetaRow(String label, String value, double fontSize, {bool isRef = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
      child: isRef
          ? pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
                pw.Text(value, style: pw.TextStyle(fontSize: fontSize)),
              ],
            )
          : pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label, style: pw.TextStyle(fontSize: fontSize, color: PdfColors.grey800)),
                pw.SizedBox(width: 4),
                pw.Expanded(
                  child: pw.Text(
                    value,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value, double fontSize) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize)),
          pw.Text(value, style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
