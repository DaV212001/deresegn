import 'package:deresegn/controllers/invoice_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  group('Invoice Calculation Engine Tests', () {
    late InvoiceController controller;

    setUp(() {
      Get.testMode = true;
      controller = InvoiceController();
    });

    tearDown(() {
      Get.reset();
    });

    test('Single item without excise tax calculation', () {
      final tax15 = TaxCategory(
        code: 'VAT15',
        description: 'VAT (15%)',
        rate: 0.15,
      );

      controller.addItem(
        'Test Item',
        100.0, // unitPrice
        2.0, // quantity
        tax15,
        exciseRate: 0.0,
        isExciseTaxable: false,
      );

      final item = controller.items.first;
      expect(item.netValue, 200.0);
      expect(item.exciseAmount, 0.0);
      expect(item.vatBase, 200.0);
      expect(item.vatAmount, 30.0);
      expect(item.totalLineAmount, 230.0);

      expect(controller.totalPreTax, 200.0);
      expect(controller.totalExcise, 0.0);
      expect(controller.totalVat, 30.0);
      expect(controller.grandTotal, 230.0);
    });

    test('Single item with excise tax calculation', () {
      final tax15 = TaxCategory(
        code: 'VAT15',
        description: 'VAT (15%)',
        rate: 0.15,
      );

      controller.addItem(
        'Excise Item',
        100.0, // unitPrice
        2.0, // quantity
        tax15,
        exciseRate: 0.10, // 10% excise
        isExciseTaxable: true,
      );

      final item = controller.items.first;
      expect(item.netValue, 200.0);
      expect(item.exciseAmount, 20.0); // 200 * 0.10
      expect(item.vatBase, 220.0); // 200 + 20
      expect(item.vatAmount, 33.0); // 220 * 0.15
      expect(item.totalLineAmount, 253.0); // 220 + 33

      expect(controller.totalPreTax, 200.0);
      expect(controller.totalExcise, 20.0);
      expect(controller.totalVat, 33.0);
      expect(controller.grandTotal, 253.0);
    });

    test('Mixed items calculation (Excise + Non-Excise)', () {
      final tax15 = TaxCategory(
        code: 'VAT15',
        description: 'VAT (15%)',
        rate: 0.15,
      );

      // Item 1: No excise
      controller.addItem('Normal Item', 100.0, 1.0, tax15);

      // Item 2: With 10% excise
      controller.addItem(
        'Excise Item',
        200.0,
        1.0,
        tax15,
        exciseRate: 0.10,
        isExciseTaxable: true,
      );

      // Item 1: Net=100, Excise=0, VATBase=100, VAT=15, Total=115
      // Item 2: Net=200, Excise=20, VATBase=220, VAT=33, Total=253

      expect(controller.totalPreTax, 300.0); // 100 + 200
      expect(controller.totalExcise, 20.0); // 0 + 20
      expect(controller.totalVat, 48.0); // 15 + 33
      expect(controller.grandTotal, 368.0); // 300 + 20 + 48
    });

    test('Zero quantity or price', () {
      final tax15 = TaxCategory(
        code: 'VAT15',
        description: 'VAT (15%)',
        rate: 0.15,
      );

      controller.addItem('Free Item', 0.0, 10.0, tax15);
      expect(controller.grandTotal, 0.0);

      controller.addItem('Empty Item', 100.0, 0.0, tax15);
      expect(controller.grandTotal, 0.0);
    });
  });
}
