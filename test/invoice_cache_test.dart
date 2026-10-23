import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deresegn/models/invoice_history_model.dart';
import 'package:deresegn/services/invoice_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('InvoiceCacheService saves and retrieves invoices correctly', () async {
    final inv1 = InvoiceSummary(
      id: 101,
      irn: 'IRN-TEST-101',
      documentNumber: 'DOC-101',
      status: 'A',
      buyer: BuyerInfo(legalName: 'Customer Alpha', tin: '0011223344'),
      totals: TotalsInfo(totalValue: '1150.00', taxValue: '150.00'),
      createdAt: '2026-10-20T10:00:00.000Z',
    );

    final inv2 = InvoiceSummary(
      id: 102,
      irn: 'IRN-TEST-102',
      documentNumber: 'DOC-102',
      status: 'C',
      buyer: BuyerInfo(legalName: 'Customer Beta'),
      totals: TotalsInfo(totalValue: '2300.00', taxValue: '300.00'),
      createdAt: '2026-10-20T11:00:00.000Z',
    );

    await InvoiceCacheService.saveInvoices([inv1]);
    var loaded = await InvoiceCacheService.loadInvoices();
    expect(loaded.length, equals(1));
    expect(loaded.first.documentNumber, equals('DOC-101'));
    expect(loaded.first.buyer.legalName, equals('Customer Alpha'));

    // Save second invoice - should merge and sort descending by date (inv2 first)
    await InvoiceCacheService.saveInvoices([inv2]);
    loaded = await InvoiceCacheService.loadInvoices();
    expect(loaded.length, equals(2));
    expect(loaded[0].documentNumber, equals('DOC-102'));
    expect(loaded[1].documentNumber, equals('DOC-101'));

    final lastTime = await InvoiceCacheService.getLastCachedTime();
    expect(lastTime, isNotNull);

    // Test clearCache
    await InvoiceCacheService.clearCache();
    loaded = await InvoiceCacheService.loadInvoices();
    expect(loaded.isEmpty, isTrue);
  });
}
