import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide MultipartFile, FormData;

import '../config/config_preference.dart';
import '../controllers/auth_controller.dart';
import '../services/api_service.dart';

class BranchSetupScreen extends StatefulWidget {
  const BranchSetupScreen({super.key});
  @override
  State<BranchSetupScreen> createState() => _BranchSetupScreenState();
}

class _BranchSetupScreenState extends State<BranchSetupScreen> {
  final name = TextEditingController(),
      location = TextEditingController(),
      phone = TextEditingController(),
      email = TextEditingController(),
      tin = TextEditingController(),
      clientId = TextEditingController(),
      secret = TextEditingController(),
      key = TextEditingController();
  PlatformFile? privateKey, certificate;
  final existingBranchId = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ConfigPreference.getBranchId() != null &&
          !ConfigPreference.isLoggedIn() &&
          Get.isRegistered<AuthController>()) {
        Get.find<AuthController>().performMachineLogin();
      }
    });
  }

  @override
  void dispose() {
    for (final c in [
      name,
      location,
      phone,
      email,
      tin,
      clientId,
      secret,
      key,
      existingBranchId,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration d(String s, {IconData? icon}) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: s,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      filled: true,
      fillColor: theme.inputDecorationTheme.fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
    );
  }

  Widget f(TextEditingController c, String s, {IconData? icon}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      decoration: d(s, icon: icon),
    ),
  );
  Future<void> pick(bool isKey) async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null) return;
    setState(() {
      if (isKey) {
        privateKey = result.files.single;
      } else {
        certificate = result.files.single;
      }
    });
  }

  Future<void> save() async {
    if (privateKey?.path == null || certificate?.path == null) {
      Get.snackbar(
        'Files required',
        'Select the branch private key and certificate.',
      );
      return;
    }
    setState(() => saving = true);
    try {
      final data = FormData.fromMap({
        'branch_name': name.text,
        'location': location.text,
        'phone_number': phone.text,
        'email': email.text,
        'tin_number': tin.text,
        'client_id': clientId.text,
        'client_secret': secret.text,
        'api_key': key.text,
        'private_key': await MultipartFile.fromFile(
          privateKey!.path!,
          filename: privateKey!.name,
        ),
        'certificate': await MultipartFile.fromFile(
          certificate!.path!,
          filename: certificate!.name,
        ),
      });
      await ApiService.createBranch(
        data,
        onSuccess: (response) async {
          final raw = response.data is Map
              ? (response.data['data'] ?? response.data)
              : response.data;
          final id = raw is Map ? (raw['id'] ?? raw['branch_id']) : raw;
          if (id == null) {
            Get.snackbar(
              'Branch setup failed',
              'The server did not return a branch ID.',
            );
            return;
          }
          await ConfigPreference.saveBranchId('$id');
          await ConfigPreference.saveDeviceCredentials(
            clientId: clientId.text.trim(),
            clientSecret: secret.text.trim(),
            apiKey: key.text.trim(),
            tin: tin.text.trim(),
          );
          await Get.find<AuthController>().performMachineLogin();
        },
        onFailure: (e, r) => Get.snackbar('Branch setup failed', '$e'),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Branch setup'),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor.withOpacity(.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.storefront_outlined,
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose your branch',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Connect a branch before registering invoices.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Existing branch',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: existingBranchId,
                    decoration: d('Branch ID', icon: Icons.tag_outlined),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (existingBranchId.text.trim().isNotEmpty) {
                        await ConfigPreference.saveBranchId(
                          existingBranchId.text.trim(),
                        );
                        await Get.find<AuthController>().performMachineLogin();
                      }
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Continue with existing branch'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: theme.dividerColor)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('OR', style: theme.textTheme.labelSmall),
                        ),
                        Expanded(child: Divider(color: theme.dividerColor)),
                      ],
                    ),
                  ),
                  Text(
                    'Create new branch',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  f(name, 'Branch name', icon: Icons.store_outlined),
                  f(location, 'Location', icon: Icons.location_on_outlined),
                  f(phone, 'Phone number', icon: Icons.phone_outlined),
                  f(email, 'Email', icon: Icons.email_outlined),
                  f(tin, 'TIN number', icon: Icons.badge_outlined),
                  f(clientId, 'MOR client ID', icon: Icons.vpn_key_outlined),
                  f(secret, 'MOR client secret', icon: Icons.lock_outline),
                  f(key, 'MOR API key', icon: Icons.key_outlined),
                  OutlinedButton.icon(
                    onPressed: () => pick(true),
                    icon: const Icon(Icons.key_outlined),
                    label: Text(
                      privateKey?.name ?? 'Select private key (.key)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => pick(false),
                    icon: const Icon(Icons.verified_outlined),
                    label: Text(
                      certificate?.name ?? 'Select certificate (.pem/.crt)',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: saving ? null : save,
                      icon: saving
                          ? const SizedBox.shrink()
                          : const Icon(Icons.add_business_outlined),
                      label: saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create branch'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
