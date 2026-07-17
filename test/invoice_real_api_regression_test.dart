import 'dart:io';

import 'package:deresegn/config/config_preference.dart';
import 'package:deresegn/config/dio_config.dart';
import 'package:deresegn/controllers/auth_controller.dart';
import 'package:deresegn/screens/invoice_detail_screen.dart';
import 'package:deresegn/screens/invoice_generator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  // Enable real network requests for the test environment
  HttpOverrides.global = null;

  setUpAll(() async {
    // Mock path_provider for Dio's cookie storage
    const MethodChannel channel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (MethodCall methodCall) async => '.',
        );
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() async {
    Get.testMode = true;
    DioConfig.isTestMode = false; // Enable real Auth/Logging interceptors
    DioConfig.resetDio();
    await ConfigPreference.init();
  });

  testWidgets('Real API Regression: Registration and Navigation', (
    WidgetTester tester,
  ) async {
    final authController = Get.put(AuthController());

    // 1. Perform Real Authentication
    await tester.runAsync(() async {
      await authController.performMachineLogin();
    });

    final token = ConfigPreference.getAccessToken();
    expect(
      token,
      isNotNull,
      reason:
          "Login failed, no access token. Ensure credentials in ConfigPreference are valid.",
    );

    // 2. Build the UI
    await tester.pumpWidget(
      GetMaterialApp(
        home: const InvoiceGeneratorScreen(),
        theme: ThemeData.dark(),
        getPages: [
          GetPage(
            name: '/invoice-detail',
            page: () => Container(),
          ), // Placeholder if needed
        ],
      ),
    );
    await tester.pumpAndSettle();

    // --- STEP 1: Buyer Info ---
    await tester.enterText(
      find.widgetWithText(TextField, 'Buyer TIN'),
      '0088514835',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Buyer Legal Name'),
      'Regression Test Buyer',
    );
    await tester.pump();

    // Tap "Continue to Items"
    final continueBtn = find.text('Continue to Items');
    expect(continueBtn, findsOneWidget);
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    // --- STEP 2: Add Item ---
    await tester.enterText(
      find.widgetWithText(TextField, 'Item Name / Search'),
      'Regression Product',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Price'), '150.50');
    await tester.enterText(find.widgetWithText(TextField, 'Qty'), '1');
    await tester.pump();

    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();

    // --- STEP 3: Review Summary ---
    await tester.tap(find.text('Review Summary'));
    await tester.pumpAndSettle();

    // --- STEP 4: Submit to Real API ---
    // Trigger registration
    await tester.tap(find.text('Submit Invoice'));

    // Use runAsync to allow the underlying Dio request and its retries to execute
    await tester.runAsync(() async {
      // Wait for success dialog. Real API + potential 406 retries can take time.
      int attempts = 0;
      while (attempts < 20 && !Get.isDialogOpen!) {
        await Future.delayed(const Duration(milliseconds: 1000));
        attempts++;
      }
    });

    await tester.pumpAndSettle();

    // 4. Verify Backend Accepted the Payload
    expect(
      find.text('Invoice Registered'),
      findsOneWidget,
      reason:
          "The API rejected the payload or timed out. Check Logs for 400/500 errors.",
    );

    // --- STEP 5: Navigate to Details ---
    await tester.tap(find.text('View Details'));
    await tester.pumpAndSettle();

    // 5. Verify the Detail Screen Loaded with Real Data
    expect(find.byType(InvoiceDetailScreen), findsOneWidget);
    expect(find.text('Regression Test Buyer'), findsOneWidget);
    expect(find.text('0088514835'), findsOneWidget);

    // Check if the grand total appears correctly (150.50 + 15% VAT = 173.08 approx)
    expect(find.textContaining('173.08'), findsWidgets);
  });
}
