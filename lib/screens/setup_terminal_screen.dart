import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../config/config_preference.dart';
import '../controllers/auth_controller.dart';

class SetupTerminalScreen extends StatefulWidget {
  @override
  _SetupTerminalScreenState createState() => _SetupTerminalScreenState();
}

class _SetupTerminalScreenState extends State<SetupTerminalScreen> {
  final _tinController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  final _apiKeyController = TextEditingController();

  final _authController = Get.put(AuthController());
  bool _obscureClientSecret = true;
  bool _obscureApiKey = true;

  @override
  void dispose() {
    _tinController.dispose();
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _saveCredentials() async {
    final tin = _tinController.text.trim();
    final clientId = _clientIdController.text.trim();
    final clientSecret = _clientSecretController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (tin.isEmpty) {
      Get.snackbar('Missing details', 'Please enter TIN number.');
      return;
    }
    if (tin.length != 10 || !RegExp(r'^\d{10}$').hasMatch(tin)) {
      Get.snackbar('Invalid TIN', 'invalid_tin'.tr);
      return;
    }
    if (clientId.isEmpty) {
      Get.snackbar('Missing details', 'Please enter Client ID.');
      return;
    }
    if (clientSecret.isEmpty) {
      Get.snackbar('Missing details', 'Please enter Client Secret.');
      return;
    }
    if (apiKey.isEmpty) {
      Get.snackbar('Missing details', 'Please enter API Key.');
      return;
    }

    await ConfigPreference.saveDeviceCredentials(
      tin: tin,
      clientId: clientId,
      clientSecret: clientSecret,
      apiKey: apiKey,
    );
    _authController.performMorLogin();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Device Binding Terminal',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color:
                theme.appBarTheme.foregroundColor ??
                theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.point_of_sale_rounded,
                    size: 64,
                    color: Color(0xFF0D253A),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Deresegn POS Setup',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your Ministry of Revenues (MOR) credentials to configure this POS terminal.',
                    style: TextStyle(color: Color(0xFF666666)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildTextField(
                    'TIN (Tax Identification Number)',
                    _tinController,
                    theme,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    maxLength: 10,
                    helperText: '10 digits',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField('Client ID', _clientIdController, theme),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Client Secret',
                    _clientSecretController,
                    theme,
                    obscureText: _obscureClientSecret,
                    onToggleObscure: () => setState(
                      () => _obscureClientSecret = !_obscureClientSecret,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'API Key',
                    _apiKeyController,
                    theme,
                    obscureText: _obscureApiKey,
                    onToggleObscure: () => setState(
                      () => _obscureApiKey = !_obscureApiKey,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Obx(
                    () => ElevatedButton(
                      onPressed: _authController.isLoggingIn.value
                          ? null
                          : _saveCredentials,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _authController.isLoggingIn.value
                          ? CircularProgressIndicator(
                              color: theme.colorScheme.onPrimary,
                            )
                          : const Text(
                              'Bind Device & Start',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    ThemeData theme, {
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        counterText: '',
        labelStyle: const TextStyle(color: Color(0xFF888888)),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: Colors.grey,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.primaryColor),
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: theme.inputDecorationTheme.fillColor,
      ),
    );
  }
}
