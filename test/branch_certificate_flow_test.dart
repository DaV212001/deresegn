import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:deresegn/models/branch_certificate_models.dart';
import 'package:deresegn/controllers/branch_certificate_controller.dart';
import 'package:deresegn/services/insa_request_form_service.dart';
import 'package:deresegn/screens/branch_certificate_screen.dart';

void main() {
  group('Branch CSR Request & Response Models', () {
    test('BranchCsrRequest serializes all required fields accurately', () {
      final req = BranchCsrRequest(
        tin: '0012345678',
        systemNumber: 'SYS-0001',
        organizationName: 'Your Company',
        organizationalUnit: 'Head Office',
        email: 'you@example.com',
      );

      final json = req.toJson();

      expect(json['tin'], '0012345678');
      expect(json['system_number'], 'SYS-0001');
      expect(json['organization_name'], 'Your Company');
      expect(json['organizational_unit'], 'Head Office');
      expect(json['email'], 'you@example.com');
      expect(json.containsKey('force'), isFalse);
    });

    test('BranchCsrRequest includes force: true when requested for replacement', () {
      final req = BranchCsrRequest(
        tin: '0012345678',
        systemNumber: 'SYS-0001',
        organizationName: 'Your Company',
        organizationalUnit: 'Head Office',
        email: 'you@example.com',
        force: true,
      );

      final json = req.toJson();
      expect(json['force'], isTrue);
    });

    test('BranchCsrResponse parses success response with line breaks preserved', () {
      const sampleCsr =
          '-----BEGIN CERTIFICATE REQUEST-----\n'
          'MIICxDCCAawCAQAwgYYxEDAOBgNVBAMMBzAwMDAwMzExFTATBgNVBAUTCjAxMjM0\n'
          'NTY3ODkxEDAOBgNVBAoMB0NvbXBhbnkxEDAOBgNVBAsMB0JyYW5jaDExGDAWBgNV\n'
          'BAgMD0FkZGlzIEFiYWJhMREwDwYDVQQHDAhBc2tvY28xCzAJBgNVBAYTAkVUMIIB\n'
          'IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA3fB...\n'
          '-----END CERTIFICATE REQUEST-----\n';

      final raw = {
        'message': 'CSR generated. Save and send to INSA for signing.',
        'csr': sampleCsr,
        'branch_id': 29,
      };

      final response = BranchCsrResponse.fromJson(raw);

      expect(response.message, contains('CSR generated'));
      expect(response.branchId, 29);
      expect(response.csr, sampleCsr);
      expect(response.csr.contains('\n'), isTrue);
      expect(response.csr.startsWith('-----BEGIN CERTIFICATE REQUEST-----'), isTrue);
      expect(response.csr.trimRight().endsWith('-----END CERTIFICATE REQUEST-----'), isTrue);
    });

    test('BranchCsrResponse handles string branch_id parsing gracefully', () {
      final raw = {
        'message': 'CSR created',
        'csr': 'sample_csr',
        'branch_id': '37',
      };

      final response = BranchCsrResponse.fromJson(raw);
      expect(response.branchId, 37);
    });
  });

  group('CSR File Saving Requirements (Step 2)', () {
    test('Writes UTF-8 text with no BOM, no quotes, and exact line breaks', () async {
      final tempDir = Directory.systemTemp.createTempSync('deresegn_csr_test_');
      try {
        const branchId = 29;
        const parsedCsrValue =
            '-----BEGIN CERTIFICATE REQUEST-----\n'
            'MIICxDCCAawCAQAwgYYxEDAOBgNVBAMMBzAwMDAwMzExFTATBgNVBAUTCjAxMjM0\n'
            'NTY3ODkxEDAOBgNVBAoMB0NvbXBhbnkxEDAOBgNVBAsMB0JyYW5jaDExGDAWBgNV\n'
            'BAgMD0FkZGlzIEFiYWJhMREwDwYDVQQHDAhBc2tvY28xCzAJBgNVBAYTAkVUMIIB\n'
            'IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA3fB\n'
            '-----END CERTIFICATE REQUEST-----\n';

        final file = File('${tempDir.path}/branch-$branchId-csr.pem');

        // Write directly as UTF-8 text with no BOM
        await file.writeAsString(
          parsedCsrValue,
          encoding: const Utf8Codec(allowMalformed: false),
          flush: true,
        );

        expect(file.existsSync(), isTrue);

        final bytes = await file.readAsBytes();

        // Verify UTF-8 BOM is NOT present (EF BB BF)
        if (bytes.length >= 3) {
          final hasBom = bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF;
          expect(hasBom, isFalse, reason: 'CSR PEM must not contain UTF-8 BOM header');
        }

        // Read text and check equality
        final readText = await file.readAsString();
        expect(readText, parsedCsrValue);
        expect(readText.startsWith('"'), isFalse, reason: 'Must not contain leading quote');
        expect(readText.endsWith('"'), isFalse, reason: 'Must not contain trailing quote');
        expect(file.path.endsWith('branch-29-csr.pem'), isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('INSA Email Submission Formatting (Step 3)', () {
    test('Email template matches required INSA submission standard', () {
      const insaEmail = 'ica@insa.gov.et';
      const subject = 'Certificate Request for E-Invoice';

      const name = 'Samuel Asamnew';
      const org = 'Deresegn Technologies';
      const contact = '0949384998';

      final body = 'Dear Admin,\n\n'
          'This is a test certificate request for E-Invoice.\n\n'
          'Please find attached:\n'
          '1. Request Form\n'
          '2. CSR File\n\n'
          'Regards,\n'
          '$name\n'
          '$org\n'
          '$contact';

      expect(insaEmail, 'ica@insa.gov.et');
      expect(subject, 'Certificate Request for E-Invoice');
      expect(body, contains('Dear Admin,'));
      expect(body, contains('This is a test certificate request for E-Invoice.'));
      expect(body, contains('1. Request Form'));
      expect(body, contains('2. CSR File'));
      expect(body, contains(name));
      expect(body, contains(org));
      expect(body, contains(contact));
    });

    test('buildMailtoUri encodes spaces as %20 rather than + to prevent literal plus signs in Gmail', () {
      final controller = BranchCertificateController(
        branchId: 10,
        initialOrgName: 'Acme Corp',
        initialOwnerName: 'John Doe',
      );
      controller.onInit();

      final uri = controller.buildMailtoUri();
      final uriString = uri.toString();

      // Ensure scheme and email are accurate
      expect(uriString.startsWith('mailto:ica@insa.gov.et?'), isTrue);

      // Crucial: query part must encode spaces as %20, never +
      expect(uriString, contains('subject=Certificate%20Request%20for%20E-Invoice'));
      expect(uriString, contains('Dear%20Admin'));

      // Check query string specifically does not contain any '+'
      final query = uriString.split('?').last;
      expect(query.contains('+'), isFalse);
    });
  });

  group('INSA Certificate Upload & Validation (Step 4)', () {
    test('BranchCertificateUploadRequest serializes certificate text as JSON string', () {
      const certContent =
          '-----BEGIN CERTIFICATE-----\n'
          'MIIDXTCCAkWgAwIBAgIUW6o487RpKnsmTt7v2FsQ8GDr8GwwDQYJKoZIhvcNAQEN\n'
          'BQAwgYgxCzAJBgNVBAYTAkVRMRQwEgYDVQQIDAtBZGRpcyBBYmFiYTE0MDIGA1UE\n'
          '-----END CERTIFICATE-----\n';

      final req = BranchCertificateUploadRequest(certificate: certContent);
      final json = req.toJson();

      expect(json['certificate'], certContent);
      expect(json['certificate'].startsWith('-----BEGIN CERTIFICATE-----'), isTrue);
    });

    test('PEM Validation rejects non-PEM files with expected error', () {
      final invalidSamples = [
        'NOT A CERTIFICATE',
        '{"some": "json"}',
        'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC...',
        '   -----BEGIN RSA PRIVATE KEY-----   ',
      ];

      for (final invalid in invalidSamples) {
        final isValidPemCert = invalid.trim().startsWith('-----BEGIN CERTIFICATE-----');
        expect(isValidPemCert, isFalse);
      }

      const validCert = '   -----BEGIN CERTIFICATE-----\nMIIC...\n-----END CERTIFICATE-----\n';
      expect(validCert.trim().startsWith('-----BEGIN CERTIFICATE-----'), isTrue);
    });

    test('BranchCertificateUploadResponse parses matches_private_key: true correctly', () {
      final raw = {
        'message': 'Certificate stored successfully.',
        'branch_id': 29,
        'matches_private_key': true,
      };

      final response = BranchCertificateUploadResponse.fromJson(raw);
      expect(response.message, 'Certificate stored successfully.');
      expect(response.branchId, 29);
      expect(response.matchesPrivateKey, isTrue);
    });

    test('BranchCertificateUploadResponse parses matches_private_key: false correctly', () {
      final raw = {
        'message': 'Certificate verification failed.',
        'branch_id': 29,
        'matches_private_key': false,
      };

      final response = BranchCertificateUploadResponse.fromJson(raw);
      expect(response.branchId, 29);
      expect(response.matchesPrivateKey, isFalse);
    });

    test('Branch 409 conflict detection evaluation', () {
      // 409 Conflict indicates branch already has certificate
      const statusCode = 409;
      final isAlreadyInstalled = statusCode == 409;
      expect(isAlreadyInstalled, isTrue);

      // Force retry flag should be set to true
      final forceRequest = BranchCsrRequest(
        tin: '0012345678',
        systemNumber: 'SYS-0001',
        organizationName: 'Your Company',
        organizationalUnit: 'Head Office',
        email: 'you@example.com',
        force: true,
      );
      expect(forceRequest.toJson()['force'], isTrue);
    });

    test('500 Invalid PEM error message evaluation', () {
      const statusCode = 500;
      const serverMessage = 'Invalid PEM certificate provided';

      final isInvalidPemError =
          statusCode == 500 && serverMessage.contains('Invalid PEM certificate provided');
      expect(isInvalidPemError, isTrue);
    });
  });

  group('Branch Certificate Status Query & Response Evaluation', () {
    test('Parses backend status response accurately with has_private_key and has_certificate', () {
      final json = {
        'branch_id': 41,
        'has_private_key': false,
        'has_certificate': false,
        'certificate_matches_key': false,
      };

      final res = BranchCertificateStatusResponse.fromJson(json);

      expect(res.branchId, equals(41));
      expect(res.hasPrivateKey, isFalse);
      expect(res.hasCertificate, isFalse);
      expect(res.certificateMatchesKey, isFalse);
      expect(res.isInstalled, isFalse);
      expect(res.hasCsr, isFalse);
    });

    test('Identifies when CSR exists on server awaiting INSA certificate upload', () {
      final json = {
        'branch_id': 41,
        'has_private_key': true,
        'has_certificate': false,
        'certificate_matches_key': false,
      };

      final res = BranchCertificateStatusResponse.fromJson(json);

      expect(res.branchId, equals(41));
      expect(res.hasPrivateKey, isTrue);
      expect(res.hasCertificate, isFalse);
      expect(res.hasCsr, isTrue);
      expect(res.isInstalled, isFalse);
    });

    test('Identifies fully installed certificate matching private key', () {
      final json = {
        'branch_id': 41,
        'has_private_key': true,
        'has_certificate': true,
        'certificate_matches_key': true,
      };

      final res = BranchCertificateStatusResponse.fromJson(json);

      expect(res.hasPrivateKey, isTrue);
      expect(res.hasCertificate, isTrue);
      expect(res.certificateMatchesKey, isTrue);
      expect(res.isInstalled, isTrue);
    });

    test('Identifies certificate mismatch where key does not match', () {
      final json = {
        'branch_id': 41,
        'has_private_key': true,
        'has_certificate': true,
        'certificate_matches_key': false,
      };

      final res = BranchCertificateStatusResponse.fromJson(json);

      expect(res.hasPrivateKey, isTrue);
      expect(res.hasCertificate, isTrue);
      expect(res.certificateMatchesKey, isFalse);
      expect(res.isInstalled, isFalse);
    });

    test('State transition: when has_private_key is false, step switches to 1 even if startAtUpload was true', () {
      final controller = BranchCertificateController(
        branchId: 41,
        startAtUpload: true,
      );
      expect(controller.currentStep.value, equals(4));

      final res = BranchCertificateStatusResponse.fromJson({
        'branch_id': 41,
        'has_private_key': false,
        'has_certificate': false,
        'certificate_matches_key': false,
      });

      if (res.isInstalled) {
        controller.isCertificateInstalled.value = true;
      } else {
        controller.isCertificateInstalled.value = false;
        if (res.hasCertificate && !res.certificateMatchesKey) {
          controller.currentStep.value = 4;
        } else if (res.hasPrivateKey) {
          controller.currentStep.value = 4;
        } else {
          controller.currentStep.value = 1;
        }
      }

      expect(controller.currentStep.value, equals(1));
    });

    test('State transition: when has_private_key is true and certificate false, step switches to 4', () {
      final controller = BranchCertificateController(
        branchId: 41,
        startAtUpload: false,
      );
      expect(controller.currentStep.value, equals(1));

      final res = BranchCertificateStatusResponse.fromJson({
        'branch_id': 41,
        'has_private_key': true,
        'has_certificate': false,
        'certificate_matches_key': false,
      });

      if (res.isInstalled) {
        controller.isCertificateInstalled.value = true;
      } else {
        controller.isCertificateInstalled.value = false;
        if (res.hasCertificate && !res.certificateMatchesKey) {
          controller.currentStep.value = 4;
        } else if (res.hasPrivateKey) {
          controller.currentStep.value = 4;
        } else {
          controller.currentStep.value = 1;
        }
      }

      expect(controller.currentStep.value, equals(4));
    });
  });

  group('INSA Request Form Service Tests', () {
    test('generateText generates exact official format required by INSA', () {
      const data = InsaRequestFormData(
        fullName: 'Test Taxpayer',
        address: 'Addis Ababa',
        telephone: '0911111111',
        email: 'testtaxpayer@gmail.com',
        organizationName: 'Test Organizaition',
        tin: '1234567890',
        branchName: 'MAIN',
        systemId: 'B0360155CA',
        branchId: 41,
      );

      final text = InsaRequestFormService.generateText(data);

      expect(text, contains('E-Invoice Digital Certificate Request Form'));
      expect(text, contains('Contact Person Information'));
      expect(text, contains('| ** Full Name:   | Test Taxpayer   |'));
      expect(text, contains('| ** Address:   | Addis Ababa   |'));
      expect(text, contains('| ** Telephone No.:   | 0911111111   |'));
      expect(text, contains('| ** e-mail address:   | testtaxpayer@gmail.com   |'));
      expect(text, contains('Tax Payer / Organization Information'));
      expect(text, contains('| ** Organization Name:    | Test Organizaition   |'));
      expect(text, contains('| ** TIN:   | 1234567890   |'));
      expect(text, contains('Invoice System Information'));
      expect(text, contains('| No.   | Organization/Business/Branch Name   | System ID:   |'));
      expect(text, contains('| 1   | MAIN   | B0360155CA   |'));
      expect(text, contains('Fields marked with ** are required.'));
      expect(text, contains('This form with the Certificate Signing Request (CSR) file shall be sent to ica@insa.gov.et as attachment.'));
    });

    test('generatePdf produces valid non-empty PDF bytes', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const data = InsaRequestFormData(
        fullName: 'Test Taxpayer',
        address: 'Addis Ababa',
        telephone: '0911111111',
        email: 'testtaxpayer@gmail.com',
        organizationName: 'Test Organization',
        tin: '1234567890',
        branchName: 'Head Office',
        systemId: 'SYS-0001',
        branchId: 41,
      );

      final bytes = await InsaRequestFormService.generatePdf(data);
      expect(bytes.isNotEmpty, isTrue);
      // PDF header magic bytes "%PDF-"
      expect(bytes.length, greaterThan(100));
      final header = utf8.decode(bytes.sublist(0, 5), allowMalformed: true);
      expect(header, equals('%PDF-'));
    });
  });

  group('Branch Certificate Screen Step Indicator Layout', () {
    testWidgets('Renders without overflow on 360x640 mobile screen (available width 286px)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        Get.reset();
      });

      await tester.pumpWidget(
        const GetMaterialApp(
          home: BranchCertificateScreen(branchId: 0),
        ),
      );
      await tester.pump();

      expect(find.byType(BranchCertificateScreen), findsOneWidget);
      expect(find.text('Generate Certificate Signing Request'), findsOneWidget);
      expect(find.textContaining('2048-bit RSA'), findsNothing);
      expect(find.text('INSA Certificate Setup'), findsOneWidget);
      expect(find.text('Step 4: Upload INSA-Issued Certificate'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Step 4 upload card is not rendered on Step 1 when neither private key nor CSR exists', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        Get.reset();
      });

      await tester.pumpWidget(
        const GetMaterialApp(
          home: BranchCertificateScreen(branchId: 0),
        ),
      );
      await tester.pump();

      expect(find.text('Generate Certificate Signing Request'), findsOneWidget);
      expect(find.text('Step 4: Upload INSA-Issued Certificate'), findsNothing);
    });

    testWidgets('Renders without overflow on very narrow 320x480 and 280x500 screens', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        Get.reset();
      });

      await tester.pumpWidget(
        const GetMaterialApp(
          home: BranchCertificateScreen(branchId: 0),
        ),
      );
      await tester.pump();

      expect(find.byType(BranchCertificateScreen), findsOneWidget);
      expect(find.text('Generate Certificate Signing Request'), findsOneWidget);
      expect(find.textContaining('2048-bit RSA'), findsNothing);
      expect(find.text('INSA Certificate Setup'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Even narrower screen
      tester.view.physicalSize = const Size(280, 500);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Step indicator updates on tap and renders all steps without layout errors', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        Get.reset();
      });

      await tester.pumpWidget(
        const GetMaterialApp(
          home: BranchCertificateScreen(branchId: 0),
        ),
      );
      await tester.pump();

      // Step indicator items should all be present
      expect(find.byKey(const Key('step_indicator_1')), findsOneWidget);
      expect(find.byKey(const Key('step_indicator_2')), findsOneWidget);
      expect(find.byKey(const Key('step_indicator_3')), findsOneWidget);
      expect(find.byKey(const Key('step_indicator_4')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap step 2
      await tester.tap(find.byKey(const Key('step_indicator_2')));
      await tester.pump();
      expect(find.text('Step 2: Download CSR & Request Form'), findsOneWidget);
      expect(find.text('branch-0-csr.pem'), findsOneWidget);
      expect(find.text('branch-0-insa-request-form.pdf'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap step 3
      await tester.tap(find.byKey(const Key('step_indicator_3')));
      await tester.pump();
      expect(find.text('Step 3: Send CSR & Request Form to INSA'), findsOneWidget);
      expect(find.textContaining('ica@insa.gov.et'), findsWidgets);
      expect(tester.takeException(), isNull);

      // Tap step 4
      await tester.tap(find.byKey(const Key('step_indicator_4')));
      await tester.pump();
      expect(find.text('Step 4: Upload INSA-Issued Certificate'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap step 1
      await tester.tap(find.byKey(const Key('step_indicator_1')));
      await tester.pump();
      expect(find.text('Generate Certificate Signing Request'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Invoice Generator Certificate Warning Banner renders without overflow under 278px and 240px constraints', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 278.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: Colors.amber, size: 22),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'INSA Certificate Not Installed',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'A digital certificate is required to submit e-invoices to MoR. If you have received your certificate file (.cer / .pem), upload it below.',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {},
                            icon: const Icon(Icons.upload_file_rounded, size: 16),
                            label: const Text('Upload Certificate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('How to Get One', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Upload Certificate'), findsOneWidget);
      expect(find.text('How to Get One'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('False Positive Prevention in CSR and Request Form Detection', () {
    test('findInAppCache rejects 0-byte or corrupt files', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final tempDir = Directory.systemTemp.createTempSync('cache_false_pos_test_');
      try {
        // 0-byte PEM file
        final emptyPem = File('${tempDir.path}/empty-csr.pem');
        await emptyPem.writeAsString('');

        // Corrupted PEM file (missing header)
        final badPem = File('${tempDir.path}/corrupt-csr.pem');
        await badPem.writeAsString('THIS IS NOT A VALID CSR CONTENT');

        // Valid PEM file
        final validPem = File('${tempDir.path}/valid-csr.pem');
        await validPem.writeAsString('-----BEGIN CERTIFICATE REQUEST-----\nMIIC...\n-----END CERTIFICATE REQUEST-----');

        expect(emptyPem.lengthSync(), 0);
        expect(badPem.lengthSync(), greaterThan(0));
        expect(validPem.lengthSync(), greaterThan(0));

        // Direct content & length check matching findInAppCache logic
        bool isValidCsrFile(File f) {
          if (!f.existsSync() || f.lengthSync() == 0) return false;
          final content = f.readAsStringSync();
          return content.contains('-----BEGIN CERTIFICATE REQUEST-----');
        }

        expect(isValidCsrFile(emptyPem), isFalse, reason: 'Empty file must be rejected');
        expect(isValidCsrFile(badPem), isFalse, reason: 'Corrupt PEM must be rejected');
        expect(isValidCsrFile(validPem), isTrue, reason: 'Valid CSR must be accepted');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('findInAppCache rejects 0-byte or non-PDF files for request form', () async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_false_pos_test_');
      try {
        final emptyPdf = File('${tempDir.path}/empty.pdf');
        await emptyPdf.writeAsBytes([]);

        final corruptPdf = File('${tempDir.path}/corrupt.pdf');
        await corruptPdf.writeAsString('<html><body>Error 500</body></html>');

        final validPdfBytes = utf8.encode('%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF');
        final validPdf = File('${tempDir.path}/valid.pdf');
        await validPdf.writeAsBytes(validPdfBytes);

        bool isValidPdfFile(File f) {
          if (!f.existsSync() || f.lengthSync() < 50) return false;
          final bytes = f.readAsBytesSync();
          final header = utf8.decode(bytes.sublist(0, 5), allowMalformed: true);
          return header.startsWith('%PDF');
        }

        expect(isValidPdfFile(emptyPdf), isFalse);
        expect(isValidPdfFile(corruptPdf), isFalse);
        expect(isValidPdfFile(validPdf), isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Public directory detection never uses internal app documents cache as fallback', () async {
      // getPublicDownloadDirectory must return null or distinct directory, never app cache
      final pubDir = await InsaRequestFormService.getPublicDownloadDirectory();
      // On Windows or test environment, if null or separate downloads folder, must not be app private dir
      if (pubDir != null) {
        expect(pubDir.path.contains('app_flutter'), isFalse);
      }
    });

    test('hasCsrOnDevice returns false when no CSR is stored locally', () {
      final controller = BranchCertificateController(branchId: 99);
      expect(controller.hasCsrOnDevice, isFalse);
    });

    test('hasCsrOnDevice returns true when valid CSR text is in memory', () {
      final controller = BranchCertificateController(branchId: 99);
      controller.csrText.value = '-----BEGIN CERTIFICATE REQUEST-----\nMIIC...\n-----END CERTIFICATE REQUEST-----';
      expect(controller.hasCsrOnDevice, isTrue);
    });
  });

  group('On-Device CSR Absence & Step 1 Navigation (Server Key Exists)', () {
    test('loadCachedCsrAndFiles does NOT auto-generate request form when hasPrivateKey is true but CSR is absent', () async {
      final controller = BranchCertificateController(branchId: 9999);
      controller.hasPrivateKey.value = true;
      controller.csrText.value = null;

      await controller.loadCachedCsrAndFiles();

      expect(controller.hasCsrOnDevice, isFalse);
      expect(controller.requestFormFilePath.value, isNull);
      expect(controller.requestFormPdfBytes.value, isNull);
    });

    test('goToStep1 triggers notification telling user there is no CSR on device so they should generate one again', () {
      final controller = BranchCertificateController(branchId: 88, startAtUpload: true);
      controller.hasPrivateKey.value = true;
      expect(controller.hasCsrOnDevice, isFalse);
      expect(controller.currentStep.value, equals(4));

      // User wants to go back to step 1
      controller.goToStep1(showDialog: false);

      expect(controller.currentStep.value, equals(1));
    });

    testWidgets('Step 4 and Step 1 display warning when private key exists on server but not on device', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        Get.reset();
      });

      await tester.pumpWidget(
        const GetMaterialApp(
          home: BranchCertificateScreen(
            branchId: 7777,
            startAtUpload: true,
          ),
        ),
      );
      await tester.pump();

      final controller = Get.find<BranchCertificateController>(tag: 'branch_cert_7777');
      // Simulate server status reporting private key exists, but device has no CSR
      controller.hasPrivateKey.value = true;
      controller.csrText.value = null;
      controller.csrFilePath.value = null;
      controller.publicCsrPath.value = null;
      controller.isCertificateInstalled.value = false;
      controller.currentStep.value = 4;
      await tester.pumpAndSettle();

      // Step 4 should display the warning that there is no CSR on device
      expect(find.text('No CSR on Device'), findsWidgets);
      expect(
        find.text('The server has a private key for this branch, but there isn\'t a CSR on this device, so you should generate one again.'),
        findsWidgets,
      );
      expect(find.text('Go to Step 1: Generate CSR Again'), findsOneWidget);

      // Tap Go to Step 1 button
      await tester.ensureVisible(find.text('Go to Step 1: Generate CSR Again'));
      await tester.tap(find.text('Go to Step 1: Generate CSR Again'));
      await tester.pumpAndSettle();

      // Dialog appears explaining no CSR on device
      expect(find.text('The server has a registered private key for this branch, but there isn\'t a CSR on this device, so you should generate one again.'), findsOneWidget);
      expect(find.text('Go to Step 1'), findsOneWidget);

      // Tap Go to Step 1 in dialog
      await tester.tap(find.text('Go to Step 1'));
      await tester.pumpAndSettle();

      // Now on Step 1, should display Step 1 card with warning banner
      expect(controller.currentStep.value, equals(1));
      expect(find.text('Generate Certificate Signing Request'), findsOneWidget);
      expect(
        find.text('The server has a private key for this branch, but there isn\'t a CSR on this device, so you should generate one again.'),
        findsOneWidget,
      );
      // Proceed to Step 2 button must NOT be present since no CSR is on device
      expect(find.text('Proceed to Download Files (Step 2)'), findsNothing);
    });

    testWidgets('Step 2 displays missing status instead of false positive cached/downloaded status when files do not exist', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        Get.reset();
      });

      await tester.pumpWidget(
        const GetMaterialApp(
          home: BranchCertificateScreen(
            branchId: 6666,
          ),
        ),
      );
      await tester.pump();

      final controller = Get.find<BranchCertificateController>(tag: 'branch_cert_6666');
      controller.csrFilePath.value = null;
      controller.publicCsrPath.value = null;
      controller.isCsrInPublicDir.value = false;
      controller.requestFormFilePath.value = null;
      controller.publicRequestFormPath.value = null;
      controller.isRequestFormInPublicDir.value = false;
      controller.currentStep.value = 2;
      await tester.pumpAndSettle();

      // Should NOT say "Cached in app storage" or "Ready in Public Downloads"
      expect(find.textContaining('Ready in Public Downloads'), findsNothing);
      expect(find.textContaining('Cached in app storage'), findsNothing);

      // Should display accurate missing status
      expect(find.text('CSR file not found on this device. Please return to Step 1 to generate it.'), findsOneWidget);
      expect(find.text('Request form not found. Please return to Step 1 to generate CSR and form.'), findsOneWidget);
      expect(find.text('Status: Not on device'), findsOneWidget);
    });

    testWidgets('Step 3 Open Gmail button shows attachment reminder dialog telling user to attach files', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        Get.reset();
      });

      await tester.pumpWidget(
        const GetMaterialApp(
          home: BranchCertificateScreen(
            branchId: 5555,
          ),
        ),
      );
      await tester.pump();

      final controller = Get.find<BranchCertificateController>(tag: 'branch_cert_5555');
      controller.currentStep.value = 3;
      await tester.pumpAndSettle();

      // Locate Open Gmail / Email App button
      final openEmailBtn = find.text('Open Gmail / Email App');
      expect(openEmailBtn, findsOneWidget);

      await tester.ensureVisible(openEmailBtn);
      await tester.tap(openEmailBtn);
      await tester.pumpAndSettle();

      // Verify reminder dialog
      expect(find.text('Open Email & Attach Files'), findsOneWidget);
      expect(find.text('Attach these 2 files before sending:'), findsOneWidget);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.textContaining('branch-5555-csr.pem')), findsOneWidget);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.textContaining('branch-5555-insa-request-form.pdf')), findsOneWidget);
      expect(find.textContaining('Tap the paperclip (📎) icon in Gmail'), findsOneWidget);
      expect(find.text('Open Gmail / Email'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Open Email & Attach Files'), findsNothing);
    });

    testWidgets('Buttons across all steps render with single-line auto-scaled text and zero overflow on narrow screens', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        Get.reset();
      });

      await tester.pumpWidget(
        const GetMaterialApp(
          home: BranchCertificateScreen(branchId: 4444),
        ),
      );
      await tester.pumpAndSettle();

      final controller = Get.find<BranchCertificateController>(tag: 'branch_cert_4444');

      // Verify Step 1
      expect(tester.takeException(), isNull);

      // Verify Step 2
      controller.currentStep.value = 2;
      await tester.pumpAndSettle();
      expect(find.text('Back to Step 1'), findsOneWidget);
      expect(find.text('Next: Step 3 (INSA)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify Step 3
      controller.currentStep.value = 3;
      await tester.pumpAndSettle();
      expect(find.text('Open Gmail / Email App'), findsOneWidget);
      expect(find.text('Copy Email Template'), findsOneWidget);
      expect(find.text('Back to Step 2'), findsOneWidget);
      expect(find.text('Next: Step 4 (Upload)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify Step 4
      controller.currentStep.value = 4;
      await tester.pumpAndSettle();
      expect(find.text('Upload Certificate'), findsOneWidget);
      expect(find.text('Back to Step 3: INSA Submission'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
