import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:deresegn/models/invoice_history_model.dart';
import 'package:deresegn/services/invoice_pdf_service.dart';
import 'package:deresegn/services/invoice_history_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generate Sample Invoice PDF with Header & Footer', () async {
    final sampleInvoice = InvoiceSummary(
      id: 1001,
      documentNumber: 'INV-2026-000842',
      irn: 'IRN-9876543210-20260828-ABCDE',
      status: 'A',
      transactionType: 'B2B',
      createdAt: '2026-08-28T10:30:00Z',
      buyer: BuyerInfo(
        legalName: 'Abyssinia Trading Enterprises PLC',
        tin: '0098765432',
        phone: '+251 91 234 5678',
        email: 'finance@abyssiniatrading.et',
        city: 'Addis Ababa',
        region: 'Addis Ababa',
      ),
      totals: TotalsInfo(
        totalValue: '18500.00',
        taxValue: '2413.04',
        discount: '500.00',
        exciseValue: '0.00',
        currency: 'ETB',
      ),
      requestPayload: {
        'SellerDetails': {
          'LegalName': 'Deresegn',
          'TradeName': 'Deresegn POS & Cloud Invoicing',
          'Tin': '0012345678',
          'Vrn': 'VAT-ET-887766',
          'City': 'Addis Ababa',
          'Wereda': 'Kirkos Woreda 02',
          'Phone': '+251 91 105 8179',
          'Email': 'contact@deresegn.com',
        },
        'BuyerDetails': {
          'Name': 'Abyssinia Trading Enterprises PLC',
          'Tin': '0098765432',
          'Vrn': 'VAT-ET-112233',
          'City': 'Addis Ababa',
          'Zone': 'Bole Sub City',
          'Woreda': 'Woreda 03',
          'Kebele': '04',
          'HouseNo': '120/A',
          'PhoneNo': '+251 91 234 5678',
          'Email': 'finance@abyssiniatrading.et',
        },
        'DocumentDetails': {
          'DocumentNumber': 'INV-2026-000842',
          'Date': '2026-08-28',
          'Type': 'INV',
        },
        'PaymentDetails': {
          'Mode': 'Bank Transfer / Telebirr',
          'PaymentTerm': 'CASH',
        },
        'SourceSystem': {
          'SystemNumber': 'TERM-01-POS',
          'CashierName': 'Abebe Bikila',
        },
        'ItemList': [
          {
            'ProductDescription': 'High Precision Thermal Receipt Printer 80mm',
            'NatureOfSupplies': 'G',
            'Unit': 'PCS',
            'Quantity': '2',
            'UnitPrice': '4500.00',
            'TaxCode': 'VAT-15%',
            'ExciseTaxValue': '0.00',
            'Discount': '0.00',
            'TotalLineAmount': '9000.00',
          },
          {
            'ProductDescription': 'Wireless Barcode 2D Scanner & Stand',
            'NatureOfSupplies': 'G',
            'Unit': 'PCS',
            'Quantity': '3',
            'UnitPrice': '2500.00',
            'TaxCode': 'VAT-15%',
            'ExciseTaxValue': '0.00',
            'Discount': '500.00',
            'TotalLineAmount': '7000.00',
          },
          {
            'ProductDescription': 'Deresegn Annual Cloud ERP Integration License',
            'NatureOfSupplies': 'S',
            'Unit': 'YR',
            'Quantity': '1',
            'UnitPrice': '2500.00',
            'TaxCode': 'VAT-15%',
            'ExciseTaxValue': '0.00',
            'Discount': '0.00',
            'TotalLineAmount': '2500.00',
          },
        ],
        'ValueDetails': {
          'TotalValue': '18500.00',
          'TaxValue': '2413.04',
          'Discount': '500.00',
          'ExciseValue': '0.00',
          'TransactionWithholdValue': '0.00',
          'IncomeWithholdValue': '0.00',
        },
      },
    );

    // 1. Generate Invoice PDF
    final invoicePdfBytes = await InvoicePdfService.generate(sampleInvoice);
    try {
      await File('sample_invoice.pdf').writeAsBytes(invoicePdfBytes);
    } catch (_) {}
    await File('deresegn_sample_invoice.pdf').writeAsBytes(invoicePdfBytes);

    try {
      await File('C:/Users/Abel Seyoum/.gemini/antigravity/brain/d249dcbe-7aaa-4186-93b9-3ca2f49fd2a8/sample_invoice.pdf').writeAsBytes(invoicePdfBytes);
    } catch (_) {}

    expect(invoicePdfBytes.isNotEmpty, isTrue);
    print('Generated sample_invoice.pdf (${invoicePdfBytes.length} bytes)');

    // 2. Generate History Summary Report PDF
    final historyReportBytes = await InvoiceHistoryExportService.generateHistoryReportPdf([
      sampleInvoice,
      InvoiceSummary(
        id: 1002,
        documentNumber: 'INV-2026-000843',
        irn: 'IRN-1122334455-20260828-XYZ89',
        status: 'A',
        transactionType: 'B2C',
        createdAt: '2026-08-28T11:15:00Z',
        buyer: BuyerInfo(legalName: 'Walk-in Retail Customer', tin: null),
        totals: TotalsInfo(totalValue: '1250.00', taxValue: '163.04', currency: 'ETB'),
      ),
      InvoiceSummary(
        id: 1003,
        documentNumber: 'INV-2026-000844',
        irn: 'IRN-9988776655-20260828-CAN01',
        status: 'C',
        transactionType: 'B2C',
        createdAt: '2026-08-28T12:00:00Z',
        buyer: BuyerInfo(legalName: 'Mekonen Assefa', tin: '0033445566'),
        totals: TotalsInfo(totalValue: '3400.00', taxValue: '443.48', currency: 'ETB'),
      ),
    ]);

    try {
      await File('sample_history_report.pdf').writeAsBytes(historyReportBytes);
    } catch (_) {}
    await File('deresegn_sample_history_report.pdf').writeAsBytes(historyReportBytes);

    try {
      await File('C:/Users/Abel Seyoum/.gemini/antigravity/brain/d249dcbe-7aaa-4186-93b9-3ca2f49fd2a8/sample_history_report.pdf').writeAsBytes(historyReportBytes);
    } catch (_) {}

    expect(historyReportBytes.isNotEmpty, isTrue);
    print('Generated sample_history_report.pdf (${historyReportBytes.length} bytes)');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
