import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:deresegn/controllers/invoice_controller.dart';
import 'package:deresegn/models/invoice_history_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Credit & Debit Note MoR Rule 7030 Synchronization Tests', () {
    late InvoiceController controller;

    setUp(() {
      Get.testMode = true;
      controller = InvoiceController();
    });

    tearDown(() {
      Get.reset();
    });

    test('setReferenceInvoice inherits CASH and IMMEDIATE from cash sales invoice', () {
      final cashInvoice = InvoiceSummary(
        id: 101,
        irn: 'IRN-CASH-12345',
        documentNumber: 'INV-101',
        buyer: BuyerInfo(tin: '0011223344', legalName: 'Cash Buyer PLC'),
        totals: TotalsInfo(totalValue: '500.0'),
        requestPayload: {
          'DocumentDetails': {'Type': 'INV'},
          'PaymentDetails': {'PaymentTerm': 'IMMEDIATE', 'Mode': 'CASH'},
          'ItemList': [],
        },
      );

      controller.setReferenceInvoice(cashInvoice);

      expect(controller.referenceIrn.value, equals('IRN-CASH-12345'));
      expect(controller.buyerTin.value, equals('0011223344'));
      expect(controller.buyerName.value, equals('Cash Buyer PLC'));
      expect(controller.paymentTerm.value, equals('IMMEDIATE'));
      expect(controller.paymentMode.value, equals('CASH'));
    });

    test('setReferenceInvoice inherits CREDIT and Net 30 from credit sales invoice', () {
      final creditInvoice = InvoiceSummary(
        id: 102,
        irn: 'IRN-CREDIT-67890',
        documentNumber: 'INV-102',
        buyer: BuyerInfo(tin: '0099887766', legalName: 'Credit Buyer Corp'),
        totals: TotalsInfo(totalValue: '1500.0'),
        requestPayload: {
          'DocumentDetails': {'Type': 'INV'},
          'PaymentDetails': {'PaymentTerm': 'Net 30', 'Mode': 'CREDIT'},
          'ItemList': [],
        },
      );

      controller.setReferenceInvoice(creditInvoice);

      expect(controller.referenceIrn.value, equals('IRN-CREDIT-67890'));
      expect(controller.buyerTin.value, equals('0099887766'));
      expect(controller.buyerName.value, equals('Credit Buyer Corp'));
      expect(controller.paymentTerm.value, equals('Net 30'));
      expect(controller.paymentMode.value, equals('CREDIT'));
    });

    test('parseMessage extracts exact Rule 7030 error message from Map and Stringified responses', () {
      final mapData = {
        "statusCode": 406,
        "message": "RULE VALIDATION ERROR",
        "body": [
          {
            "portion": "ReferenceDetails",
            "errorMessage": [
              "7030: (id) Related Document is not correct. : Payment term does noot match"
            ]
          }
        ]
      };

      final parsed = controller.parseMessage(mapData);
      expect(
        parsed,
        equals('7030: (id) Related Document is not correct. : Payment term does noot match'),
      );

      final stringData = jsonEncode(mapData);
      final parsedString = controller.parseMessage(stringData);
      expect(
        parsedString,
        equals('7030: (id) Related Document is not correct. : Payment term does noot match'),
      );

      final nestedStringBody = {
        "statusCode": 406,
        "message": "RULE VALIDATION ERROR",
        "body": jsonEncode([
          {
            "portion": "ReferenceDetails",
            "errorMessage": [
              "7030: (id) Related Document is not correct. : Payment term does noot match"
            ]
          }
        ])
      };
      final parsedNested = controller.parseMessage(nestedStringBody);
      expect(
        parsedNested,
        equals('7030: (id) Related Document is not correct. : Payment term does noot match'),
      );
    });
  });
}
