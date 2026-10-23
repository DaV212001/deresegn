import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deresegn/models/invoice_history_model.dart';
import 'package:deresegn/services/cancelled_invoices_storage.dart';
import 'package:deresegn/controllers/invoice_history_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> mockStorage = {};
  const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockStorage.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'write') {
        mockStorage[methodCall.arguments['key'] as String] =
            methodCall.arguments['value'] as String;
        return null;
      } else if (methodCall.method == 'read') {
        return mockStorage[methodCall.arguments['key'] as String];
      } else if (methodCall.method == 'delete') {
        mockStorage.remove(methodCall.arguments['key'] as String);
        return null;
      } else if (methodCall.method == 'deleteAll') {
        mockStorage.clear();
        return null;
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (MethodCall methodCall) async {
      return '.';
    });

    await CancelledInvoicesStorage.init();
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  test('CancelledInvoicesStorage tracks cancelled IRNs and reasons persistently', () async {
    const irn = 'TEST-IRN-12345';
    expect(CancelledInvoicesStorage.isCancelled(irn), isFalse);
    expect(CancelledInvoicesStorage.getReason(irn), isNull);

    await CancelledInvoicesStorage.markCancelled(irn, reasonCode: '1');

    expect(CancelledInvoicesStorage.isCancelled(irn), isTrue);
    expect(CancelledInvoicesStorage.getReason(irn), equals('1'));

    // Re-init from SharedPreferences
    await CancelledInvoicesStorage.init();
    expect(CancelledInvoicesStorage.isCancelled(irn), isTrue);
    expect(CancelledInvoicesStorage.getReason(irn), equals('1'));
  });

  test('InvoiceSummary reflects cancellation and reasons from storage', () {
    const irn = 'TEST-IRN-REACTIVE';
    final inv = InvoiceSummary(
      id: 101,
      irn: irn,
      documentNumber: 'INV-101',
      status: 'A',
      buyer: BuyerInfo(legalName: 'Test Buyer'),
      totals: TotalsInfo(totalValue: '1000.00'),
    );

    expect(inv.isCancelled, isFalse);

    // Cancelled in storage
    CancelledInvoicesStorage.markCancelled(irn, reasonCode: '2');
    expect(inv.isCancelled, isTrue);

    final updated = inv.copyWith(status: 'C', cancellationReason: '2');
    expect(updated.isCancelled, isTrue);
    expect(updated.status, equals('C'));
  });

  test('InvoiceHistoryController markInvoiceCancelledLocally updates in-memory list reactively', () async {
    final controller = Get.put(InvoiceHistoryController());

    final inv1 = InvoiceSummary(
      id: 201,
      irn: 'IRN-201',
      documentNumber: 'INV-201',
      status: 'A',
      buyer: BuyerInfo(legalName: 'Buyer 1'),
      totals: TotalsInfo(totalValue: '500.00'),
    );
    final inv2 = InvoiceSummary(
      id: 202,
      irn: 'IRN-202',
      documentNumber: 'INV-202',
      status: 'A',
      buyer: BuyerInfo(legalName: 'Buyer 2'),
      totals: TotalsInfo(totalValue: '750.00'),
    );

    controller.invoices.assignAll([inv1, inv2]);
    expect(controller.invoices[0].isCancelled, isFalse);

    controller.markInvoiceCancelledLocally('IRN-201', reasonCode: '3');

    expect(controller.invoices[0].status, equals('C'));
    expect(controller.invoices[0].isCancelled, isTrue);
    expect(controller.invoices[1].status, equals('A'));
    expect(controller.invoices[1].isCancelled, isFalse);

    // Allow any pending async task to complete
    await Future.delayed(const Duration(milliseconds: 100));
  });
}
