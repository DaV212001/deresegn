import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:deresegn/models/invoice_history_model.dart';
import 'package:deresegn/models/receipt_models.dart';
import 'package:deresegn/services/invoice_pdf_service.dart';
import 'package:deresegn/services/receipt_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generate All MoR Sample PDFs for Compliance Audit', () async {
    final outputDir = Directory('MoR_Sample_PDFs');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final brainDir = Directory(r'C:\Users\Abel Seyoum\.gemini\antigravity\brain\26b61b0e-99cd-4f55-8978-247c0dab3e00');
    if (!await brainDir.exists()) {
      await brainDir.create(recursive: true);
    }

    // Common Seller Details (Micro Sun & Solution PLC)
    final sellerDetails = {
      'LegalName': 'Micro Sun & Solution PLC',
      'TradeName': 'Deresegn POS & Cloud Invoicing',
      'Tin': '0012345678',
      'VatNumber': '432566633432',
      'Vrn': '432566633432',
      'City': 'Addis Ababa',
      'Zone': 'Kirkos Sub City',
      'Wereda': 'Woreda 02',
      'Woreda': 'Woreda 02',
      'Kebele': '03',
      'HouseNo': '501',
      'Phone': '+251 91 105 8179',
      'Email': 'contact@deresegn.com',
    };

    final sourceSystem = {
      'SystemType': 'POS',
      'SystemNumber': '23C4A8817B',
      'CashierName': 'Abebe Bikila',
    };

    // Helper to save files to both MoR_Sample_PDFs and brain dir
    Future<void> savePdf(String filename, Uint8List bytes) async {
      final file1 = File('${outputDir.path}/$filename');
      await file1.writeAsBytes(bytes);
      try {
        final file2 = File('${brainDir.path}/$filename');
        await file2.writeAsBytes(bytes);
      } catch (_) {}
      print('Saved: ${file1.path} (${bytes.length} bytes)');
    }

    // =========================================================================
    // CASE 1: Cash Sales Invoice (Standard VAT 15%)
    // =========================================================================
    final case1Invoice = InvoiceSummary(
      id: 101,
      documentNumber: 'INV-2026-00101',
      irn: 'IRN-0012345678-20260928-CSH01',
      status: 'A',
      transactionType: 'B2C',
      createdAt: '2026-09-28T09:15:00Z',
      buyer: BuyerInfo(
        legalName: 'Ethio Agri-CEFT PLC',
        tin: '0048123901',
        phone: '+251 91 123 4567',
        email: 'sales@ethioagriceft.et',
        city: 'Addis Ababa',
        region: 'Addis Ababa',
      ),
      totals: TotalsInfo(
        totalValue: '16100.00',
        taxValue: '2100.00',
        discount: '0.00',
        exciseValue: '0.00',
        currency: 'ETB',
      ),
      requestPayload: {
        'SellerDetails': sellerDetails,
        'BuyerDetails': {
          'LegalName': 'Ethio Agri-CEFT PLC',
          'Name': 'Ethio Agri-CEFT PLC',
          'Tin': '0048123901',
          'VatNumber': '123456789012',
          'Vrn': '123456789012',
          'City': 'Addis Ababa',
          'Zone': 'Bole Sub City',
          'Wereda': 'Woreda 03',
          'Kebele': '05',
          'HouseNo': '204',
          'Phone': '+251 91 123 4567',
          'Email': 'sales@ethioagriceft.et',
        },
        'DocumentDetails': {
          'DocumentNumber': 'INV-2026-00101',
          'Date': '28-09-2026 09:15',
          'Type': 'INV',
          'Reason': 'Sales Invoice',
        },
        'PaymentDetails': {
          'Mode': 'CASH',
          'PaymentTerm': 'CASH',
        },
        'SourceSystem': sourceSystem,
        'ItemList': [
          {
            'ProductDescription': 'POS Thermal Receipt Printer 80mm USB/LAN',
            'NatureOfSupplies': 'goods',
            'Unit': 'PCS',
            'Quantity': '2.00',
            'UnitPrice': '5000.00',
            'TaxCode': 'VAT15',
            'ExciseTaxValue': '0.00',
            'Discount': '0.00',
            'TaxAmount': '1500.00',
            'TotalLineAmount': '11500.00',
          },
          {
            'ProductDescription': 'Omnidirectional 2D Barcode Scanner Hands-Free',
            'NatureOfSupplies': 'goods',
            'Unit': 'PCS',
            'Quantity': '1.00',
            'UnitPrice': '4000.00',
            'TaxCode': 'VAT15',
            'ExciseTaxValue': '0.00',
            'Discount': '0.00',
            'TaxAmount': '600.00',
            'TotalLineAmount': '4600.00',
          },
        ],
        'ValueDetails': {
          'TotalAmount': '14000.00',
          'TaxableAmount': '14000.00',
          'TaxValue': '2100.00',
          'Discount': '0.00',
          'ExciseValue': '0.00',
          'NonTaxableAmount': '0.00',
          'TotalValue': '16100.00',
        },
      },
    );
    final case1Bytes = await InvoicePdfService.generate(case1Invoice);
    await savePdf('01_Cash_Sales_Invoice_VAT15.pdf', case1Bytes);

    // =========================================================================
    // CASE 2: Credit Sales Invoice (VAT 15%)
    // =========================================================================
    final case2Invoice = InvoiceSummary(
      id: 102,
      documentNumber: 'INV-2026-00102',
      irn: 'IRN-0076543210-20260928-CRD02',
      status: 'A',
      transactionType: 'B2B',
      createdAt: '2026-09-28T10:00:00Z',
      buyer: BuyerInfo(
        legalName: 'Bole Towers Real Estate SC',
        tin: '0076543210',
        phone: '+251 91 765 4321',
        email: 'finance@boletowers.et',
        city: 'Addis Ababa',
        region: 'Addis Ababa',
      ),
      totals: TotalsInfo(
        totalValue: '52900.00',
        taxValue: '6900.00',
        discount: '0.00',
        exciseValue: '0.00',
        currency: 'ETB',
      ),
      requestPayload: {
        'SellerDetails': sellerDetails,
        'BuyerDetails': {
          'LegalName': 'Bole Towers Real Estate SC',
          'Name': 'Bole Towers Real Estate SC',
          'Tin': '0076543210',
          'VatNumber': '887766554433',
          'Vrn': '887766554433',
          'City': 'Addis Ababa',
          'Zone': 'Bole Sub City',
          'Wereda': 'Woreda 04',
          'Kebele': '08',
          'HouseNo': '120',
          'Phone': '+251 91 765 4321',
          'Email': 'finance@boletowers.et',
        },
        'DocumentDetails': {
          'DocumentNumber': 'INV-2026-00102',
          'Date': '28-09-2026 10:00',
          'Type': 'INV',
          'Reason': 'Sales Invoice',
        },
        'PaymentDetails': {
          'Mode': 'CREDIT',
          'PaymentTerm': 'CREDIT',
        },
        'SourceSystem': sourceSystem,
        'ItemList': [
          {
            'ProductDescription': 'Enterprise Cloud ERP Annual Subscription License',
            'NatureOfSupplies': 'service',
            'Unit': 'YR',
            'Quantity': '1.00',
            'UnitPrice': '30000.00',
            'TaxCode': 'VAT15',
            'ExciseTaxValue': '0.00',
            'Discount': '0.00',
            'TaxAmount': '4500.00',
            'TotalLineAmount': '34500.00',
          },
          {
            'ProductDescription': 'Biometric Attendance & Access Terminal Hardware',
            'NatureOfSupplies': 'goods',
            'Unit': 'PCS',
            'Quantity': '2.00',
            'UnitPrice': '8000.00',
            'TaxCode': 'VAT15',
            'ExciseTaxValue': '0.00',
            'Discount': '0.00',
            'TaxAmount': '2400.00',
            'TotalLineAmount': '18400.00',
          },
        ],
        'ValueDetails': {
          'TotalAmount': '46000.00',
          'TaxableAmount': '46000.00',
          'TaxValue': '6900.00',
          'Discount': '0.00',
          'ExciseValue': '0.00',
          'NonTaxableAmount': '0.00',
          'TotalValue': '52900.00',
        },
      },
    );
    final case2Bytes = await InvoicePdfService.generate(case2Invoice);
    await savePdf('02_Credit_Sales_Invoice_VAT15.pdf', case2Bytes);

    // =========================================================================
    // CASE 3: Mixed Tax Rates (VAT 15%, Exempt, and 0% Zero-Rated)
    // =========================================================================
    final case3Invoice = InvoiceSummary(
      id: 103,
      documentNumber: 'INV-2026-00103',
      irn: 'IRN-0055443322-20260928-MIX03',
      status: 'A',
      transactionType: 'B2B',
      createdAt: '2026-09-28T10:45:00Z',
      buyer: BuyerInfo(
        legalName: 'St. Paul Hospital Millennium Medical College',
        tin: '0055443322',
        phone: '+251 11 275 0125',
        email: 'procurement@sphmmc.edu.et',
        city: 'Addis Ababa',
        region: 'Addis Ababa',
      ),
      totals: TotalsInfo(
        totalValue: '29500.00',
        taxValue: '1500.00',
        discount: '0.00',
        exciseValue: '0.00',
        currency: 'ETB',
      ),
      requestPayload: {
        'SellerDetails': sellerDetails,
        'BuyerDetails': {
          'LegalName': 'St. Paul Hospital Millennium Medical College',
          'Name': 'St. Paul Hospital Millennium Medical College',
          'Tin': '0055443322',
          'VatNumber': '998877665544',
          'Vrn': '998877665544',
          'City': 'Addis Ababa',
          'Zone': 'Gullele Sub City',
          'Wereda': 'Woreda 01',
          'Kebele': '02',
          'HouseNo': '45',
          'Phone': '+251 11 275 0125',
          'Email': 'procurement@sphmmc.edu.et',
        },
        'DocumentDetails': {
          'DocumentNumber': 'INV-2026-00103',
          'Date': '28-09-2026 10:45',
          'Type': 'INV',
          'Reason': 'Sales Invoice',
        },
        'PaymentDetails': {
          'Mode': 'BANK TRANSFER',
          'PaymentTerm': 'CASH',
        },
        'SourceSystem': sourceSystem,
        'ItemList': [
          {
            'ProductDescription': 'Ultrasound Diagnostic Machine Calibration & Maintenance',
            'NatureOfSupplies': 'service',
            'Unit': 'SRV',
            'Quantity': '1.00',
            'UnitPrice': '10000.00',
            'TaxCode': 'VAT15',
            'ExciseTaxValue': '0.00',
            'Discount': '0.00',
            'TaxAmount': '1500.00',
            'TotalLineAmount': '11500.00',
          },
          {
            'ProductDescription': 'Essential Prescription Antibiotics & Hospital Supplies (Exempt)',
            'NatureOfSupplies': 'goods',
            'Unit': 'BOX',
            'Quantity': '50.00',
            'UnitPrice': '200.00',
            'TaxCode': 'VATEX',
            'ExciseTaxValue': '0.00',
            'Discount': '0.00',
            'TaxAmount': '0.00',
            'TotalLineAmount': '10000.00',
          },
          {
            'ProductDescription': 'Specialized Medical Reagents for Export Research (Zero-Rated)',
            'NatureOfSupplies': 'goods',
            'Unit': 'KIT',
            'Quantity': '20.00',
            'UnitPrice': '400.00',
            'TaxCode': 'VAT0',
            'ExciseTaxValue': '0.00',
            'Discount': '0.00',
            'TaxAmount': '0.00',
            'TotalLineAmount': '8000.00',
          },
        ],
        'ValueDetails': {
          'TotalAmount': '28000.00',
          'TaxableAmount': '10000.00',
          'TaxValue': '1500.00',
          'Discount': '0.00',
          'ExciseValue': '0.00',
          'NonTaxableAmount': '18000.00',
          'TotalValue': '29500.00',
        },
      },
    );
    final case3Bytes = await InvoicePdfService.generate(case3Invoice);
    await savePdf('03_Sales_Invoice_VAT15_Exempt_ZeroRated.pdf', case3Bytes);

    // =========================================================================
    // CASE 4: Discount & Excise Tax (ኤክሳይስ ታክስ)
    // =========================================================================
    final case4Invoice = InvoiceSummary(
      id: 104,
      documentNumber: 'INV-2026-00104',
      irn: 'IRN-0019283746-20260928-EXC04',
      status: 'A',
      transactionType: 'B2B',
      createdAt: '2026-09-28T11:20:00Z',
      buyer: BuyerInfo(
        legalName: 'Sheraton Addis Luxury Collection Hotel',
        tin: '0019283746',
        phone: '+251 11 517 1717',
        email: 'finance@sheratonaddis.com',
        city: 'Addis Ababa',
        region: 'Addis Ababa',
      ),
      totals: TotalsInfo(
        totalValue: '52641.25',
        taxValue: '6866.25',
        discount: '1000.00',
        exciseValue: '8775.00',
        currency: 'ETB',
      ),
      requestPayload: {
        'SellerDetails': sellerDetails,
        'BuyerDetails': {
          'LegalName': 'Sheraton Addis Luxury Collection Hotel',
          'Name': 'Sheraton Addis Luxury Collection Hotel',
          'Tin': '0019283746',
          'VatNumber': '334455667788',
          'Vrn': '334455667788',
          'City': 'Addis Ababa',
          'Zone': 'Kirkos Sub City',
          'Wereda': 'Woreda 03',
          'Kebele': '01',
          'HouseNo': 'P.O.Box 6002',
          'Phone': '+251 11 517 1717',
          'Email': 'finance@sheratonaddis.com',
        },
        'DocumentDetails': {
          'DocumentNumber': 'INV-2026-00104',
          'Date': '28-09-2026 11:20',
          'Type': 'INV',
          'Reason': 'Sales Invoice',
        },
        'PaymentDetails': {
          'Mode': 'TELEBIRR',
          'PaymentTerm': 'CASH',
        },
        'SourceSystem': sourceSystem,
        'ItemList': [
          {
            'ProductDescription': 'Premium Imported Tobacco Cigars (30% Excise Rate)',
            'NatureOfSupplies': 'goods',
            'Unit': 'BOX',
            'Quantity': '10.00',
            'UnitPrice': '2000.00',
            'TaxCode': 'VAT15',
            'ExciseTaxValue': '5850.00',
            'Discount': '500.00',
            'TaxAmount': '3802.50',
            'TotalLineAmount': '29152.50',
          },
          {
            'ProductDescription': 'Sparkling Fruit Beverage & Energy Drinks (25% Excise Rate)',
            'NatureOfSupplies': 'goods',
            'Unit': 'CRT',
            'Quantity': '20.00',
            'UnitPrice': '600.00',
            'TaxCode': 'VAT15',
            'ExciseTaxValue': '2925.00',
            'Discount': '300.00',
            'TaxAmount': '2193.75',
            'TotalLineAmount': '16818.75',
          },
          {
            'ProductDescription': 'Branded Luxury Glass Tumbler Set 6-Piece',
            'NatureOfSupplies': 'goods',
            'Unit': 'SET',
            'Quantity': '15.00',
            'UnitPrice': '400.00',
            'TaxCode': 'VAT15',
            'ExciseTaxValue': '0.00',
            'Discount': '200.00',
            'TaxAmount': '870.00',
            'TotalLineAmount': '6670.00',
          },
        ],
        'ValueDetails': {
          'TotalAmount': '38000.00',
          'Discount': '1000.00',
          'ExciseValue': '8775.00',
          'TaxableAmount': '45775.00',
          'TaxValue': '6866.25',
          'NonTaxableAmount': '0.00',
          'TotalValue': '52641.25',
        },
      },
    );
    final case4Bytes = await InvoicePdfService.generate(case4Invoice);
    await savePdf('04_Sales_Invoice_Discount_and_Excise.pdf', case4Bytes);

    // =========================================================================
    // CASE 5: Tax Credit Note (ክሬዲት ኖት)
    // =========================================================================
    final case5Invoice = InvoiceSummary(
      id: 105,
      documentNumber: 'CN-2026-00045',
      irn: 'IRN-0012345678-20260928-CN0005',
      status: 'A',
      transactionType: 'B2B',
      createdAt: '2026-09-28T12:00:00Z',
      buyer: BuyerInfo(
        legalName: 'Ethio Agri-CEFT PLC',
        tin: '0048123901',
        phone: '+251 91 123 4567',
        email: 'sales@ethioagriceft.et',
        city: 'Addis Ababa',
        region: 'Addis Ababa',
      ),
      totals: TotalsInfo(
        totalValue: '5750.00',
        taxValue: '750.00',
        discount: '0.00',
        exciseValue: '0.00',
        currency: 'ETB',
      ),
      requestPayload: {
        'SellerDetails': sellerDetails,
        'BuyerDetails': {
          'LegalName': 'Ethio Agri-CEFT PLC',
          'Name': 'Ethio Agri-CEFT PLC',
          'Tin': '0048123901',
          'VatNumber': '123456789012',
          'Vrn': '123456789012',
          'City': 'Addis Ababa',
          'Zone': 'Bole Sub City',
          'Wereda': 'Woreda 03',
          'Kebele': '05',
          'HouseNo': '204',
          'Phone': '+251 91 123 4567',
          'Email': 'sales@ethioagriceft.et',
        },
        'DocumentDetails': {
          'DocumentNumber': 'CN-2026-00045',
          'Date': '28-09-2026 12:00',
          'Type': 'CN',
          'Reason': 'Defective Goods Returned by Buyer',
        },
        'PaymentDetails': {
          'Mode': 'CREDIT',
          'PaymentTerm': 'CREDIT',
        },
        'ReferenceDetails': {
          'PreviousIrn': 'IRN-0012345678-20260928-CSH01',
          'RelatedDocument': 'INV-2026-00101',
        },
        'SourceSystem': sourceSystem,
        'ItemList': [
          {
            'ProductDescription': 'POS Thermal Receipt Printer 80mm (Defective Unit Returned)',
            'NatureOfSupplies': 'goods',
            'Unit': 'PCS',
            'Quantity': '1.00',
            'UnitPrice': '5000.00',
            'TaxCode': 'VAT15',
            'ExciseTaxValue': '0.00',
            'Discount': '0.00',
            'TaxAmount': '750.00',
            'TotalLineAmount': '5750.00',
          },
        ],
        'ValueDetails': {
          'TotalAmount': '5000.00',
          'TaxableAmount': '5000.00',
          'TaxValue': '750.00',
          'Discount': '0.00',
          'ExciseValue': '0.00',
          'NonTaxableAmount': '0.00',
          'TotalValue': '5750.00',
        },
      },
    );
    final case5Bytes = await InvoicePdfService.generate(case5Invoice);
    await savePdf('05_Tax_Credit_Note.pdf', case5Bytes);

    // =========================================================================
    // CASE 6: Tax Debit Note (ዴቢት ኖት)
    // =========================================================================
    final case6Invoice = InvoiceSummary(
      id: 106,
      documentNumber: 'DN-2026-00028',
      irn: 'IRN-0076543210-20260928-DN0006',
      status: 'A',
      transactionType: 'B2B',
      createdAt: '2026-09-28T12:30:00Z',
      buyer: BuyerInfo(
        legalName: 'Bole Towers Real Estate SC',
        tin: '0076543210',
        phone: '+251 91 765 4321',
        email: 'finance@boletowers.et',
        city: 'Addis Ababa',
        region: 'Addis Ababa',
      ),
      totals: TotalsInfo(
        totalValue: '9200.00',
        taxValue: '1200.00',
        discount: '0.00',
        exciseValue: '0.00',
        currency: 'ETB',
      ),
      requestPayload: {
        'SellerDetails': sellerDetails,
        'BuyerDetails': {
          'LegalName': 'Bole Towers Real Estate SC',
          'Name': 'Bole Towers Real Estate SC',
          'Tin': '0076543210',
          'VatNumber': '887766554433',
          'Vrn': '887766554433',
          'City': 'Addis Ababa',
          'Zone': 'Bole Sub City',
          'Wereda': 'Woreda 04',
          'Kebele': '08',
          'HouseNo': '120',
          'Phone': '+251 91 765 4321',
          'Email': 'finance@boletowers.et',
        },
        'DocumentDetails': {
          'DocumentNumber': 'DN-2026-00028',
          'Date': '28-09-2026 12:30',
          'Type': 'DN',
          'Reason': 'Underbilled Quantity Price Adjustment',
        },
        'PaymentDetails': {
          'Mode': 'CREDIT',
          'PaymentTerm': 'CREDIT',
        },
        'ReferenceDetails': {
          'PreviousIrn': 'IRN-0076543210-20260928-CRD02',
          'RelatedDocument': 'INV-2026-00102',
        },
        'SourceSystem': sourceSystem,
        'ItemList': [
          {
            'ProductDescription': 'Additional Biometric Terminal (Unbilled Quantity Correction)',
            'NatureOfSupplies': 'goods',
            'Unit': 'PCS',
            'Quantity': '1.00',
            'UnitPrice': '8000.00',
            'TaxCode': 'VAT15',
            'ExciseTaxValue': '0.00',
            'Discount': '0.00',
            'TaxAmount': '1200.00',
            'TotalLineAmount': '9200.00',
          },
        ],
        'ValueDetails': {
          'TotalAmount': '8000.00',
          'TaxableAmount': '8000.00',
          'TaxValue': '1200.00',
          'Discount': '0.00',
          'ExciseValue': '0.00',
          'NonTaxableAmount': '0.00',
          'TotalValue': '9200.00',
        },
      },
    );
    final case6Bytes = await InvoicePdfService.generate(case6Invoice);
    await savePdf('06_Tax_Debit_Note.pdf', case6Bytes);

    // =========================================================================
    // CASE 7: Cash Receipt Voucher (CRB) - Full Payment
    // =========================================================================
    final case7Receipt = ReceiptSummary(
      id: 201,
      receiptNumber: 'CRV-2026-00981',
      rrn: 'RRN-0012345678-20260928-CRB01',
      invoiceIrn: 'IRN-0012345678-20260928-CSH01',
      status: 'A',
      createdAt: '2026-09-28T09:30:00Z',
      requestPayload: {
        'ReceiptNumber': 'CRV-2026-00981',
        'RRN': 'RRN-0012345678-20260928-CRB01',
        'ReceiptDate': '28-09-2026 09:30',
        'ReceiptCounter': '1',
        'Reason': 'Payment for goods purchased',
        'ReceiptType': 'CRB',
        'SourceSystemType': 'POS',
        'SourceSystemNumber': '23C4A8817B',
        'ReceiptCurrency': 'ETB',
        'CollectedAmount': '16100.00',
        'TransactionDetails': {
          'ModeOfPayment': 'CASH',
        },
        'Invoices': [
          {
            'InvoiceIRN': 'IRN-0012345678-20260928-CSH01',
            'PaymentCoverage': 'FULL',
            'TotalAmount': '16100.00',
            'RemainingAmount': '0.00',
            'InvoicePaidAmount': '16100.00',
          },
        ],
      },
    );
    final case7Bytes = await ReceiptPdfService.generate(case7Receipt, case1Invoice);
    await savePdf('07_Cash_Receipt_Voucher_CRB_Full.pdf', case7Bytes);

    // =========================================================================
    // CASE 8: Cash Receipt Voucher (CRB) - Partial Payment
    // =========================================================================
    final case8Receipt = ReceiptSummary(
      id: 202,
      receiptNumber: 'CRV-2026-00982',
      rrn: 'RRN-0076543210-20260928-CRB02',
      invoiceIrn: 'IRN-0076543210-20260928-CRD02',
      status: 'A',
      createdAt: '2026-09-28T10:30:00Z',
      requestPayload: {
        'ReceiptNumber': 'CRV-2026-00982',
        'RRN': 'RRN-0076543210-20260928-CRB02',
        'ReceiptDate': '28-09-2026 10:30',
        'ReceiptCounter': '1',
        'Reason': 'Partial installment payment on Credit Invoice',
        'ReceiptType': 'CRB',
        'SourceSystemType': 'POS',
        'SourceSystemNumber': '23C4A8817B',
        'ReceiptCurrency': 'ETB',
        'CollectedAmount': '30000.00',
        'TransactionDetails': {
          'ModeOfPayment': 'BANK TRANSFER / TELEBIRR',
        },
        'Invoices': [
          {
            'InvoiceIRN': 'IRN-0076543210-20260928-CRD02',
            'PaymentCoverage': 'PARTIAL',
            'TotalAmount': '52900.00',
            'RemainingAmount': '22900.00',
            'InvoicePaidAmount': '30000.00',
          },
        ],
      },
    );
    final case8Bytes = await ReceiptPdfService.generate(case8Receipt, case2Invoice);
    await savePdf('08_Cash_Receipt_Voucher_CRB_Partial.pdf', case8Bytes);

    // =========================================================================
    // CASE 9: Withholding Tax Receipt (TWTH)
    // =========================================================================
    final case9Receipt = ReceiptSummary(
      id: 203,
      receiptNumber: 'WH-26-908123456',
      invoiceIrn: 'IRN-0076543210-20260928-CRD02',
      status: 'A',
      createdAt: '2026-09-28T11:00:00Z',
      requestPayload: {
        'ReceiptNumber': 'WH-26-908123456',
        'ReceiptCounter': '908123456',
        'ReceiptDate': '28-09-2026 11:00',
        'Reason': 'Tax Withholding',
        'ReceiptType': 'TWTH',
        'SourceSystemType': 'POS',
        'SourceSystemNumber': '23C4A8817B',
        'ReceiptCurrency': 'ETB',
        'InvoiceDetail': {
          'InvoiceDocNumber': 'INV-2026-00102',
          'Currency': 'ETB',
        },
        'WithholdDetail': {
          'Type': 'TWTH',
          'PreTaxAmount': '46000.00',
          'WithholdingAmount': '920.00',
          'IncomeWithholdValue': '920.00',
          'TransactionWithholdValue': '0.00',
        },
      },
    );
    final case9Bytes = await ReceiptPdfService.generate(case9Receipt, case2Invoice, isWithholding: true);
    await savePdf('09_Withholding_Tax_Receipt.pdf', case9Bytes);

    // =========================================================================
    // CASE 10: Consolidated MoR Audit Submission Package (Merged PDF Document)
    // =========================================================================
    final mergedPdfTheme = await InvoicePdfService.loadPdfTheme();
    final combinedPdf = pw.Document(theme: mergedPdfTheme);

    // Add Cover Page for MoR Submission
    combinedPdf.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
        ),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFF0D253A),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'MICRO SUN & SOLUTION PLC',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Deresegn POS & Cloud E-Invoicing System',
                      style: const pw.TextStyle(
                        fontSize: 13,
                        color: PdfColor.fromInt(0xFFFAA61A),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 28),
              pw.Text(
                'MINISTRY OF REVENUES (MoR) FISCAL COMPLIANCE',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF0D253A),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Complete Fiscal PDF Demonstration Package',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 24),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFCCCCCC), width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                  color: const PdfColor.fromInt(0xFFF9FBFF),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Index of MoR Test Cases Included in this Document:',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0D253A)),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text('1. Cash Sales VAT/Excise Tax Invoice (Standard VAT 15%)', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.SizedBox(height: 4),
                    pw.Text('2. Credit Sales VAT/Excise Tax Invoice (B2B Credit Sale)', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.SizedBox(height: 4),
                    pw.Text('3. Mixed Tax Rates Invoice (VAT 15%, VAT Exempt, and VAT 0% Zero-Rated)', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.SizedBox(height: 4),
                    pw.Text('4. Discount & Excise Tax Invoice (Commercial Discount & Excise Breakdown)', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.SizedBox(height: 4),
                    pw.Text('5. Tax Credit Note (Return of Goods / Adjustment referencing original IRN)', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.SizedBox(height: 4),
                    pw.Text('6. Tax Debit Note (Price / Quantity Adjustment referencing original IRN)', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.SizedBox(height: 4),
                    pw.Text('7. Cash Receipt Voucher (CRB) - Full Payment Settlement', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.SizedBox(height: 4),
                    pw.Text('8. Cash Receipt Voucher (CRB) - Partial Payment Settlement', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.SizedBox(height: 4),
                    pw.Text('9. Withholding Tax on Payment Receipt (TWTH 2% Income Withholding)', style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Applicant TIN: 0012345678', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text('VAT Reg. No: 432566633432', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('System Type: POS & Cloud ERP', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Certification Standard: MoR Proclamation 285/2002', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Excise Proclamation: 1186/2020', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Submission Date: September 2026', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Append each document into the combined package
    await InvoicePdfService.generateIntoDocument(combinedPdf, case1Invoice);
    await InvoicePdfService.generateIntoDocument(combinedPdf, case2Invoice);
    await InvoicePdfService.generateIntoDocument(combinedPdf, case3Invoice);
    await InvoicePdfService.generateIntoDocument(combinedPdf, case4Invoice);
    await InvoicePdfService.generateIntoDocument(combinedPdf, case5Invoice);
    await InvoicePdfService.generateIntoDocument(combinedPdf, case6Invoice);
    await ReceiptPdfService.generateIntoDocument(combinedPdf, case7Receipt, case1Invoice);
    await ReceiptPdfService.generateIntoDocument(combinedPdf, case8Receipt, case2Invoice);
    await ReceiptPdfService.generateIntoDocument(combinedPdf, case9Receipt, case2Invoice, isWithholding: true);

    final combinedBytes = await combinedPdf.save();
    await savePdf('10_MoR_All_Cases_Consolidated_Booklet.pdf', combinedBytes);

    print('All 10 MoR Sample PDFs generated successfully!');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
