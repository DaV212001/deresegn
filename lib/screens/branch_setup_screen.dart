import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      newBranchPassword = TextEditingController(),
      clientId = TextEditingController(),
      secret = TextEditingController(),
      key = TextEditingController();
  PlatformFile? privateKey, certificate;
  bool saving = false;
  bool _obscureBranchPassword = true;
  bool _obscureSecret = true;
  bool _obscureApiKey = true;

  @override
  void dispose() {
    for (final c in [
      name,
      location,
      phone,
      email,
      tin,
      newBranchPassword,
      clientId,
      secret,
      key,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration d(
    String s, {
    IconData? icon,
    String? helperText,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: s,
      helperText: helperText,
      helperStyle: const TextStyle(fontSize: 11, color: Colors.grey),
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: theme.inputDecorationTheme.fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      counterText: '',
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

  Widget f(
    TextEditingController c,
    String s, {
    IconData? icon,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? helperText,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          obscureText: obscure,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          decoration: d(
            s,
            icon: icon,
            helperText: helperText,
            suffixIcon: onToggleObscure != null
                ? IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
          ),
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
    if (name.text.trim().isEmpty) {
      Get.snackbar('Missing details', 'Branch name is required.');
      return;
    }
    if (tin.text.trim().isEmpty) {
      Get.snackbar('Missing details', 'TIN number is required.');
      return;
    }
    if (newBranchPassword.text.trim().isEmpty) {
      Get.snackbar('Missing details', 'Branch password is required.');
      return;
    }

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
        'branch_name': name.text.trim(),
        'location': location.text.trim(),
        'phone_number': phone.text.trim(),
        'email': email.text.trim(),
        'password': newBranchPassword.text.trim(),
        'tin_number': tin.text.trim(),
        'client_id': clientId.text.trim(),
        'client_secret': secret.text.trim(),
        'api_key': key.text.trim(),
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
          Get.snackbar('Success', 'Branch created successfully!');
          await Get.find<AuthController>().performBranchLogin(
            tin.text.trim(),
            newBranchPassword.text.trim(),
          );
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
        title: const Text('Create New Branch'),
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
                          Icons.add_business_rounded,
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
                              'Create Branch',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Configure branch details and MoR fiscal keys.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  f(name, 'Branch name', icon: Icons.store_outlined),
                  f(location, 'Location', icon: Icons.location_on_outlined),
                  f(
                    phone,
                    'Phone number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  f(
                    email,
                    'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  f(
                    tin,
                    'TIN number',
                    icon: Icons.badge_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    maxLength: 10,
                  ),
                  f(
                    newBranchPassword,
                    'Branch Password',
                    icon: Icons.lock_outline,
                    obscure: _obscureBranchPassword,
                    onToggleObscure: () => setState(
                      () => _obscureBranchPassword = !_obscureBranchPassword,
                    ),
                  ),
                  f(clientId, 'MOR client ID', icon: Icons.vpn_key_outlined),
                  f(
                    secret,
                    'MOR client secret',
                    icon: Icons.lock_outline,
                    obscure: _obscureSecret,
                    onToggleObscure: () => setState(
                      () => _obscureSecret = !_obscureSecret,
                    ),
                  ),
                  f(
                    key,
                    'MOR API key',
                    icon: Icons.key_outlined,
                    obscure: _obscureApiKey,
                    onToggleObscure: () => setState(
                      () => _obscureApiKey = !_obscureApiKey,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: saving ? null : save,
                      icon: saving
                          ? const SizedBox.shrink()
                          : const Icon(Icons.add_business_outlined),
                      label: saving
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : const Text('Create Branch'),
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
