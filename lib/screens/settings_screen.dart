import 'package:flutter/material.dart';
import '../config/app_settings.dart';

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
    if (_isLoading) {
      return const Scaffold(backgroundColor: Color(0xFF121212), body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text('Invoice Settings'), backgroundColor: const Color(0xFF1F1F1F)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildTextField('Default Cashier Name', _cashierController),
            const SizedBox(height: 16),
            _buildTextField('POS System Number', _systemController),
            const SizedBox(height: 16),
            _buildTextField('Default City', _cityController),
            const SizedBox(height: 16),
            _buildTextField('Seller Trade Name', _tradeController),
            const SizedBox(height: 16),
            _buildTextField('Seller VAT Number', _vatController),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FFB3),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF181818),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }
}
