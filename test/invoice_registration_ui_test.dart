import 'dart:convert';

import 'package:deresegn/config/config_preference.dart';
import 'package:deresegn/config/dio_config.dart';
import 'package:deresegn/screens/invoice_detail_screen.dart';
import 'package:deresegn/screens/invoice_generator_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// A Mock HttpClientAdapter to intercept network requests and return mock data.
class MockHttpClientAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    final path = options.path;

    if (path.contains('/api/supplies')) {
      return ResponseBody.fromString(
        jsonEncode([]),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    } else if (path.contains('/api/invoice/register')) {
      return ResponseBody.fromString(
        jsonEncode({'irn': 'TEST-IRN-123'}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    } else if (path.contains('/api/invoices')) {
      return ResponseBody.fromString(
        jsonEncode({
          'data': [
            {
              'id': 1,
              'irn': 'TEST-IRN-123',
              'document_number': '1001',
              'status': 'A',
              'buyer': {'legal_name': 'Test Customer', 'tin': '1234567890'},
              'totals': {
                'total_value': '230.00',
                'tax_value': '30.00',
                'currency': 'ETB',
              },
              'created_at': DateTime.now().toIso8601String(),
            },
          ],
          'pagination': {
            'current_page': 1,
            'last_page': 1,
            'total': 1,
            'per_page': 15,
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(jsonEncode({'message': 'Not Found'}), 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Mock path_provider method channel which is used by DioConfig for cookie storage
    const MethodChannel channel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (MethodCall methodCall) async => '.',
        );

    // Initialize mock secure storage for ConfigPreference
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() async {
    // Configure GetX and Dio for testing
    Get.testMode = true;
    DioConfig.isTestMode = true;
    DioConfig.resetDio();

    await ConfigPreference.init();
    await ConfigPreference.updateTokens(
      "fake_access_token",
      "fake_refresh_token",
      3600,
    );

    // Inject the mock adapter into the singleton Dio instance
    final dio = await DioConfig.dio();
    dio.httpClientAdapter = MockHttpClientAdapter();
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('Full Invoice Registration Flow: Create, Submit, and View Details', (
    WidgetTester tester,
  ) async {
    // 1. Build the Invoice Generator Screen within a GetMaterialApp to support navigation
    await tester.pumpWidget(
      GetMaterialApp(
        home: const InvoiceGeneratorScreen(),
        theme: ThemeData.dark(),
      ),
    );
    await tester.pumpAndSettle();

    // --- STEP 1: Enter Buyer Information ---
    await tester.enterText(
      find.widgetWithText(TextField, 'Buyer TIN'),
      '1234567890',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Buyer Legal Name'),
      'Test Customer',
    );
    await tester.pump();

    // Navigate to the Items tab
    await tester.tap(find.text('Continue to Items'));
    await tester.pumpAndSettle();

    // --- STEP 2: Add an Invoice Item ---
    await tester.enterText(
      find.widgetWithText(TextField, 'Item Name / Search'),
      'Test Product',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Price'), '100');
    await tester.enterText(find.widgetWithText(TextField, 'Qty'), '2');
    await tester.pump();

    // Add the item to the controller's list
    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();

    // Verify the item card is displayed with the correct calculation (100 * 2 = 200)
    expect(find.text('Test Product'), findsOneWidget);
    expect(find.text('200.00 ETB'), findsOneWidget);

    // Navigate to the Summary tab
    await tester.tap(find.text('Review Summary'));
    await tester.pumpAndSettle();

    // --- STEP 3: Review and Submit ---
    // Verify grand total (200 + 15% VAT = 230)
    // Note: findsWidgets is used as the amount might appear in both Subtotal and Total Payable rows
    expect(find.text('230.00 ETB'), findsWidgets);

    // Trigger invoice registration
    await tester.tap(find.text('Submit Invoice'));

    // Allow time for async operations: Registration -> History Refresh -> Dialog display
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // --- STEP 4: Success Dialog Verification ---
    expect(find.text('Invoice Registered'), findsOneWidget);
    expect(
      find.textContaining('1001'),
      findsOneWidget,
    ); // 1001 is the document number from mock
    expect(find.textContaining('Test Customer'), findsOneWidget);

    // Tap 'View Details' on the success dialog to navigate to InvoiceDetailScreen
    await tester.tap(find.text('View Details'));
    await tester.pumpAndSettle();

    // --- STEP 5: Invoice Detail Screen Verification ---
    expect(find.byType(InvoiceDetailScreen), findsOneWidget);
    expect(find.text('Invoice Details'), findsOneWidget);

    // Verify that the data from the mock history matches what's on screen
    expect(find.text('Test Customer'), findsOneWidget);
    expect(find.text('1234567890'), findsOneWidget);
    expect(find.text('1001'), findsOneWidget);
    expect(find.textContaining('230.00 ETB'), findsWidgets);
  });
}
