import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart' as dio_lib;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_settings.dart';
import '../config/config_preference.dart';
import '../models/branch_certificate_models.dart';
import '../screens/pdf_preview_screen.dart';
import '../services/api_service.dart';
import '../services/insa_request_form_service.dart';

class BranchCertificateController extends GetxController {
  final int branchId;
  final String initialTin;
  final String initialOrgName;
  final String initialOrgUnit;
  final String initialEmail;
  final String initialSystemNumber;
  final String initialOwnerName;
  final String initialPhone;
  final bool startAtUpload;

  BranchCertificateController({
    required this.branchId,
    this.initialTin = '',
    this.initialOrgName = '',
    this.initialOrgUnit = 'Head Office',
    this.initialEmail = '',
    this.initialSystemNumber = 'SYS-0001',
    this.initialOwnerName = '',
    this.initialPhone = '',
    this.startAtUpload = false,
  }) {
    currentStep = (startAtUpload ? 4 : 1).obs;
  }

  // State
  late final RxInt currentStep; // 1: CSR, 2: Saved PEM & Form, 3: Email INSA, 4: Upload Cert
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final successMessage = RxnString();

  // Step 1 & 2 CSR details
  final csrText = RxnString();
  final csrFilePath = RxnString();
  final publicCsrPath = RxnString();
  final isCsrInPublicDir = false.obs;
  final is409Conflict = false.obs;
  final hasLocalCsr = false.obs;

  /// Returns whether a valid CSR is available locally on this device
  /// (either stored in memory, SharedPreferences, app cache file, or public downloads file).
  bool get hasCsrOnDevice {
    final text = csrText.value;
    final hasValidText = text != null &&
        text.isNotEmpty &&
        text.contains('-----BEGIN CERTIFICATE REQUEST-----');
    final hasCacheFile = csrFilePath.value != null && csrFilePath.value!.isNotEmpty;
    final hasPubFile = publicCsrPath.value != null && publicCsrPath.value!.isNotEmpty;
    return hasValidText || hasCacheFile || hasPubFile;
  }

  // Step 2 INSA Request Form details
  final publicRequestFormPath = RxnString();
  final isRequestFormInPublicDir = false.obs;
  final requestFormPdfBytes = Rxn<Uint8List>();
  final requestFormFilePath = RxnString();

  // Step 4 Certificate upload details
  final selectedCertFileName = RxnString();
  final selectedCertContent = RxnString();
  final matchesPrivateKey = RxnBool();
  final isCertificateInstalled = false.obs;

  // Remote Certificate & Key Status Details
  final hasPrivateKey = false.obs;
  final hasCertificate = false.obs;
  final certificateMatchesKey = false.obs;
  final isStatusLoaded = false.obs;

  // Form Controllers
  late final TextEditingController tinController;
  late final TextEditingController systemNumberController;
  late final TextEditingController orgNameController;
  late final TextEditingController orgUnitController;
  late final TextEditingController emailController;
  late final TextEditingController ownerNameController;
  late final TextEditingController phoneController;
  late final TextEditingController addressController;
  late final TextEditingController certManualInputController;

  static const String insaEmail = 'ica@insa.gov.et';

  @override
  void onInit() {
    super.onInit();
    final savedTin = ConfigPreference.getCachedTin() ?? '';
    final savedOrgName = ConfigPreference.getCompanyName() ?? '';
    final savedBranchName = ConfigPreference.getBranchName() ?? '';
    final savedEmail = ConfigPreference.getBranchEmail() ?? '';
    final savedOwnerName = ConfigPreference.getOwnerName() ?? '';
    final savedPhone = ConfigPreference.getBranchPhone() ?? '';
    final savedCity = ConfigPreference.getBranchCity() ?? '';
    final savedSystemNumber = ConfigPreference.getBranchSystemNumber() ?? '';

    tinController = TextEditingController(
      text: initialTin.isNotEmpty ? initialTin : savedTin,
    );
    systemNumberController = TextEditingController(
      text: (initialSystemNumber.isNotEmpty && initialSystemNumber != 'SYS-0001')
          ? initialSystemNumber
          : (savedSystemNumber.isNotEmpty ? savedSystemNumber : 'SYS-0001'),
    );
    orgNameController = TextEditingController(
      text: initialOrgName.isNotEmpty ? initialOrgName : savedOrgName,
    );
    orgUnitController = TextEditingController(
      text: (initialOrgUnit.isNotEmpty && initialOrgUnit != 'Head Office')
          ? initialOrgUnit
          : (savedBranchName.isNotEmpty ? savedBranchName : 'Head Office'),
    );
    emailController = TextEditingController(
      text: initialEmail.isNotEmpty ? initialEmail : savedEmail,
    );
    ownerNameController = TextEditingController(
      text: initialOwnerName.isNotEmpty ? initialOwnerName : savedOwnerName,
    );
    phoneController = TextEditingController(
      text: initialPhone.isNotEmpty ? initialPhone : savedPhone,
    );
    addressController = TextEditingController(
      text: savedCity.isNotEmpty ? savedCity : 'Addis Ababa',
    );
    certManualInputController = TextEditingController();

    isCertificateInstalled.value = ConfigPreference.isBranchCertificateInstalled();
    _hydrateFormFromPrefs();
    loadCachedCsrAndFiles();
    checkCertificateStatus();
  }

  Future<void> _hydrateFormFromPrefs() async {
    try {
      if (tinController.text.trim().isEmpty) {
        final tin = await ConfigPreference.getTin();
        if (tin.trim().isNotEmpty) tinController.text = tin.trim();
      }
      if (orgNameController.text.trim().isEmpty) {
        final trade = await AppSettings.getTradeName();
        if (trade.trim().isNotEmpty) orgNameController.text = trade.trim();
      }
      if (systemNumberController.text.trim().isEmpty ||
          systemNumberController.text.trim() == 'SYS-0001') {
        final sys = await AppSettings.getSystemNumber();
        if (sys.trim().isNotEmpty && sys.trim() != 'SYS-0001') {
          systemNumberController.text = sys.trim();
        }
      }
      if (ownerNameController.text.trim().isEmpty) {
        final cashier = await AppSettings.getCashierName();
        if (cashier.trim().isNotEmpty && cashier.trim() != 'Default Cashier') {
          ownerNameController.text = cashier.trim();
        }
      }
    } catch (_) {}
  }

  /// Looks up cached CSR text and files from preferences, in-app cache, and public directory
  Future<void> loadCachedCsrAndFiles() async {
    try {
      // 1. Check in-app cache for CSR file
      final appCacheCsrPath =
          await InsaRequestFormService.findInAppCache('branch-$branchId-csr.pem');
      if (appCacheCsrPath != null) {
        final file = File(appCacheCsrPath);
        final content = await file.readAsString();
        if (content.isNotEmpty && content.contains('-----BEGIN CERTIFICATE REQUEST-----')) {
          csrText.value = content;
          csrFilePath.value = appCacheCsrPath;
          await ConfigPreference.saveBranchCsr(branchId, content);
        } else {
          csrFilePath.value = null;
        }
      } else {
        csrFilePath.value = null;
      }

      // 2. Check public directory for CSR file
      final pubCsr =
          await InsaRequestFormService.findInPublicDirectory('branch-$branchId-csr.pem');
      if (pubCsr != null) {
        final file = File(pubCsr);
        final content = await file.readAsString();
        if (content.isNotEmpty && content.contains('-----BEGIN CERTIFICATE REQUEST-----')) {
          isCsrInPublicDir.value = true;
          publicCsrPath.value = pubCsr;
          if (csrText.value == null || csrText.value!.isEmpty) {
            csrText.value = content;
            await ConfigPreference.saveBranchCsr(branchId, content);
          }
        } else {
          isCsrInPublicDir.value = false;
          publicCsrPath.value = null;
        }
      } else {
        isCsrInPublicDir.value = false;
        publicCsrPath.value = null;
      }

      // 3. Try to load CSR text from SharedPreferences if not already loaded from valid files
      if (csrText.value == null || csrText.value!.isEmpty) {
        final prefCsr = await ConfigPreference.loadBranchCsr(branchId);
        if (prefCsr != null &&
            prefCsr.isNotEmpty &&
            prefCsr.contains('-----BEGIN CERTIFICATE REQUEST-----')) {
          csrText.value = prefCsr;
          // Re-sync file to app cache if missing from disk
          if (csrFilePath.value == null) {
            await saveCsrToFile(prefCsr, branchId);
          }
        }
      }

      // 4. Check public directory for INSA Request Form PDF
      final pubForm =
          await InsaRequestFormService.findInPublicDirectory('branch-$branchId-insa-request-form.pdf');
      if (pubForm != null) {
        isRequestFormInPublicDir.value = true;
        publicRequestFormPath.value = pubForm;
      } else {
        isRequestFormInPublicDir.value = false;
        publicRequestFormPath.value = null;
      }

      // 5. Check app cache for INSA Request Form
      final inAppForm =
          await InsaRequestFormService.findInAppCache('branch-$branchId-insa-request-form.pdf');
      if (inAppForm != null) {
        requestFormFilePath.value = inAppForm;
        final file = File(inAppForm);
        requestFormPdfBytes.value = await file.readAsBytes();
      } else {
        requestFormFilePath.value = null;
        requestFormPdfBytes.value = null;
        // ONLY generate the form if a valid CSR is actually present on this device.
        // DO NOT generate if hasPrivateKey is true but no CSR exists on device.
        if (csrText.value != null &&
            csrText.value!.isNotEmpty &&
            csrText.value!.contains('-----BEGIN CERTIFICATE REQUEST-----')) {
          await generateAndSaveRequestFormFiles(silent: true);
        }
      }

      hasLocalCsr.value = hasCsrOnDevice;
    } catch (e) {
      Logger().w('Error in loadCachedCsrAndFiles: $e');
    }
  }

  Future<void> checkCertificateStatus() async {
    if (branchId <= 0) return;
    await ApiService.getBranchCertificateStatus(
      branchId: branchId,
      onSuccess: (statusRes) async {
        isStatusLoaded.value = true;
        hasPrivateKey.value = statusRes.hasPrivateKey;
        hasCertificate.value = statusRes.hasCertificate;
        certificateMatchesKey.value = statusRes.certificateMatchesKey;

        await loadCachedCsrAndFiles();

        if (statusRes.isInstalled) {
          isCertificateInstalled.value = true;
          await ConfigPreference.saveBranchCertificateInstalled(true);
        } else {
          isCertificateInstalled.value = false;
          await ConfigPreference.saveBranchCertificateInstalled(false);

          if (statusRes.hasCertificate && !statusRes.certificateMatchesKey) {
            // Certificate uploaded on server, but does not match private key
            currentStep.value = 4;
            errorMessage.value =
                'The uploaded certificate does not match the private key on file. Please upload the matching INSA certificate or generate a new CSR.';
          } else if (statusRes.hasPrivateKey) {
            // Private key / CSR already exists, proceed to Step 4 (Upload Certificate)
            currentStep.value = 4;
          } else {
            // Neither private key nor certificate exists yet: always start at Step 1
            currentStep.value = 1;
          }
        }
      },
      onFailure: (err, resp) {
        Logger().d('Could not fetch certificate status: $err');
      },
    );
  }

  @override
  void onClose() {
    tinController.dispose();
    systemNumberController.dispose();
    orgNameController.dispose();
    orgUnitController.dispose();
    emailController.dispose();
    ownerNameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    certManualInputController.dispose();
    super.onClose();
  }

  // --- Step Navigation & On-Device CSR Handling ---
  /// Navigates to Step 1.
  /// If the API says there is a private key on the server, but there isn't one on the device,
  /// tells the user that there isn't a CSR on-device and that they should generate one again.
  void goToStep1({bool showDialog = true}) {
    if (hasPrivateKey.value && !hasCsrOnDevice) {
      if (showDialog) {
        showNoCsrOnDeviceDialog();
      } else {
        currentStep.value = 1;
        notifyNoCsrOnDevice();
      }
    } else {
      currentStep.value = 1;
    }
  }

  void notifyNoCsrOnDevice() {
    try {
      if (Get.context != null) {
        Get.snackbar(
          'No CSR on Device',
          'There isn\'t a CSR on this device, so you should generate one again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.amber.shade900,
          colorText: Colors.white,
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
          duration: const Duration(seconds: 5),
        );
      }
    } catch (_) {}
  }

  void showNoCsrOnDeviceDialog({VoidCallback? onConfirm}) {
    if (Get.context == null) {
      currentStep.value = 1;
      onConfirm?.call();
      return;
    }
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.vpn_key_off_rounded,
                  color: Colors.amber,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No CSR on Device',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'The server has a registered private key for this branch, but there isn\'t a CSR on this device, so you should generate one again.',
                style: TextStyle(fontSize: 14, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Get.back();
                        currentStep.value = 1;
                        notifyNoCsrOnDevice();
                        onConfirm?.call();
                      },
                      child: const Text('Go to Step 1'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Step 1: Request the CSR ---
  Future<bool> generateCsr({bool force = false}) async {
    final tin = tinController.text.trim();
    final systemNumber = systemNumberController.text.trim();
    final orgName = orgNameController.text.trim();
    final orgUnit = orgUnitController.text.trim();
    final email = emailController.text.trim();

    if (tin.isEmpty) {
      Get.snackbar('Missing Field', 'Taxpayer TIN is required.');
      return false;
    }
    if (systemNumber.isEmpty) {
      Get.snackbar('Missing Field', 'System Number is required.');
      return false;
    }
    if (orgName.isEmpty) {
      Get.snackbar('Missing Field', 'Organization Name is required.');
      return false;
    }
    if (orgUnit.isEmpty) {
      Get.snackbar('Missing Field', 'Organizational Unit is required.');
      return false;
    }
    if (email.isEmpty) {
      Get.snackbar('Missing Field', 'Email address is required.');
      return false;
    }

    // If server has private key, but there is no CSR on device and force was not specified,
    // prompt user to confirm key replacement immediately.
    if (hasPrivateKey.value && !hasCsrOnDevice && !force) {
      confirmReplaceAndRegenerate();
      return false;
    }

    isLoading.value = true;
    errorMessage.value = null;
    successMessage.value = null;
    is409Conflict.value = false;

    final request = BranchCsrRequest(
      tin: tin,
      systemNumber: systemNumber,
      organizationName: orgName,
      organizationalUnit: orgUnit,
      email: email,
      force: force ? true : null,
    );

    bool ok = false;

    await ApiService.requestBranchCsr(
      branchId: branchId,
      request: request,
      onSuccess: (response) async {
        ok = true;
        csrText.value = response.csr;
        successMessage.value = response.message.isNotEmpty
            ? response.message
            : 'CSR generated successfully.';

        // Step 2: Save the CSR as a .pem file
        await saveCsrToFile(response.csr, branchId);

        currentStep.value = 2;

        Get.snackbar(
          'CSR Generated',
          'Certificate Signing Request successfully generated and saved.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade800,
          colorText: Colors.white,
          icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
        );
      },
      onFailure: (error, response) {
        int? statusCode;
        dynamic data;

        if (error is dio_lib.DioException) {
          statusCode = error.response?.statusCode;
          data = error.response?.data;
        } else if (response.statusCode != null && response.statusCode != 0) {
          statusCode = response.statusCode;
          data = response.data;
        }

        if (statusCode == 409) {
          is409Conflict.value = true;
          errorMessage.value = isCertificateInstalled.value
              ? 'Certificate already installed'
              : 'Private key already exists on server';
          _showCertificateAlreadyInstalledDialog();
        } else {
          final serverMsg = data is Map ? (data['message'] ?? data['error']) : null;
          errorMessage.value = serverMsg?.toString() ?? 'Failed to generate CSR: $error';
          Get.snackbar(
            'CSR Request Failed',
            errorMessage.value!,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade800,
            colorText: Colors.white,
          );
        }
      },
    );

    isLoading.value = false;
    return ok;
  }

  void _showCertificateAlreadyInstalledDialog() {
    final title = isCertificateInstalled.value
        ? 'Certificate Already Installed'
        : 'Key Already Exists on Server';
    final desc = isCertificateInstalled.value
        ? 'This branch already has an installed digital certificate.\n\nGenerating a new CSR will replace the existing private key and invalidate any prior certificate.'
        : (!hasCsrOnDevice
            ? 'The server has a private key for this branch, but there isn\'t a CSR on this device.\n\nGenerating a new CSR will replace the key on the server (force: true) so you can receive a certificate from INSA.'
            : 'A private key already exists for this branch on the server.\n\nGenerating a new CSR will replace the existing private key and require a new INSA certificate.');

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.amber,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                desc,
                style: const TextStyle(fontSize: 14, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Get.back();
                        confirmReplaceAndRegenerate();
                      },
                      child: const Text('Replace'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void confirmReplaceAndRegenerate() {
    final desc = !hasCsrOnDevice
        ? 'The server has a private key for this branch, but there isn’t a CSR on this device.\n\nGenerating a new CSR will create a new private key for this branch (force: true), and you must send the new CSR to INSA to receive a matching certificate.'
        : 'Are you sure you want to replace the certificate?\n\nA new private key will be generated for this branch, and you must send the new CSR to INSA to receive a matching certificate.';

    Get.dialog(
      AlertDialog(
        title: const Text('Confirm Key Replacement'),
        content: Text(desc),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Get.back();
              generateCsr(force: true);
            },
            child: const Text('Confirm & Replace (force: true)'),
          ),
        ],
      ),
    );
  }

  // --- Step 2: Save the CSR & Request Form Files ---
  Future<File?> saveCsrToFile(String csr, int branchId) async {
    try {
      // 1. Save in app documents cache
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'branch-$branchId-csr.pem';
      final file = File('${dir.path}/$fileName');

      // Write as UTF-8 text with no BOM and no extra quotes, using parsed JSON value
      await file.writeAsString(
        csr,
        encoding: const Utf8Codec(allowMalformed: false),
        flush: true,
      );

      csrFilePath.value = file.path;
      Logger().i('Saved CSR file to app cache: ${file.path} (${await file.length()} bytes)');

      // 2. Persist in ConfigPreference
      await ConfigPreference.saveBranchCsr(branchId, csr);

      // 3. Save directly to public Downloads directory
      final pubFile = await InsaRequestFormService.saveFileToPublicDirectory(
        fileName: fileName,
        bytes: utf8.encode(csr),
      );
      if (pubFile != null) {
        publicCsrPath.value = pubFile.path;
        isCsrInPublicDir.value = true;
        Logger().i('Saved CSR file to public directory: ${pubFile.path}');
      } else {
        publicCsrPath.value = null;
        isCsrInPublicDir.value = false;
      }
      hasLocalCsr.value = hasCsrOnDevice;

      // 4. Automatically generate and save the INSA Request Form PDF + TXT
      await generateAndSaveRequestFormFiles(silent: true);

      return file;
    } catch (e) {
      Logger().e('Error saving CSR file: $e');
      errorMessage.value = 'Failed to save CSR file: $e';
      return null;
    }
  }

  /// Explicitly downloads the CSR PEM file to the user's public directory
  Future<bool> downloadCsrToPublicDirectory() async {
    final text = csrText.value;
    if (text == null || text.isEmpty) {
      Get.snackbar('Empty CSR', 'No CSR content available to download.');
      return false;
    }
    final fileName = 'branch-$branchId-csr.pem';
    final pubFile = await InsaRequestFormService.saveFileToPublicDirectory(
      fileName: fileName,
      bytes: utf8.encode(text),
    );
    if (pubFile != null) {
      publicCsrPath.value = pubFile.path;
      isCsrInPublicDir.value = true;
      hasLocalCsr.value = hasCsrOnDevice;
      Get.snackbar(
        'CSR Saved to Downloads',
        'Saved to: ${pubFile.path}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade800,
        colorText: Colors.white,
        icon: const Icon(Icons.download_done_rounded, color: Colors.white),
        duration: const Duration(seconds: 4),
      );
      return true;
    } else {
      isCsrInPublicDir.value = false;
      publicCsrPath.value = null;
      Get.snackbar(
        'Download Failed',
        'Could not write CSR to public download directory.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
      );
      return false;
    }
  }

  InsaRequestFormData getRequestFormData() {
    final name = ownerNameController.text.trim().isNotEmpty
        ? ownerNameController.text.trim()
        : (initialOwnerName.isNotEmpty ? initialOwnerName : 'Taxpayer Admin');
    final address = addressController.text.trim().isNotEmpty
        ? addressController.text.trim()
        : 'Addis Ababa';
    final phone = phoneController.text.trim().isNotEmpty
        ? phoneController.text.trim()
        : (initialPhone.isNotEmpty
            ? initialPhone
            : (ConfigPreference.getBranchPhone() ?? '0911111111'));
    final email = emailController.text.trim().isNotEmpty
        ? emailController.text.trim()
        : (initialEmail.isNotEmpty
            ? initialEmail
            : (ConfigPreference.getBranchEmail() ?? 'info@example.com'));
    final org = orgNameController.text.trim().isNotEmpty
        ? orgNameController.text.trim()
        : (initialOrgName.isNotEmpty ? initialOrgName : 'Business Organization');
    final tin = tinController.text.trim().isNotEmpty
        ? tinController.text.trim()
        : (initialTin.isNotEmpty ? initialTin : '0000000000');
    final branch = orgUnitController.text.trim().isNotEmpty
        ? orgUnitController.text.trim()
        : (initialOrgUnit.isNotEmpty ? initialOrgUnit : 'Head Office');
    final systemId = systemNumberController.text.trim().isNotEmpty
        ? systemNumberController.text.trim()
        : (initialSystemNumber.isNotEmpty ? initialSystemNumber : 'SYS-0001');

    return InsaRequestFormData(
      fullName: name,
      address: address,
      telephone: phone,
      email: email,
      organizationName: org,
      tin: tin,
      branchName: branch,
      systemId: systemId,
      branchId: branchId,
    );
  }

  /// Generates the INSA Request Form PDF & TXT and saves to both in-app cache and public directory
  Future<Uint8List?> generateAndSaveRequestFormFiles({bool silent = false}) async {
    try {
      final formData = getRequestFormData();
      final pdfBytes = await InsaRequestFormService.generatePdf(formData);
      final textContent = InsaRequestFormService.generateText(formData);

      requestFormPdfBytes.value = pdfBytes;

      final pdfName = 'branch-$branchId-insa-request-form.pdf';
      final txtName = 'branch-$branchId-insa-request-form.txt';

      // 1. Save in App Cache
      final appFile = await InsaRequestFormService.saveFileToAppCache(
        fileName: pdfName,
        bytes: pdfBytes,
      );
      if (appFile != null) {
        requestFormFilePath.value = appFile.path;
      }
      await InsaRequestFormService.saveFileToAppCache(
        fileName: txtName,
        bytes: utf8.encode(textContent),
      );

      // 2. Save in Public Directory
      final pubFile = await InsaRequestFormService.saveFileToPublicDirectory(
        fileName: pdfName,
        bytes: pdfBytes,
      );
      if (pubFile != null) {
        publicRequestFormPath.value = pubFile.path;
        isRequestFormInPublicDir.value = true;
      } else {
        publicRequestFormPath.value = null;
        isRequestFormInPublicDir.value = false;
      }
      await InsaRequestFormService.saveFileToPublicDirectory(
        fileName: txtName,
        bytes: utf8.encode(textContent),
      );

      if (!silent && pubFile != null) {
        Get.snackbar(
          'Request Form Saved',
          'Saved to: ${pubFile.path}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade800,
          colorText: Colors.white,
          icon: const Icon(Icons.download_done_rounded, color: Colors.white),
          duration: const Duration(seconds: 4),
        );
      }

      return pdfBytes;
    } catch (e) {
      Logger().e('Error generating INSA request form: $e');
      if (!silent) {
        Get.snackbar('Error', 'Failed to generate request form: $e');
      }
      return null;
    }
  }

  /// Downloads the INSA Request Form to the public directory
  Future<bool> downloadRequestFormToPublicDirectory() async {
    final bytes = await generateAndSaveRequestFormFiles(silent: false);
    return bytes != null;
  }

  /// Opens the PDF preview dialog/screen for the INSA Request Form
  Future<void> previewRequestForm() async {
    var bytes = requestFormPdfBytes.value;
    bytes ??= await generateAndSaveRequestFormFiles(silent: true);
    if (bytes == null) {
      Get.snackbar('Error', 'Unable to build request form PDF.');
      return;
    }
    Get.to(() => PdfPreviewScreen(
          pdfBytes: bytes!,
          title: 'INSA Request Form',
        ));
  }

  /// Shares the Request Form PDF using Printing.sharePdf
  Future<void> shareRequestFormFile() async {
    var bytes = requestFormPdfBytes.value;
    bytes ??= await generateAndSaveRequestFormFiles(silent: true);
    if (bytes == null) {
      Get.snackbar('Error', 'Unable to build request form PDF.');
      return;
    }
    try {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'branch-$branchId-insa-request-form.pdf',
      );
    } catch (e) {
      Logger().w('Printing.sharePdf failed for request form: $e');
    }
  }

  Future<void> copyCsrToClipboard() async {
    final text = csrText.value;
    if (text == null || text.isEmpty) {
      Get.snackbar('Empty CSR', 'No CSR content to copy.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      'Copied',
      'CSR PEM copied to clipboard.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.black87,
      colorText: Colors.white,
    );
  }

  Future<void> shareCsrFile() async {
    final text = csrText.value;
    if (text == null || text.isEmpty) {
      Get.snackbar('Empty CSR', 'No CSR content to export.');
      return;
    }

    try {
      final bytes = utf8.encode(text);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'branch-$branchId-csr.pem',
      );
    } catch (e) {
      Logger().w('Printing.sharePdf failed, fallback to copy: $e');
      await copyCsrToClipboard();
    }
  }

  // --- Step 3: Submission Email Template & Email Launcher ---
  String get emailSubject => 'Certificate Request for E-Invoice';

  String get emailBody {
    final formData = getRequestFormData();

    return 'Dear Admin,\n\n'
        'This is a digital certificate request for E-Invoice.\n\n'
        'Please find attached:\n'
        '1. E-Invoice Digital Certificate Request Form (branch-$branchId-insa-request-form.pdf)\n'
        '2. Certificate Signing Request (branch-$branchId-csr.pem)\n\n'
        'Taxpayer Information:\n'
        '• Organization: ${formData.organizationName}\n'
        '• TIN: ${formData.tin}\n'
        '• Branch / System: ${formData.branchName} (${formData.systemId})\n'
        '• Contact Person: ${formData.fullName} (${formData.telephone}, ${formData.email})\n\n'
        'Regards,\n'
        '${formData.fullName}\n'
        '${formData.organizationName}\n'
        '${formData.telephone}';
  }

  void openEmailWithAttachmentReminder() {
    final csrName = 'branch-$branchId-csr.pem';
    final formName = 'branch-$branchId-insa-request-form.pdf';
    final csrPath = publicCsrPath.value ?? csrFilePath.value;
    final formPath = publicRequestFormPath.value ?? requestFormFilePath.value;

    if (Get.context == null) {
      launchEmailToInsa();
      return;
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.mark_email_read_outlined, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Open Email & Attach Files',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your email app (such as Gmail) will open with INSA\'s address, subject, and request details pre-filled.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.attach_file_rounded, size: 16, color: Colors.amber),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Attach these 2 files before sending:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. $csrName\n   (${csrPath != null ? 'In Downloads / app storage' : 'In Downloads folder'})\n\n2. $formName\n   (${formPath != null ? 'In Downloads / app storage' : 'In Downloads folder'})',
                      style: const TextStyle(fontSize: 11, fontFamily: 'Courier', height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '💡 Tap the paperclip (📎) icon in Gmail to attach both files.',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Get.back();
              launchEmailToInsa();
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Open Gmail / Email'),
          ),
        ],
      ),
    );
  }

  /// Encodes query parameters for mailto: URIs ensuring spaces are percent-encoded
  /// as %20 instead of + (application/x-www-form-urlencoded), which prevents Gmail
  /// and other mail clients from rendering literal '+' characters.
  static String encodeMailtoQuery(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  /// Builds a RFC 6068 compliant mailto: URI with percent-encoded spaces (%20)
  Uri buildMailtoUri() {
    final query = encodeMailtoQuery({
      'subject': emailSubject,
      'body': emailBody,
    });
    return Uri.parse('mailto:$insaEmail?$query');
  }

  Future<void> launchEmailToInsa() async {
    final uri = buildMailtoUri();

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await copyEmailTemplate();
        if (Get.context != null) {
          Get.snackbar(
            'Email App Not Found',
            'Email template copied to clipboard. Please send email to $insaEmail.',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 4),
          );
        }
      }
    } catch (e) {
      Logger().e('Error launching email client: $e');
      await copyEmailTemplate();
    }
  }

  Future<void> copyEmailTemplate() async {
    final formatted = 'To: $insaEmail\n'
        'Subject: $emailSubject\n\n'
        '$emailBody';
    await Clipboard.setData(ClipboardData(text: formatted));
    Get.snackbar(
      'Copied',
      'INSA email template copied to clipboard.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.black87,
      colorText: Colors.white,
    );
  }

  // --- Step 4: Pick & Upload Issued Certificate ---
  Future<void> pickCertificateFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pem', 'crt', 'cer'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      String content = '';

      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      }

      final trimmed = content.trim();
      if (!trimmed.startsWith('-----BEGIN CERTIFICATE-----')) {
        errorMessage.value = 'This is not a PEM certificate file';
        Get.snackbar(
          'Invalid Format',
          'This is not a PEM certificate file',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade800,
          colorText: Colors.white,
        );
        return;
      }

      selectedCertFileName.value = file.name;
      selectedCertContent.value = trimmed;
      certManualInputController.text = trimmed;
      errorMessage.value = null;

      Get.snackbar(
        'Certificate Loaded',
        'File "${file.name}" ready for upload.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blue.shade800,
        colorText: Colors.white,
      );
    } catch (e) {
      Logger().e('Error picking certificate file: $e');
      errorMessage.value = 'Failed to read certificate file: $e';
      Get.snackbar('Error', errorMessage.value!);
    }
  }

  Future<bool> uploadCertificate({String? customPem}) async {
    final pemToUpload = (customPem ?? certManualInputController.text).trim().isNotEmpty
        ? (customPem ?? certManualInputController.text).trim()
        : selectedCertContent.value?.trim();

    if (pemToUpload == null || pemToUpload.isEmpty) {
      Get.snackbar('Missing Certificate', 'Please select or paste your PEM certificate file.');
      return false;
    }

    if (!pemToUpload.startsWith('-----BEGIN CERTIFICATE-----')) {
      errorMessage.value = 'This is not a PEM certificate file';
      Get.snackbar(
        'Invalid Certificate',
        'This is not a PEM certificate file',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
      );
      return false;
    }

    isLoading.value = true;
    errorMessage.value = null;
    successMessage.value = null;

    bool success = false;

    await ApiService.uploadBranchCertificate(
      branchId: branchId,
      certificatePem: pemToUpload,
      onSuccess: (response) async {
        isLoading.value = false;
        matchesPrivateKey.value = response.matchesPrivateKey;

        if (response.matchesPrivateKey) {
          success = true;
          isCertificateInstalled.value = true;
          await ConfigPreference.saveBranchCertificateInstalled(true);
          successMessage.value = 'Certificate installed';

          Get.snackbar(
            'Success',
            'Certificate installed',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade800,
            colorText: Colors.white,
            icon: const Icon(Icons.verified_rounded, color: Colors.white),
            duration: const Duration(seconds: 4),
          );
        } else {
          // matches_private_key: false
          errorMessage.value =
              'This certificate doesn’t match this branch’s key. Generate a new request and send it to INSA again.';
          _showKeyMismatchDialog();
        }
      },
      onFailure: (error, response) {
        isLoading.value = false;
        int? statusCode;
        dynamic data;

        if (error is dio_lib.DioException) {
          statusCode = error.response?.statusCode;
          data = error.response?.data;
        } else if (response.statusCode != null && response.statusCode != 0) {
          statusCode = response.statusCode;
          data = response.data;
        }

        final msg = data is Map ? (data['message'] ?? data['error'])?.toString() : null;
        if (statusCode == 500 && (msg?.contains('Invalid PEM certificate provided') ?? false)) {
          errorMessage.value = 'Invalid PEM certificate provided';
        } else {
          errorMessage.value = msg ?? 'Certificate upload failed: $error';
        }

        Get.snackbar(
          'Upload Failed',
          errorMessage.value!,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade800,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      },
    );

    return success;
  }

  void _showKeyMismatchDialog() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.vpn_key_off_rounded,
                  color: Colors.red.shade700,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Key Mismatch Detected',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'This certificate doesn’t match this branch’s key. Generate a new request and send it to INSA again.',
                style: TextStyle(fontSize: 14, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Get.back();
                        confirmReplaceAndRegenerate();
                      },
                      child: const Text('New Request (force: true)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
