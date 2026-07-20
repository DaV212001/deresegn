import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_settings.dart';
import '../theme/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = Get.find<ThemeService>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('settings'.tr),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionTitle('general'.tr, theme),
          _buildSectionCard([
            Obx(
              () => SwitchListTile(
                title: Text(
                  'dark_mode'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.brightness_4,
                    color: theme.primaryColor,
                    size: 20,
                  ),
                ),
                value: themeService.isDarkMode,
                onChanged: (val) => themeService.toggleTheme(),
                activeColor: theme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            Divider(
              height: 1,
              indent: 56,
              endIndent: 16,
              color: theme.dividerColor.withOpacity(0.5),
            ),
            ListTile(
              title: Text(
                'language'.tr,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.language,
                  color: theme.primaryColor,
                  size: 20,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Get.locale?.languageCode == 'am'
                        ? 'amharic'.tr
                        : 'english'.tr,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                ],
              ),
              onTap: () => _showLanguageDialog(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ], theme),
          _buildSectionTitle('account'.tr, theme),
          _buildSectionCard([
            ListTile(
              title: Text(
                'company_details'.tr,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.business,
                  color: theme.primaryColor,
                  size: 20,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                size: 18,
                color: Colors.grey,
              ),
              onTap: () => Get.to(() => CompanyDetailsScreen()),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ], theme),
          _buildSectionTitle('legal'.tr, theme),
          _buildSectionCard([
            ListTile(
              title: Text(
                'terms_conditions'.tr,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.description,
                  color: theme.primaryColor,
                  size: 20,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                size: 18,
                color: Colors.grey,
              ),
              onTap: () => _showInfoDialog(
                context,
                'terms_conditions'.tr,
                'terms_conditions_content'.tr,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            Divider(
              height: 1,
              indent: 56,
              endIndent: 16,
              color: theme.dividerColor.withOpacity(0.5),
            ),
            ListTile(
              title: Text(
                'privacy_policy'.tr,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.privacy_tip,
                  color: theme.primaryColor,
                  size: 20,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                size: 18,
                color: Colors.grey,
              ),
              onTap: () => _showInfoDialog(
                context,
                'privacy_policy'.tr,
                'privacy_policy_content'.tr,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            Divider(
              height: 1,
              indent: 56,
              endIndent: 16,
              color: theme.dividerColor.withOpacity(0.5),
            ),
            ListTile(
              title: Text(
                'about_us'.tr,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.info, color: theme.primaryColor, size: 20),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                size: 18,
                color: Colors.grey,
              ),
              onTap: () => _showInfoDialog(
                context,
                'about_us'.tr,
                'about_us_content'.tr,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ], theme),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0, top: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.primaryColor,
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSectionCard(List<Widget> children, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('language'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('english'.tr),
              onTap: () {
                Get.updateLocale(const Locale('en', 'US'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('amharic'.tr),
              onTap: () {
                Get.updateLocale(const Locale('am', 'ET'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ok'.tr),
          ),
        ],
      ),
    );
  }
}

class CompanyDetailsScreen extends StatefulWidget {
  @override
  _CompanyDetailsScreenState createState() => _CompanyDetailsScreenState();
}

class _CompanyDetailsScreenState extends State<CompanyDetailsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: theme.primaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('company_details'.tr),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildReadOnlyField('cashier_name'.tr, _cashierController, theme),
            const SizedBox(height: 16),
            _buildReadOnlyField('system_number'.tr, _systemController, theme),
            const SizedBox(height: 16),
            _buildReadOnlyField('city'.tr, _cityController, theme),
            const SizedBox(height: 16),
            _buildReadOnlyField('trade_name'.tr, _tradeController, theme),
            const SizedBox(height: 16),
            _buildReadOnlyField('vat_number'.tr, _vatController, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(
    String label,
    TextEditingController controller,
    ThemeData theme,
  ) {
    return TextField(
      controller: controller,
      readOnly: true,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: theme.inputDecorationTheme.fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
