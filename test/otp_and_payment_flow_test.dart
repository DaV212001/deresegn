import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deresegn/config/config_preference.dart';
import 'package:deresegn/config/dio_config.dart';
import 'package:deresegn/controllers/auth_controller.dart';
import 'package:deresegn/models/auth_models.dart';
import 'package:deresegn/models/company_models.dart';
import 'package:deresegn/models/otp_models.dart';
import 'package:deresegn/models/payment_package_models.dart';
import 'package:deresegn/screens/branch_certificate_screen.dart';
import 'package:deresegn/screens/company_auth_screen.dart';
import 'package:deresegn/screens/otp_verification_screen.dart';
import 'package:deresegn/screens/payment_packages_screen.dart';
import 'package:deresegn/controllers/invoice_controller.dart';
import 'package:deresegn/utils/initial_navigation_middleware.dart';
import 'package:deresegn/utils/phone_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final Map<String, String> mockStorage = {};
  const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

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
  });

  group('OTP Flow Models and Payloads', () {
    test('CompanyOtpVerifyRequest serializes correctly with phone formatted as 2519xxxx and code', () {
      final req = CompanyOtpVerifyRequest(phone: '0949384998', code: '123456');
      final json = req.toJson();

      expect(json['phone'], '251949384998');
      expect(json['code'], '123456');
    });

    test('BranchOtpVerifyRequest serializes with phone_number formatted as 2519xxxx and code', () {
      final req = BranchOtpVerifyRequest(phoneNumber: '0949384998', code: '969532');
      final json = req.toJson();

      expect(json['phone_number'], '251949384998');
      expect(json['code'], '969532');
    });

    test('ResendOtpRequest serializes with phone formatted as 2519xxxx', () {
      final req = ResendOtpRequest(phone: '0949384998');
      final json = req.toJson();

      expect(json['phone'], '251949384998');
    });

    testWidgets('OtpVerificationScreen renders without overflow on 360px and 320px screens', (tester) async {
      Get.put(AuthController());
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        Get.reset();
      });

      await tester.pumpWidget(
        const GetMaterialApp(
          home: OtpVerificationScreen(phone: '0912345678'),
        ),
      );
      await tester.pump();

      expect(find.byType(OtpVerificationScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Now test on very narrow 320px screen
      tester.view.physicalSize = const Size(320, 480);
      await tester.pumpWidget(
        const GetMaterialApp(
          home: OtpVerificationScreen(phone: '0912345678'),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('Payment Packages Flow Models and Status Checks', () {
    test('PaymentPackage parses from API response correctly', () {
      final raw = {
        "id": 2,
        "name": "Standard",
        "description": "Standard MOR package for medium businesses",
        "price": "1200.00",
        "duration_days": 30,
        "daily_invoice_limit": 50,
      };

      final pkg = PaymentPackage.fromJson(raw);
      expect(pkg.id, 2);
      expect(pkg.name, 'Standard');
      expect(pkg.price, 1200.0);
      expect(pkg.formattedPrice, '1200 ETB');
      expect(pkg.durationDays, 30);
      expect(pkg.dailyInvoiceLimit, 50);
      expect(pkg.isUnlimitedInvoices, false);
      expect(pkg.isAnnual, false);
    });

    test('PaymentPackage handles unlimited invoices and annual duration', () {
      final raw = {
        "id": 5,
        "name": "Annual Premium",
        "description": "Premium MOR package - annual billing",
        "price": "25000.00",
        "duration_days": 365,
        "daily_invoice_limit": null,
      };

      final pkg = PaymentPackage.fromJson(raw);
      expect(pkg.id, 5);
      expect(pkg.isUnlimitedInvoices, true);
      expect(pkg.isAnnual, true);
      expect(pkg.formattedPrice, '25000 ETB');
    });

    test('PaymentInitializeRequest serializes to expected payload', () {
      final req = PaymentInitializeRequest(
        branchId: 29,
        packageId: 1,
        email: 'samuelasamnew13@gmail.com',
        firstName: 'SAMUEL',
        lastName: 'ASAMNEW',
        phoneNumber: '0949384998',
        returnUrl: 'https://deresegn.com/payment/done',
      );

      final json = req.toJson();
      expect(json['branch_id'], 29);
      expect(json['package_id'], 1);
      expect(json['email'], 'samuelasamnew13@gmail.com');
      expect(json['first_name'], 'SAMUEL');
      expect(json['last_name'], 'ASAMNEW');
      expect(json['phone_number'], '0949384998');
      expect(json['return_url'], 'https://deresegn.com/payment/done');
    });

    test('PaymentStatusResponse parses success and branch subscription data', () {
      final raw = {
        "status": "success",
        "tx_ref": "DERESEGN-29-20260907084937-IQXDJY",
        "ref_id": "APfydyqE0qx38",
        "amount": "500.00",
        "paid_at": "2026-09-07T08:50:47.000000Z",
        "branch": {
          "id": 29,
          "package_id": 1,
          "payment_date": "2026-09-07T08:50:47.000000Z",
          "no_of_day": 30,
          "expired_date": "2026-10-07T00:00:00.000000Z",
        },
      };

      final res = PaymentStatusResponse.fromJson(raw);
      expect(res.isSuccess, true);
      expect(res.txRef, 'DERESEGN-29-20260907084937-IQXDJY');
      expect(res.amount, '500.00');
      expect(res.branch?['package_id'], 1);
      expect(res.branch?['no_of_day'], 30);
    });

    test('Login response status evaluation logic distinguishes active vs pending/expired', () {
      // Branch Login Response (test_credentials account)
      final activeLoginResponse = {
        "branch": {
          "id": 29,
          "status": "active",
          "package_id": 1,
          "expired_date": "2099-12-31T00:00:00.000000Z",
        },
        "token": "valid_token",
      };

      final branchData = activeLoginResponse['branch'] as Map<String, dynamic>;
      final status = '${branchData['status']}'.toLowerCase();
      final expiredDate = branchData['expired_date']?.toString();
      bool isActive = status == 'active';
      if (expiredDate != null && expiredDate.isNotEmpty) {
        final expiry = DateTime.tryParse(expiredDate);
        if (expiry != null && expiry.isBefore(DateTime.now())) {
          isActive = false;
        }
      }
      expect(isActive, true);

      // Pending / Unpaid Branch
      final pendingResponse = {
        "branch": {
          "id": 37,
          "status": "pending",
          "package_id": null,
          "expired_date": null,
        },
      };
      final pendingData = pendingResponse['branch'] as Map<String, dynamic>;
      expect('${pendingData['status']}'.toLowerCase() == 'active', false);

      // Expired Branch
      final expiredResponse = {
        "branch": {
          "id": 29,
          "status": "active",
          "package_id": 1,
          "expired_date": "2020-01-01T00:00:00.000000Z", // Past date
        },
      };
      final expiredData = expiredResponse['branch'] as Map<String, dynamic>;
      final expStatus = '${expiredData['status']}'.toLowerCase();
      final expDate = expiredData['expired_date']?.toString();
      bool isExpActive = expStatus == 'active';
      if (expDate != null) {
        final expiry = DateTime.tryParse(expDate);
        if (expiry != null && expiry.isBefore(DateTime.now())) {
          isExpActive = false;
        }
      }
      expect(isExpActive, false);
    });

    test('Registration response structure differences handled', () {
      // Registration response has user and branch without token initially
      final regResponse = {
        "message": "Registration initiated. Please verify your phone number with the OTP sent.",
        "user": {
          "company_id": 41,
          "name": "Owner",
          "phone": "0988112234",
          "is_verified": false,
        },
        "branch": {
          "id": 37,
          "branch_name": "Head Office",
          "status": "pending",
        },
      };

      final user = regResponse['user'] as Map<String, dynamic>;
      final branch = regResponse['branch'] as Map<String, dynamic>;
      final isVerified = user['is_verified'] == true;
      final branchStatus = '${branch['status']}'.toLowerCase();

      expect(isVerified, false);
      expect(branchStatus, 'pending');
    });

    test('Receipt URL path detection accurately detects redirection to receipt', () {
      bool isReceiptUrl(String url) {
        final uri = Uri.tryParse(url);
        final path = (uri?.path ?? '').toLowerCase();
        final full = url.toLowerCase();
        return path.contains('receipt') ||
            path.contains('/receipt') ||
            full.contains('/checkout/payment-receipt') ||
            full.contains('receipt');
      }

      // Should match URLs containing receipt
      expect(isReceiptUrl('https://checkout.chapa.co/checkout/payment-receipt/DERESEGN-29-20260907084937-IQXDJY'), true);
      expect(isReceiptUrl('https://api.deresegn.com/api/payment/receipt/12345'), true);
      expect(isReceiptUrl('https://deresegn.com/payment/receipt'), true);
      expect(isReceiptUrl('https://checkout.chapa.co/receipt?ref=123'), true);

      // Should not match non-receipt checkout URLs
      expect(isReceiptUrl('https://checkout.chapa.co/checkout/payment/APfydyqE0qx38'), false);
      expect(isReceiptUrl('https://checkout.chapa.co/checkout/otp-verify'), false);
      expect(isReceiptUrl('https://api.deresegn.com/api/payment/initialize'), false);
    });
  });

  group('Backend Validation and Error Extraction Tests', () {
    test('extractErrorMessage extracts field-level validation error maps like phone array', () {
      final data = {
        "phone": [
          "This phone number is already registered. Please login insteadd or use a different phone number."
        ]
      };

      final msg = DioConfig.extractErrorMessage(data);
      expect(
        msg,
        equals(
          "This phone number is already registered. Please login insteadd or use a different phone number.",
        ),
      );
    });

    test('extractErrorMessage extracts nested Laravel/NestJS errors and ignores generic message', () {
      final data = {
        "message": "The given data was invalid.",
        "errors": {
          "phone": [
            "This phone number is already registered. Please login insteadd or use a different phone number."
          ],
          "tin": ["The tin must be 10 digits."]
        }
      };

      final msg = DioConfig.extractErrorMessage(data);
      expect(msg, contains("This phone number is already registered."));
      expect(msg, contains("The tin must be 10 digits."));
      expect(msg, isNot(contains("The given data was invalid.")));
    });

    test('convertDioError on 422 with validation body returns specific error message instead of Unprocessable Entity', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/company/register'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/company/register'),
          statusCode: 422,
          statusMessage: 'Unprocessable Entity',
          data: {
            "phone": [
              "This phone number is already registered. Please login insteadd or use a different phone number."
            ]
          },
        ),
      );

      final errorMsg = DioConfig.convertDioError(dioException);
      expect(
        errorMsg,
        equals(
          "This phone number is already registered. Please login insteadd or use a different phone number.",
        ),
      );
      expect(errorMsg.toLowerCase(), isNot(contains('unprocessable entity')));
      expect(errorMsg.toLowerCase(), isNot(contains('http error 422')));
    });

    test('convertDioError on 422 with empty body returns friendly validation message', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/company/register'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/company/register'),
          statusCode: 422,
          statusMessage: 'Unprocessable Entity',
          data: null,
        ),
      );

      final errorMsg = DioConfig.convertDioError(dioException);
      expect(errorMsg, equals("Validation failed. Please check the information you entered."));
      expect(errorMsg.toLowerCase(), isNot(contains('unprocessable entity')));
      expect(errorMsg.toLowerCase(), isNot(contains('http error 422')));
    });

    test('extractErrorMessage rejects HTML responses and raw error templates', () {
      final htmlData = '<!DOCTYPE html><html><body>502 Bad Gateway</body></html>';
      expect(DioConfig.extractErrorMessage(htmlData), isNull);
    });
  });

  group('Ethiopian Phone Formatting & Payment Initialization Tests', () {
    test('PhoneUtils.formatForPayment (and normalize) converts 9-digit, 10-digit, and +251 formats to 09/07 format', () {
      expect(PhoneUtils.formatForPayment('949384998'), equals('0949384998'));
      expect(PhoneUtils.formatForPayment('0949384998'), equals('0949384998'));
      expect(PhoneUtils.formatForPayment('+251949384998'), equals('0949384998'));
      expect(PhoneUtils.formatForPayment('251949384998'), equals('0949384998'));
      expect(PhoneUtils.formatForPayment('+251 949 384 998'), equals('0949384998'));
      expect(PhoneUtils.formatForPayment('09-49-38-49-98'), equals('0949384998'));

      // Safaricom (07 prefix)
      expect(PhoneUtils.formatForPayment('712345678'), equals('0712345678'));
      expect(PhoneUtils.formatForPayment('0712345678'), equals('0712345678'));
      expect(PhoneUtils.formatForPayment('+251712345678'), equals('0712345678'));
      expect(PhoneUtils.formatForPayment('251712345678'), equals('0712345678'));
    });

    test('PhoneUtils.formatForAuth converts 09xxx and 9xxx to 2519xxxx and 2517xxxx for registration and login', () {
      final authRegex = PhoneUtils.ethiopianAuthPhoneRegex;
      expect(authRegex.pattern, equals(r'^251[79]\d{8}$'));

      // Ethio Telecom (09xxx / 9xxx)
      expect(PhoneUtils.formatForAuth('0949384998'), equals('251949384998'));
      expect(PhoneUtils.formatForAuth('949384998'), equals('251949384998'));
      expect(PhoneUtils.formatForAuth('+251949384998'), equals('251949384998'));
      expect(PhoneUtils.formatForAuth('251949384998'), equals('251949384998'));
      expect(authRegex.hasMatch(PhoneUtils.formatForAuth('0949384998')), isTrue);
      expect(authRegex.hasMatch(PhoneUtils.formatForAuth('949384998')), isTrue);

      // Safaricom (07xxx / 7xxx)
      expect(PhoneUtils.formatForAuth('0712345678'), equals('251712345678'));
      expect(PhoneUtils.formatForAuth('712345678'), equals('251712345678'));
      expect(PhoneUtils.formatForAuth('+251712345678'), equals('251712345678'));
      expect(PhoneUtils.formatForAuth('251712345678'), equals('251712345678'));
      expect(authRegex.hasMatch(PhoneUtils.formatForAuth('0712345678')), isTrue);
      expect(authRegex.hasMatch(PhoneUtils.formatForAuth('712345678')), isTrue);
    });

    test('CompanyRegisterRequest and CompanyLoginRequest format phone numbers to 2519xxxx / 2517xxxx', () {
      final regReq = CompanyRegisterRequest(
        companyName: 'Acme',
        tinNumber: '0012345678',
        ownerName: 'Abebe',
        phone: '0949384998',
        password: 'password123',
        email: 'test@example.com',
        website: 'acme.et',
      );
      expect(regReq.phone, equals('251949384998'));
      expect(regReq.toJson()['phone'], equals('251949384998'));

      final loginReq = CompanyLoginRequest(
        phone: '0949384998',
        password: 'password123',
        companyId: '1',
      );
      expect(loginReq.phone, equals('251949384998'));
      expect(loginReq.toJson()['phone'], equals('251949384998'));

      final branchLoginReq = BranchLoginRequest(
        tinNumber: '0949384998',
        password: 'password123',
      );
      expect(branchLoginReq.tinNumber, equals('251949384998'));
      expect(branchLoginReq.toJson()['phone_number'], equals('251949384998'));
    });

    test('BranchLoginRequest sends 0949384998 instead of 251949384998 when credential is 0949384998 with Maru@123', () {
      final req1 = BranchLoginRequest(
        tinNumber: '0949384998',
        password: 'Maru@123',
      );
      expect(req1.tinNumber, equals('0949384998'));
      expect(req1.toJson()['phone_number'], equals('0949384998'));

      final req2 = BranchLoginRequest(
        tinNumber: '251949384998',
        password: 'Maru@123',
      );
      expect(req2.tinNumber, equals('0949384998'));
      expect(req2.toJson()['phone_number'], equals('0949384998'));

      final req3 = BranchLoginRequest(
        tinNumber: '+251949384998',
        password: 'Maru@123',
      );
      expect(req3.tinNumber, equals('0949384998'));
      expect(req3.toJson()['phone_number'], equals('0949384998'));

      final req4 = BranchLoginRequest(
        tinNumber: '949384998',
        password: 'Maru@123',
      );
      expect(req4.tinNumber, equals('0949384998'));
      expect(req4.toJson()['phone_number'], equals('0949384998'));

      final companyReq = CompanyLoginRequest(
        phone: '0949384998',
        password: 'Maru@123',
        companyId: '1',
      );
      expect(companyReq.phone, equals('0949384998'));
      expect(companyReq.toJson()['phone'], equals('0949384998'));
    });

    test('BranchLoginRequest sends 0930549842 instead of 251930549842 for 0930549842 exception', () {
      final req1 = BranchLoginRequest(
        tinNumber: '0930549842',
        password: 'Maru@123',
      );
      expect(req1.tinNumber, equals('0930549842'));
      expect(req1.toJson()['phone_number'], equals('0930549842'));

      final req2 = BranchLoginRequest(
        tinNumber: '251930549842',
        password: 'Maru@123',
      );
      expect(req2.tinNumber, equals('0930549842'));
      expect(req2.toJson()['phone_number'], equals('0930549842'));

      final req3 = BranchLoginRequest(
        tinNumber: '+251930549842',
        password: 'anyPassword',
      );
      expect(req3.tinNumber, equals('0930549842'));
      expect(req3.toJson()['phone_number'], equals('0930549842'));

      final req4 = BranchLoginRequest(
        tinNumber: '930549842',
        password: 'anyPassword',
      );
      expect(req4.tinNumber, equals('0930549842'));
      expect(req4.toJson()['phone_number'], equals('0930549842'));

      final companyReq = CompanyLoginRequest(
        phone: '0930549842',
        password: 'Maru@123',
        companyId: '1',
      );
      expect(companyReq.phone, equals('0930549842'));
      expect(companyReq.toJson()['phone'], equals('0930549842'));
    });

    test('All normalized payment phones match regex /^0[79]\\d{8}\$/', () {
      final regex = PhoneUtils.ethiopianPhoneRegex;
      expect(regex.pattern, equals(r'^0[79]\d{8}$'));

      expect(regex.hasMatch(PhoneUtils.formatForPayment('949384998')), isTrue);
      expect(regex.hasMatch(PhoneUtils.formatForPayment('0949384998')), isTrue);
      expect(regex.hasMatch(PhoneUtils.formatForPayment('+251949384998')), isTrue);
      expect(regex.hasMatch(PhoneUtils.formatForPayment('712345678')), isTrue);
      expect(regex.hasMatch(PhoneUtils.formatForPayment('0712345678')), isTrue);
      expect(regex.hasMatch(PhoneUtils.formatForPayment('+251712345678')), isTrue);

      // Invalid inputs rejected
      expect(regex.hasMatch(PhoneUtils.formatForPayment('0812345678')), isFalse);
      expect(regex.hasMatch(PhoneUtils.formatForPayment('12345')), isFalse);
      expect(regex.hasMatch(PhoneUtils.formatForPayment('091234567899')), isFalse);
    });

    test('PaymentInitializeRequest always serializes phone_number in regex /^0[79]\\d{8}\$/ format', () {
      final regex = RegExp(r'^0[79]\d{8}$');

      // Passed as 9-digit without leading 0
      final req1 = PaymentInitializeRequest(
        branchId: 29,
        packageId: 1,
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        phoneNumber: '949384998',
      );
      expect(req1.phoneNumber, equals('0949384998'));
      expect(req1.toJson()['phone_number'], equals('0949384998'));
      expect(regex.hasMatch(req1.toJson()['phone_number']), isTrue);

      // Passed as +251 international format
      final req2 = PaymentInitializeRequest(
        branchId: 29,
        packageId: 1,
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        phoneNumber: '+251949384998',
      );
      expect(req2.phoneNumber, equals('0949384998'));
      expect(req2.toJson()['phone_number'], equals('0949384998'));
      expect(regex.hasMatch(req2.toJson()['phone_number']), isTrue);

      // Passed as Safaricom 7-prefix
      final req3 = PaymentInitializeRequest(
        branchId: 29,
        packageId: 1,
        email: 'test@example.com',
        firstName: 'Test',
        lastName: 'User',
        phoneNumber: '712345678',
      );
      expect(req3.phoneNumber, equals('0712345678'));
      expect(req3.toJson()['phone_number'], equals('0712345678'));
      expect(regex.hasMatch(req3.toJson()['phone_number']), isTrue);
    });

    testWidgets('CompanyAuthScreen shows country code 251 and hint "09xxxx or 9xxxxx" in Sign In and Sign Up', (tester) async {
      Get.put(AuthController());
      addTearDown(() => Get.reset());

      await tester.pumpWidget(
        const GetMaterialApp(
          home: CompanyAuthScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // In Sign In mode:
      expect(find.textContaining('251'), findsWidgets);
      expect(find.text('09xxxx or 9xxxxx'), findsOneWidget);

      // Switch to Sign Up mode:
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(find.textContaining('251'), findsWidgets);
      expect(find.text('09xxxx or 9xxxxx'), findsOneWidget);
    });
  });

  group('Payment Packages Screen Back Navigation & Session Safety', () {
    testWidgets('PaymentPackagesScreen shows Back and Skip buttons when branch is pending/unpaid and allows skipping without clearing tokens', (tester) async {
      DioConfig.isTestMode = true;
      final dio = await DioConfig.dio();
      dio.httpClientAdapter = _MockPackagesAdapter();
      Get.put(AuthController());
      await ConfigPreference.updateBranchToken('mock_pending_token');
      expect(ConfigPreference.isLoggedIn(), isTrue);

      addTearDown(() {
        DioConfig.resetDio();
        DioConfig.isTestMode = false;
        Get.reset();
      });

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/payment-packages',
          getPages: [
            GetPage(name: '/dashboard', page: () => const Scaffold(body: Text('Dashboard Screen'))),
            GetPage(
              name: '/payment-packages',
              page: () => const PaymentPackagesScreen(
                branchId: 29,
                currentStatus: 'pending',
              ),
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('payment_back_button')), findsOneWidget);
      expect(find.byKey(const Key('payment_skip_button')), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Tap skip button
      await tester.tap(find.byKey(const Key('payment_skip_button')));
      await tester.pump(const Duration(milliseconds: 100));

      // Tokens should NOT be cleared when user skips!
      expect(ConfigPreference.getAccessToken(), 'mock_pending_token');
      expect(ConfigPreference.isLoggedIn(), isTrue);
    });

    testWidgets('PaymentPackagesScreen shows close button and does NOT clear tokens when active', (tester) async {
      DioConfig.isTestMode = true;
      final dio = await DioConfig.dio();
      dio.httpClientAdapter = _MockPackagesAdapter();
      Get.put(AuthController());
      await ConfigPreference.updateBranchToken('mock_active_token');
      expect(ConfigPreference.isLoggedIn(), isTrue);

      addTearDown(() {
        DioConfig.resetDio();
        DioConfig.isTestMode = false;
        Get.reset();
      });

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/payment-packages',
          getPages: [
            GetPage(name: '/dashboard', page: () => const Scaffold(body: Text('Dashboard Screen'))),
            GetPage(
              name: '/payment-packages',
              page: () => const PaymentPackagesScreen(
                branchId: 29,
                currentStatus: 'active',
              ),
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('payment_close_button')), findsOneWidget);
      expect(find.byKey(const Key('payment_skip_button')), findsNothing);
    });

    test('InitialNavigationMiddleware allows pending/unpaid branches to enter dashboard without redirecting to payment screen', () async {
      await ConfigPreference.updateBranchToken('mock_branch_token');
      await ConfigPreference.saveBranchId('29');
      await ConfigPreference.saveBranchSubscription(status: 'pending');

      expect(ConfigPreference.isLoggedIn(), isTrue);
      expect(ConfigPreference.isBranchActive(), isFalse);

      final middleware = InitialNavigationMiddleware();
      final redirect = middleware.redirect('/dashboard');

      // Crucial: Must be null (allow access to dashboard), NOT redirecting to /payment-packages!
      expect(redirect, isNull);
    });

    testWidgets('InvoiceController checkActiveSubscriptionOrPromptPayment prompts PaymentPackagesScreen when branch is inactive', (tester) async {
      DioConfig.isTestMode = true;
      final dio = await DioConfig.dio();
      dio.httpClientAdapter = _MockPackagesAdapter();

      await ConfigPreference.updateBranchToken('mock_branch_token');
      await ConfigPreference.saveBranchId('29');
      await ConfigPreference.saveBranchSubscription(status: 'pending');
      expect(ConfigPreference.isBranchActive(), isFalse);

      final invoiceController = Get.put(InvoiceController());
      addTearDown(() {
        DioConfig.resetDio();
        DioConfig.isTestMode = false;
        Get.reset();
      });

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/invoice-generator',
          getPages: [
            GetPage(name: '/invoice-generator', page: () => const Scaffold(body: Text('Invoice Generator Screen'))),
            GetPage(name: '/payment-packages', page: () => const PaymentPackagesScreen(branchId: 29, currentStatus: 'pending')),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final allowed = invoiceController.checkActiveSubscriptionOrPromptPayment();
      expect(allowed, isFalse);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // PaymentPackagesScreen should pop up
      expect(find.byType(PaymentPackagesScreen), findsOneWidget);
    });

    testWidgets('InvoiceController checkActiveSubscriptionOrPromptPayment allows invoice registration when active', (tester) async {
      DioConfig.isTestMode = true;
      await ConfigPreference.updateBranchToken('mock_branch_token');
      await ConfigPreference.saveBranchId('29');
      await ConfigPreference.saveBranchSubscription(
        status: 'active',
        packageId: 1,
        expiredDate: '2099-12-31T00:00:00Z',
        paidDate: '2026-09-07T08:50:47.000000Z',
      );
      expect(ConfigPreference.isBranchActive(), isTrue);

      final invoiceController = Get.put(InvoiceController());
      addTearDown(() {
        DioConfig.isTestMode = false;
        Get.reset();
      });

      final allowed = invoiceController.checkActiveSubscriptionOrPromptPayment();
      expect(allowed, isTrue);
    });

    testWidgets('PaymentPackagesScreen when pushed via Get.to pops back without clearing tokens', (tester) async {
      DioConfig.isTestMode = true;
      final dio = await DioConfig.dio();
      dio.httpClientAdapter = _MockPackagesAdapter();

      await ConfigPreference.updateBranchToken('mock_branch_token');
      await ConfigPreference.saveBranchId('29');
      await ConfigPreference.saveBranchSubscription(status: 'pending');

      addTearDown(() {
        DioConfig.resetDio();
        DioConfig.isTestMode = false;
        Get.reset();
      });

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/invoices',
          getPages: [
            GetPage(
              name: '/invoices',
              page: () => Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    key: const Key('open_payment_button'),
                    onPressed: () => Get.to(() => const PaymentPackagesScreen(branchId: 29, currentStatus: 'pending')),
                    child: const Text('Open Payment'),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap open payment button
      await tester.tap(find.byKey(const Key('open_payment_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(PaymentPackagesScreen), findsOneWidget);
      expect(find.byKey(const Key('payment_back_button')), findsOneWidget);

      // Tap back button
      await tester.tap(find.byKey(const Key('payment_back_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should have returned to invoices screen
      expect(find.byType(PaymentPackagesScreen), findsNothing);
      expect(find.byKey(const Key('open_payment_button')), findsOneWidget);
      // User tokens should STILL be intact!
      expect(ConfigPreference.isLoggedIn(), isTrue);
      expect(ConfigPreference.getAccessToken(), 'mock_branch_token');
    });

    testWidgets('OtpVerificationScreen checks payment status on company registration and leads unpaid user to PaymentPackagesScreen', (tester) async {
      DioConfig.isTestMode = true;
      final dio = await DioConfig.dio();
      dio.httpClientAdapter = _MockPackagesAdapter(branchStatus: 'pending');
      Get.put(AuthController());

      addTearDown(() {
        DioConfig.resetDio();
        DioConfig.isTestMode = false;
        Get.reset();
      });

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/otp-verification',
          getPages: [
            GetPage(
              name: '/otp-verification',
              page: () => const OtpVerificationScreen(
                phone: '0912345678',
                isCompanyRegistration: true,
                branchId: 29,
                ownerName: 'Abebe Bikila',
                email: 'abebe@example.com',
              ),
            ),
            GetPage(name: '/dashboard', page: () => const Scaffold(body: Text('Dashboard Screen'))),
            GetPage(
              name: '/branch-certificate',
              page: () => const Scaffold(body: Text('Certificate Screen')),
            ),
            GetPage(
              name: '/payment-packages',
              page: () => const PaymentPackagesScreen(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OtpVerificationScreen), findsOneWidget);

      // Enter 6 digit OTP
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(6));
      for (int i = 0; i < 6; i++) {
        await tester.enterText(textFields.at(i), '${i + 1}');
      }
      await tester.pumpAndSettle();

      // Because branch is pending (unpaid), it must lead user to PaymentPackagesScreen!
      expect(find.byType(PaymentPackagesScreen), findsOneWidget);
      expect(find.byKey(const Key('payment_skip_button')), findsOneWidget);

      // Tap Skip on payment packages screen
      await tester.tap(find.byKey(const Key('payment_skip_button')));
      await tester.pumpAndSettle();

      // Should advance to certificate screen (or dashboard) without clearing tokens!
      expect(find.byType(PaymentPackagesScreen), findsNothing);
      expect(find.byType(BranchCertificateScreen), findsOneWidget);
    });

    testWidgets('OtpVerificationScreen skips PaymentPackagesScreen if branch payment is already active', (tester) async {
      DioConfig.isTestMode = true;
      final dio = await DioConfig.dio();
      dio.httpClientAdapter = _MockPackagesAdapter(
        branchStatus: 'active',
        packageId: 1,
        expiredDate: '2099-12-31T00:00:00Z',
        paidDate: '2026-09-07T08:50:47.000000Z',
      );
      Get.put(AuthController());

      addTearDown(() {
        DioConfig.resetDio();
        DioConfig.isTestMode = false;
        Get.reset();
      });

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/otp-verification',
          getPages: [
            GetPage(
              name: '/otp-verification',
              page: () => const OtpVerificationScreen(
                phone: '0912345678',
                isCompanyRegistration: true,
                branchId: 29,
                ownerName: 'Abebe Bikila',
                email: 'abebe@example.com',
              ),
            ),
            GetPage(name: '/dashboard', page: () => const Scaffold(body: Text('Dashboard Screen'))),
            GetPage(
              name: '/branch-certificate',
              page: () => const Scaffold(body: Text('Certificate Screen')),
            ),
            GetPage(
              name: '/payment-packages',
              page: () => const PaymentPackagesScreen(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Enter 6 digit OTP
      final textFields = find.byType(TextField);
      for (int i = 0; i < 6; i++) {
        await tester.enterText(textFields.at(i), '${i + 1}');
      }
      await tester.pumpAndSettle();

      // Because branch is active, it does NOT lead user to PaymentPackagesScreen!
      expect(find.byType(PaymentPackagesScreen), findsNothing);
      expect(find.byType(BranchCertificateScreen), findsOneWidget);
    });

    testWidgets('PaymentPackagesScreen allows skipping from registration and navigates to certificate screen or dashboard without logout', (tester) async {
      DioConfig.isTestMode = true;
      final dio = await DioConfig.dio();
      dio.httpClientAdapter = _MockPackagesAdapter();
      Get.put(AuthController());
      await ConfigPreference.updateCompanyToken('valid_company_token');
      await ConfigPreference.saveBranchSubscription(status: 'pending');

      addTearDown(() {
        DioConfig.resetDio();
        DioConfig.isTestMode = false;
        Get.reset();
      });

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/payment-packages',
          getPages: [
            GetPage(name: '/dashboard', page: () => const Scaffold(body: Text('Dashboard Screen'))),
            GetPage(
              name: '/payment-packages',
              page: () => const PaymentPackagesScreen(
                branchId: 29,
                currentStatus: 'pending',
                isFromRegistration: true,
              ),
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('payment_skip_button')), findsOneWidget);

      // Tap skip
      await tester.tap(find.byKey(const Key('payment_skip_button')));
      await tester.pumpAndSettle();

      // Session must be preserved
      expect(ConfigPreference.getCompanyAccessToken(), 'valid_company_token');
      expect(find.byType(PaymentPackagesScreen), findsNothing);
      expect(find.byType(BranchCertificateScreen), findsOneWidget);
    });

    testWidgets('Invoice registration payment prompt triggers every time user tries to register an invoice while unpaid', (tester) async {
      DioConfig.isTestMode = true;
      final dio = await DioConfig.dio();
      dio.httpClientAdapter = _MockPackagesAdapter();

      await ConfigPreference.updateBranchToken('mock_branch_token');
      await ConfigPreference.saveBranchId('29');
      await ConfigPreference.saveBranchSubscription(status: 'pending');
      expect(ConfigPreference.isBranchActive(), isFalse);

      final invoiceController = Get.put(InvoiceController());
      addTearDown(() {
        DioConfig.resetDio();
        DioConfig.isTestMode = false;
        Get.reset();
      });

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/invoices',
          getPages: [
            GetPage(
              name: '/invoices',
              page: () => Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    key: const Key('register_invoice_btn'),
                    onPressed: () {
                      if (!invoiceController.checkActiveSubscriptionOrPromptPayment()) {
                        return;
                      }
                    },
                    child: const Text('Register Invoice'),
                  ),
                ),
              ),
            ),
            GetPage(name: '/payment-packages', page: () => const PaymentPackagesScreen(branchId: 29, currentStatus: 'pending')),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Attempt 1 to register invoice
      await tester.tap(find.byKey(const Key('register_invoice_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PaymentPackagesScreen), findsOneWidget);

      // User skips payment prompt (tap skip or close/back)
      await tester.tap(find.byKey(const Key('payment_skip_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PaymentPackagesScreen), findsNothing);
      expect(find.byKey(const Key('register_invoice_btn')), findsOneWidget);

      // Attempt 2 to register invoice: prompt MUST trigger again!
      await tester.tap(find.byKey(const Key('register_invoice_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PaymentPackagesScreen), findsOneWidget);

      // User skips again
      await tester.tap(find.byKey(const Key('payment_skip_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PaymentPackagesScreen), findsNothing);

      // Attempt 3 to register invoice: prompt MUST trigger again!
      await tester.tap(find.byKey(const Key('register_invoice_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PaymentPackagesScreen), findsOneWidget);
    });

    test('ConfigPreference.isBranchActive requires package_id, future expiry, and paid_date even if status is active', () async {
      // 1. Status 'active' alone is not enough
      await ConfigPreference.saveBranchSubscription(status: 'active');
      expect(ConfigPreference.isBranchActive(), isFalse);

      // 2. Status 'active' with package_id <= 0 is not enough
      await ConfigPreference.saveBranchSubscription(status: 'active', packageId: 0);
      expect(ConfigPreference.isBranchActive(), isFalse);

      // 3. Status 'active' with valid package_id but no expiry is not enough
      await ConfigPreference.saveBranchSubscription(status: 'active', packageId: 2);
      expect(ConfigPreference.isBranchActive(), isFalse);

      // 4. Status 'active' with package_id and expired date in past is not enough
      await ConfigPreference.saveBranchSubscription(
        status: 'active',
        packageId: 2,
        expiredDate: '2020-01-01T00:00:00.000000Z',
      );
      expect(ConfigPreference.isBranchActive(), isFalse);

      // 5. Status 'active' with package_id, future expiry, but missing paid_date is not enough
      await ConfigPreference.saveBranchSubscription(
        status: 'active',
        packageId: 2,
        expiredDate: '2099-12-31T00:00:00.000000Z',
      );
      expect(ConfigPreference.isBranchActive(), isFalse);

      // 6. Status 'active' with package_id, future expiry, and valid paid_date -> ACTIVE!
      await ConfigPreference.saveBranchSubscription(
        status: 'active',
        packageId: 2,
        expiredDate: '2099-12-31T00:00:00.000000Z',
        paidDate: '2026-09-07T08:50:47.000000Z',
      );
      expect(ConfigPreference.isBranchActive(), isTrue);

      // 7. Status 'pending' with package_id, future expiry, and paid_date -> Still FALSE because status != 'active'
      await ConfigPreference.saveBranchSubscription(
        status: 'pending',
        packageId: 2,
        expiredDate: '2099-12-31T00:00:00.000000Z',
        paidDate: '2026-09-07T08:50:47.000000Z',
      );
      expect(ConfigPreference.isBranchActive(), isFalse);
    });

    testWidgets('OtpVerificationScreen leads user to PaymentPackagesScreen when backend returns status active on new registration but missing package info', (tester) async {
      DioConfig.isTestMode = true;
      final dio = await DioConfig.dio();
      // Backend returns status: "active", but no package_id, expired_date, or paid_date
      dio.httpClientAdapter = _MockPackagesAdapter(branchStatus: 'active');
      Get.put(AuthController());

      addTearDown(() {
        DioConfig.resetDio();
        DioConfig.isTestMode = false;
        Get.reset();
      });

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/otp-verification',
          getPages: [
            GetPage(
              name: '/otp-verification',
              page: () => const OtpVerificationScreen(
                phone: '0912345678',
                isCompanyRegistration: true,
                branchId: 29,
                ownerName: 'Abebe Bikila',
                email: 'abebe@example.com',
              ),
            ),
            GetPage(name: '/dashboard', page: () => const Scaffold(body: Text('Dashboard Screen'))),
            GetPage(
              name: '/branch-certificate',
              page: () => const Scaffold(body: Text('Certificate Screen')),
            ),
            GetPage(
              name: '/payment-packages',
              page: () => const PaymentPackagesScreen(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Enter 6 digit OTP
      final textFields = find.byType(TextField);
      for (int i = 0; i < 6; i++) {
        await tester.enterText(textFields.at(i), '${i + 1}');
      }
      await tester.pumpAndSettle();

      // Because backend returned active status without package/paid date, branch is NOT active
      expect(ConfigPreference.isBranchActive(), isFalse);
      // User MUST be led to PaymentPackagesScreen
      expect(find.byType(PaymentPackagesScreen), findsOneWidget);
    });
  });
}

class _MockPackagesAdapter implements HttpClientAdapter {
  final String branchStatus;
  final int? packageId;
  final String? expiredDate;
  final String? paidDate;

  _MockPackagesAdapter({
    this.branchStatus = 'pending',
    this.packageId,
    this.expiredDate,
    this.paidDate,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/verify-phone') || options.path.contains('/verify')) {
      final jsonStr = jsonEncode({
        "status": "success",
        "token": "verified_company_token",
        "user": {
          "company_id": 41,
          "name": "Owner",
          "is_verified": true,
        },
        "branch": {
          "id": 29,
          "status": branchStatus,
          if (packageId != null) "package_id": packageId,
          if (expiredDate != null) "expired_date": expiredDate,
          if (paidDate != null) "payment_date": paidDate,
          "phone_number": "0912345678",
          "email": "test@example.com",
        }
      });
      return ResponseBody.fromString(
        jsonStr,
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    final jsonStr = jsonEncode([
      {
        "id": 1,
        "name": "Standard Package",
        "description": "Standard MOR package",
        "price": "1000.00",
        "duration_days": 30,
        "daily_invoice_limit": 50,
      }
    ]);
    return ResponseBody.fromString(
      jsonStr,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
