import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:deresegn/models/invoice_history_model.dart';
import 'package:deresegn/models/receipt_models.dart';
import 'package:deresegn/services/thermal_receipt_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final outDir = Directory(
    r'C:\Users\Abel Seyoum\.gemini\antigravity\brain\8cbd54e1-1b1d-40c3-8af1-7412d6eb23a7\receipt_photos\generated_samples',
  );

  setUpAll(() {
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
  });

  group('ThermalReceiptPdfService with User Company Details', () {
    const userCompanyOverride = CompanyProfileOverride(
      tin: '0000037187',
      tradeName: 'Micro Sun & Solution PLC',
      legalName: 'Micro Sun & Solution PLC',
      vatNumber: '43256663343256663322',
      address: 'Kirkos Sub-City, Woreda 03, Addis Ababa',
      phone: '+251 94 799 0585',
      cashierName: 'Amanuel Tilahun',
      systemNumber: 'F86A66EF99',
    );

    final userInvoice = InvoiceSummary(
      id: 207,
      documentNumber: '207',
      irn: 'test-52284b0f36e08c516b55a2c4ff24ce2eb9acb7831101aa702c3ed429ec8212b03',
      transactionType: 'B2C',
      buyer: BuyerInfo(
        legalName: 'Taxpayer P',
        tin: '0053374665',
      ),
      totals: TotalsInfo(
        totalValue: '506.87',
        taxValue: '33.38',
        discount: '10.01',
        exciseValue: '20.00',
      ),
      requestPayload: {
        'DocumentType': 'CASH_INVOICE',
        'TransactionType': 'B2C',
        'DocumentNumber': '207',
        'IssueDateTime': '2026-10-21T09:54:57Z',
        'SellerDetails': {
          'Tin': '0000037187',
          'TradeName': 'Micro Sun & Solution PLC',
          'LegalName': 'Micro Sun & Solution PLC',
          'VatRegistrationNumber': '43256663343256663322',
          'Region': '1',
          'Woreda': '03',
          'Telephone': '+251947990585',
        },
        'BuyerDetails': {
          'LegalName': 'Taxpayer P',
          'Tin': '0053374665',
        },
        'SourceSystem': {
          'SourceSystemCode': 'MSS-POS-01',
          'DeviceSerialNumber': 'F86A66EF99',
          'OperatorName': 'Amanuel Tilahun',
        },
        'InvoiceLines': [
          {
            'ProductDescription': 'Mineral Water 500ml',
            'Quantity': '1',
            'UnitPrice': '12.50',
            'LineAmount': '12.50',
            'TaxCategory': 'VAT15',
          },
          {
            'ProductDescription': 'test item',
            'Quantity': '1',
            'UnitPrice': '1.00',
            'LineAmount': '1.00',
            'TaxCategory': 'VATEX',
          },
          {
            'ProductDescription': 'Amoxicilin',
            'Quantity': '1',
            'UnitPrice': '250.00',
            'LineAmount': '250.00',
            'TaxCategory': 'VAT0',
          },
          {
            'ProductDescription': 'Beer',
            'Quantity': '1',
            'UnitPrice': '200.00',
            'LineAmount': '200.00',
            'TaxCategory': 'VAT15',
          },
        ],
        'Totals': {
          'GrossAmount': '463.50',
          'DiscountAmount': '10.01',
          'ExciseTaxAmount': '20.00',
          'VatAmount': '33.38',
          'TotalInvoiceAmount': '506.87',
        },
        'PaymentMeans': 'CASH',
        'CashTendered': '506.87',
        'Change': '0.00',
      },
    );

    test('generates and saves 80mm Cash Sales Invoice with user company details', () async {
      final bytes = await ThermalReceiptPdfService.generateInvoiceReceipt(
        userInvoice,
        paperFormat: ReceiptPaperFormat.roll80,
        companyOverride: userCompanyOverride,
      );
      File('${outDir.path}/01_Cash_Sales_Invoice_80mm.pdf').writeAsBytesSync(bytes);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('generates and saves 58mm Cash Sales Invoice with user company details', () async {
      final bytes = await ThermalReceiptPdfService.generateInvoiceReceipt(
        userInvoice,
        paperFormat: ReceiptPaperFormat.roll58,
        companyOverride: userCompanyOverride,
      );
      File('${outDir.path}/01_Cash_Sales_Invoice_58mm.pdf').writeAsBytesSync(bytes);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('generates and saves Cancelled Invoice with user company details', () async {
      final bytes = await ThermalReceiptPdfService.generateInvoiceReceipt(
        userInvoice,
        paperFormat: ReceiptPaperFormat.roll80,
        isCancelled: true,
        companyOverride: userCompanyOverride,
      );
      File('${outDir.path}/02_Cancelled_Invoice_80mm.pdf').writeAsBytesSync(bytes);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('generates and saves Debit Note with user company details', () async {
      final debitInvoice = InvoiceSummary(
        id: 212,
        documentNumber: '212',
        irn: 'test-6ebeafc478288457bf61fdc82cacd70263ab176ab19dchf2307e604b330d23b',
        transactionType: 'B2B',
        buyer: BuyerInfo(
          legalName: 'Abyssinia Trading PLC',
          tin: '0079140416',
        ),
        totals: TotalsInfo(totalValue: '256.87'),
        requestPayload: {
          'DocumentType': 'DEBIT_NOTE',
          'TransactionType': 'B2B',
          'DocumentNumber': '212',
          'PreviousIrn': 'test-81ab8b972dac17ac7a8be950117b74c016dffc2351198e13accface9dac3a1cc',
          'SellerDetails': userInvoice.requestPayload!['SellerDetails'],
          'BuyerDetails': {
            'LegalName': 'Abyssinia Trading PLC',
            'Tin': '0079140416',
          },
          'SourceSystem': userInvoice.requestPayload!['SourceSystem'],
          'InvoiceLines': [
            {'ProductDescription': 'test item', 'Quantity': '1', 'UnitPrice': '1.00', 'LineAmount': '1.00', 'TaxCategory': 'VATEX'},
            {'ProductDescription': 'Mineral Water 500ml', 'Quantity': '1', 'UnitPrice': '12.50', 'LineAmount': '12.50', 'TaxCategory': 'VAT15'},
            {'ProductDescription': 'Beer', 'Quantity': '1', 'UnitPrice': '200.00', 'LineAmount': '200.00', 'TaxCategory': 'VAT15'},
          ],
          'Totals': {
            'GrossAmount': '213.50',
            'DiscountAmount': '10.01',
            'ExciseTaxAmount': '20.00',
            'VatAmount': '33.38',
            'TotalInvoiceAmount': '256.87',
          },
          'PaymentMeans': 'CASH',
        },
      );

      final bytes = await ThermalReceiptPdfService.generateInvoiceReceipt(
        debitInvoice,
        paperFormat: ReceiptPaperFormat.roll80,
        companyOverride: userCompanyOverride,
      );
      File('${outDir.path}/03_Debit_Note_80mm.pdf').writeAsBytesSync(bytes);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('generates and saves Credit Note with user company details', () async {
      final creditInvoice = InvoiceSummary(
        id: 211,
        documentNumber: '211',
        irn: 'test-d0728eab02113a4512b5dc5ad12eb284ad316a8b01a6fc1434ac2fd953ceb20',
        transactionType: 'B2B',
        buyer: BuyerInfo(
          legalName: 'Abyssinia Trading PLC',
          tin: '0079140416',
        ),
        totals: TotalsInfo(totalValue: '492.49'),
        requestPayload: {
          'DocumentType': 'CREDIT_NOTE',
          'TransactionType': 'B2B',
          'DocumentNumber': '211',
          'PreviousIrn': 'test-81ab8b972dac17ac7a8be950117b74c016dffc2351198e13accface9dac3a1cc',
          'SellerDetails': userInvoice.requestPayload!['SellerDetails'],
          'BuyerDetails': {
            'LegalName': 'Abyssinia Trading PLC',
            'Tin': '0079140416',
          },
          'SourceSystem': userInvoice.requestPayload!['SourceSystem'],
          'InvoiceLines': [
            {'ProductDescription': 'test item', 'Quantity': '1', 'UnitPrice': '1.00', 'LineAmount': '1.00', 'TaxCategory': 'VATEX'},
            {'ProductDescription': 'Amoxicilin', 'Quantity': '1', 'UnitPrice': '250.00', 'LineAmount': '250.00', 'TaxCategory': 'VAT0'},
            {'ProductDescription': 'Beer', 'Quantity': '1', 'UnitPrice': '200.00', 'LineAmount': '200.00', 'TaxCategory': 'VAT15'},
          ],
          'Totals': {
            'GrossAmount': '451.00',
            'DiscountAmount': '10.01',
            'ExciseTaxAmount': '20.00',
            'VatAmount': '31.50',
            'TotalInvoiceAmount': '492.49',
          },
          'PaymentMeans': 'CASH',
        },
      );

      final bytes = await ThermalReceiptPdfService.generateInvoiceReceipt(
        creditInvoice,
        paperFormat: ReceiptPaperFormat.roll80,
        companyOverride: userCompanyOverride,
      );
      File('${outDir.path}/04_Credit_Note_80mm.pdf').writeAsBytesSync(bytes);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('generates and saves Sales Receipt Voucher with user company details', () async {
      final sampleReceipt = ReceiptSummary(
        id: 38,
        receiptNumber: 'REC38',
        rrn: 'test-ed38b12feea417aa43a16996526eac2d09c26c84c7f21bb94a37303f427e7535',
        invoiceIrn: 'test-cb4ed7ec9d95b32da83a8386c3f7adbb99bb8b88ef2923b987dfa476e4e82defb8',
        requestPayload: {
          'ReceiptNumber': 'REC38',
          'ReceiptDate': '2026-10-21T14:59:39Z',
          'CollectedAmount': '506.87',
          'Cashier': 'Amanuel Tilahun',
          'TransactionDetails': {'PaymentMethod': 'CASH'},
        },
      );

      final bytes = await ThermalReceiptPdfService.generateVoucherReceipt(
        sampleReceipt,
        userInvoice,
        paperFormat: ReceiptPaperFormat.roll80,
        companyOverride: userCompanyOverride,
      );
      File('${outDir.path}/06_Sales_Receipt_Voucher_CRV_80mm.pdf').writeAsBytesSync(bytes);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('generates and saves Withholding Tax Receipt with user company details', () async {
      final sampleWhtReceipt = ReceiptSummary(
        id: 32,
        receiptNumber: 'REC32',
        rrn: 'test-ec09b0a8cba8272c2b3669c9b34145d0882339ce20f36ea37493a6491a2b371ba',
        invoiceIrn: 'test-dc9ad47a584c9a5df41cb57f498847985c68a031604d627f69f638c5e5b7b6d0',
        requestPayload: {
          'ReceiptType': 'TWTH',
          'ReceiptNumber': 'REC32',
          'ReceiptDate': '2026-10-21T15:42:58Z',
          'BuyerTIN': '0000037187',
          'CollectedAmount': '1827.36',
          'WithholdDetail': {
            'InvoiceAmountExclTax': '68912.00',
            'WithholdingAmount': '1827.36',
          },
        },
      );

      final bytes = await ThermalReceiptPdfService.generateVoucherReceipt(
        sampleWhtReceipt,
        userInvoice,
        paperFormat: ReceiptPaperFormat.roll80,
        isWithholding: true,
        companyOverride: userCompanyOverride,
      );
      File('${outDir.path}/08_Withholding_Tax_Receipt_WHT_80mm.pdf').writeAsBytesSync(bytes);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('generates 80mm and 58mm receipts correctly for Invoice #155 (ItemList & ValueDetails)', () async {
      final invoice155Json = <String, dynamic>{
        'id': 155,
        'irn': 'test-78908fa153eecc5825957f6ad86b6b8aaa8bac53ac406b7d39a04565c14bc4c66',
        'document_number': '196',
        'status': 'A',
        'ack_date': '2026-11-24T06:41:32.000000Z',
        'signed_qr': 'iVBORw0KGgoAAAANSUhEUgAAAZAAAAGGQAQAAAACoxAthAAALp0lEQVR4Xu2bQY60uBKEXWLhXXEBJK7hna8EF6CKCxRX8o5rIHEB2LFA+H3hnkX1P4tR6enlSE+FWjOlakcL25kZEWn/Ln/8uD+/+OfnC/n0+UI+fb6QT58v5NPnC/n0+b+DbM4Nbs1z+/LLbV7H2fXp7Fwej7yn9Qru7tYxN861xpA9n0NcHnPThTymdTyWu1vusX2FpYvV5sGul28e2RySmsHll+dtefgLS52aW2qndD5mhlXjzHybzv8LkMfh6nm5e16+6ed1z/rmltwtuy62m6syy/5vQPrjvIe8BcZU+7wM0Tm/vjxf6sPlCY8/52IBYff96dz65LXDOTgWmQ9MrSVW9+weyd3D+WfA/O8h5Es/N//480eK/X3A33/+S4hQ8exTU89sNKvK1rebd4/cDKHlV/dQkdR/PZaQdN7478wH58LyOErihHaazz4TnNUrAF96c8gW8+Ybkrdz7jFXV6ymuc1KGda2fakw5qcndK0h/O+hHFlflJeyy5dXEb77/HLV0y23rNy5zfYQNredjuWRGMBg6kl+hXU6VmLAxaY+IJFMNhlDtujqo3qphuQrQg18dn0++2PNeXEwyFwx5v6eYjYQB7FS3/KY14kg1IfzAdAzft1nvnSDb5/BGpK1vCp9l5aUBSdzl64oAYJzYG0P17nm/r4vJDLs6pVicOlP5Y+UZOhDDHsBq/9KJPMGHOI4+XbiRpC1oBK7kEcJnHHk3gIy+0gcYgBDbaFqBQPCoClLC8k2/RpnXh/zwovKKgXHOetIXkmCCH9hjpTE5CpGpNECLPo2X3vOum3tdRDUwi/3Q/XH9WONJJyq3j/e1S+UI0vUhihciy1OYS5DJ50WKl4T78+3Vkog+LMeMS5SlAX8/ROFjaQI08zy7g8MjTBIq/677xuUpVSTUSF804UbAvZExRWbWG9',
        'signed_invoice': 'VkhboV8FWNugvg4zj3/jEo63MccHUyrA5aka1wy+donaTqWdf94fpJdfAsOmtNBabtGvc81QfGqO7MnhErQkH2tH0fIF1qDopzfxNt1bS9eeXwcfTqnzNVP43AyuufYMwpzlSfGiFDC6q8byxCnabKAVdGSSJFAmKBolukKrOJU8Tajn1OLzL2XBEsqeXXNi9yLMo5dz+t65Z2NXIlY62tGZAtk+oMdcenhqDQxOXOzcZgnJUGPpwxqs72Na4fL+7pKrT85W5+mYJUC7Ijaj//mzQ5KAPzHMd0oXLETDJufWpLlxWY113B/qnIxwTLt3dkz+/+Cp7bBNBedNX+18aOw==',
        'request_payload': {
          'DocumentDetails': {
            'DocumentNumber': '196',
            'Type': 'INV',
            'Reason': 'Sales Invoice',
            'Date': '24-11-2026T06:40:30',
          },
          'TransactionType': 'B2C',
          'SourceSystem': {
            'SystemType': 'POS',
            'CashierName': 'Default Cashier',
            'SystemNumber': 'F86A66EF99',
            'InvoiceCounter': 196,
            'SalesPersonName': 'Default Cashier',
          },
          'SellerDetails': {
            'Tin': '0000037187',
            'LegalName': 'Micro Sun & Solution PLC',
            'City': '101',
            'Wereda': '13',
            'Region': '1',
            'Email': 'amanuielt@mssmea.com',
            'Phone': '+251947990585',
            'Country': '1',
            'TradeName': 'MicroSun&SolutionPLC',
            'VatNumber': '43256663343256663322',
          },
          'BuyerDetails': {
            'LegalName': 'Walking',
            'IdType': 'KID',
            'HouseNumber': null,
            'IdNumber': null,
            'Tin': null,
            'Email': 'readatwattpad@gmail.com',
            'Phone': '0944070484',
            'City': '101',
            'Region': null,
            'Country': null,
            'Kebele': null,
            'Wereda': null,
            'VatNumber': null,
          },
          'ItemList': [
            {
              'LineNumber': 1,
              'NatureOfSupplies': 'goods',
              'UnitPrice': '100000.00',
              'TotalLineAmount': '115000.00',
              'PreTaxValue': '100000.00',
              'Unit': 'PCS',
              'TaxCode': 'VAT15',
              'TaxAmount': '15000.00',
              'Quantity': '1.00',
              'Discount': '0.00',
              'ExciseTaxValue': '0.00',
              'ProductDescription': 'laptop',
              'ItemCode': 'ITEM-1',
            },
          ],
          'ValueDetails': {
            'TotalValue': '115000.00',
            'TaxValue': '15000.00',
            'Discount': '0.00',
            'ExciseValue': '0.00',
            'InvoiceCurrency': 'ETB',
            'IncomeWithholdValue': '0.00',
            'TransactionWithholdValue': '0.00',
          },
          'PaymentDetails': {
            'PaymentTerm': 'IMMEDIATE',
            'Mode': 'CASH',
          },
          'ReferenceDetails': {
            'RelatedDocument': null,
            'PreviousIrn': 'null',
          },
          'Version': '1',
        },
        'buyer': {
          'tin': null,
          'legal_name': 'Walking',
          'phone': '0944070484',
          'email': 'readatwattpad@gmail.com',
          'city': '101',
          'region': null,
        },
        'seller': {
          'tin': '0000037187',
          'legal_name': 'Micro Sun & Solution PLC',
          'phone': '+251947990585',
          'email': 'amanuielt@mssmea.com',
          'city': '101',
          'region': '1',
        },
        'totals': {
          'total_value': '115000.00',
          'tax_value': '15000.00',
          'discount': '0.00',
          'excise_value': '0.00',
          'currency': 'ETB',
        },
        'items': [
          {
            'LineNumber': 1,
            'NatureOfSupplies': 'goods',
            'UnitPrice': '100000.00',
            'TotalLineAmount': '115000.00',
            'PreTaxValue': '100000.00',
            'Unit': 'PCS',
            'TaxCode': 'VAT15',
            'TaxAmount': '15000.00',
            'Quantity': '1.00',
            'Discount': '0.00',
            'ExciseTaxValue': '0.00',
            'ProductDescription': 'laptop',
            'ItemCode': 'ITEM-1',
          },
        ],
        'payment': {
          'term': 'IMMEDIATE',
          'mode': 'CASH',
        },
        'transaction_type': 'B2C',
        'created_at': '2026-11-24T06:41:32.000000Z',
        'updated_at': '2026-11-24T06:41:32.000000Z',
      };

      final invoice155 = InvoiceSummary.fromJson(invoice155Json);

      // 1. Generate 80mm
      final bytes80 = await ThermalReceiptPdfService.generateInvoiceReceipt(
        invoice155,
        paperFormat: ReceiptPaperFormat.roll80,
      );
      expect(bytes80.isNotEmpty, isTrue);
      File('${outDir.path}/155_Laptop_Invoice_80mm.pdf').writeAsBytesSync(bytes80);

      // 2. Generate 58mm
      final bytes58 = await ThermalReceiptPdfService.generateInvoiceReceipt(
        invoice155,
        paperFormat: ReceiptPaperFormat.roll58,
      );
      expect(bytes58.isNotEmpty, isTrue);
      File('${outDir.path}/155_Laptop_Invoice_58mm.pdf').writeAsBytesSync(bytes58);
    });
  });
}
