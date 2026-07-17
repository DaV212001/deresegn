import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_settings.dart';
import '../theme/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _cashierController = TextEditingController();
  final _systemController = TextEditingController();
  final _cityController = TextEditingController();
  final _tradeController = TextEditingController();
  final _vatController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _cashierController.text = await AppSettings.getCashierName();
    _systemController.text = await AppSettings.getSystemNumber();
    _cityController.text = await AppSettings.getDefaultCity();
    _tradeController.text = await AppSettings.getTradeName();
    _vatController.text = await AppSettings.getVatNumber();
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    await AppSettings.saveSettings(
      cashierName: _cashierController.text,
      systemNumber: _systemController.text,
      defaultCity: _cityController.text,
      tradeName: _tradeController.text,
      vatNumber: _vatController.text,
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings Saved!')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = Get.find<ThemeService>();

    if (_isLoading) {
      return Scaffold(backgroundColor: theme.scaffoldBackgroundColor, body: Center(child: CircularProgressIndicator(color: theme.primaryColor)));
    }
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Invoice Settings'), backgroundColor: theme.appBarTheme.backgroundColor),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Obx(() => SwitchListTile(
                  title: Text('Dark Mode', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                  value: themeService.isDarkMode,
                  onChanged: (val) => themeService.toggleTheme(),
                  activeColor: theme.primaryColor,
                  contentPadding: EdgeInsets.zero,
                )),
            const Divider(),
            const SizedBox(height: 16),
            _buildTextField('Default Cashier Name', _cashierController, theme),
            const SizedBox(height: 16),
            _buildTextField('POS System Number', _systemController, theme),
            const SizedBox(height: 16),
            _buildTextField('Default City', _cityController, theme),
            const SizedBox(height: 16),
            _buildTextField('Seller Trade Name', _tradeController, theme),
            const SizedBox(height: 16),
            _buildTextField('Seller VAT Number', _vatController, theme),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: theme.scaffoldBackgroundColor, // Ensure text is visible on primary color
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, ThemeData theme) {
    return TextField(
      controller: controller,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: theme.inputDecorationTheme.fillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }
}
