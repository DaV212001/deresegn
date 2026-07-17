import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    _tinController.dispose();
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _saveCredentials() async {
    await ConfigPreference.saveDeviceCredentials(
      tin: _tinController.text.trim(),
      clientId: _clientIdController.text.trim(),
      clientSecret: _clientSecretController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
    );
    _authController.performMachineLogin();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Device Binding Terminal', style: TextStyle(fontWeight: FontWeight.bold, color: theme.appBarTheme.foregroundColor ?? Colors.white)),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Administrative Setup',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter Ministry of Revenues configuration to bind this device.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _buildTextField('TIN (Tax Identification Number)', _tinController, theme),
                const SizedBox(height: 16),
                _buildTextField('Client ID', _clientIdController, theme),
                const SizedBox(height: 16),
                _buildTextField('Client Secret', _clientSecretController, theme, obscureText: true),
                const SizedBox(height: 16),
                _buildTextField('API Key', _apiKeyController, theme, obscureText: true),
                const SizedBox(height: 32),
                Obx(() => ElevatedButton(
                  onPressed: _authController.isLoggingIn.value ? null : _saveCredentials,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: theme.scaffoldBackgroundColor,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _authController.isLoggingIn.value
                      ? CircularProgressIndicator(color: theme.scaffoldBackgroundColor)
                      : const Text('Bind Device & Start', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, ThemeData theme, {bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF888888)),
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
