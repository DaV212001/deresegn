import 'package:deresegn/config/config_preference.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_settings.dart';
import '../controllers/auth_controller.dart';
import '../models/company_models.dart';
import '../models/invoice_history_model.dart';
import '../services/api_service.dart';
import '../services/invoice_pdf_service.dart';
import '../theme/theme_service.dart';
import 'branch_setup_screen.dart';
import 'pdf_preview_screen.dart';

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
            Divider(
              height: 1,
              indent: 56,
              endIndent: 16,
              color: theme.dividerColor.withOpacity(0.5),
            ),
            ListTile(
              title: const Text(
                'Create New Branch',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Company authentication required to create branches',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.add_business_rounded,
                  color: theme.primaryColor,
                  size: 20,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                size: 18,
                color: Colors.grey,
              ),
              onTap: () => _handleCreateBranch(context),
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
            ListTile(
              title: const Text(
                'Sample Invoice PDF (Letterhead)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Preview PDF with official header, watermark & footer',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined, color: Colors.indigo, size: 20),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                size: 18,
                color: Colors.grey,
              ),
              onTap: () => _previewSampleInvoice(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            ListTile(
              title: Text(
                'logout'.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.logout, color: Colors.red, size: 20),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                size: 18,
                color: Colors.grey,
              ),
              onTap: () async {
                await ConfigPreference.clearAll();
                Get.offAllNamed('/dashboard');
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ], theme),
        ],
      ),
    );
  }

  void _previewSampleInvoice(BuildContext context) async {
    try {
      Get.snackbar(
        'Invoice Preview',
        'Generating sample branded PDF...',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 1),
      );

      final sampleInvoice = InvoiceSummary(
        id: 1001,
        documentNumber: 'INV-2026-000842',
        irn: 'IRN-9876543210-20260828-ABCDE',
        status: 'A',
        transactionType: 'B2B',
        createdAt: DateTime.now().toIso8601String(),
        buyer: BuyerInfo(
          legalName: 'Abyssinia Trading Enterprises PLC',
          tin: '0098765432',
          phone: '+251 91 234 5678',
          email: 'finance@abyssiniatrading.et',
          city: 'Addis Ababa',
          region: 'Addis Ababa',
        ),
        totals: TotalsInfo(
          totalValue: '18500.00',
          taxValue: '2413.04',
          discount: '500.00',
          exciseValue: '0.00',
          currency: 'ETB',
        ),
        requestPayload: {
          'SellerDetails': {
            'LegalName': 'Deresegn',
            'TradeName': 'Deresegn POS & Cloud Invoicing',
            'Tin': '0012345678',
            'Vrn': 'VAT-ET-887766',
            'City': 'Addis Ababa',
            'Wereda': 'Kirkos Woreda 02',
            'Phone': '+251 91 105 8179',
            'Email': 'contact@deresegn.com',
          },
          'BuyerDetails': {
            'Name': 'Abyssinia Trading Enterprises PLC',
            'Tin': '0098765432',
            'Vrn': 'VAT-ET-112233',
            'City': 'Addis Ababa',
            'Zone': 'Bole Sub City',
            'Woreda': 'Woreda 03',
            'Kebele': '04',
            'HouseNo': '120/A',
            'PhoneNo': '+251 91 234 5678',
            'Email': 'finance@abyssiniatrading.et',
          },
          'DocumentDetails': {
            'DocumentNumber': 'INV-2026-000842',
            'Date': '2026-08-28',
            'Type': 'INV',
          },
          'PaymentDetails': {
            'Mode': 'Bank Transfer / Telebirr',
            'PaymentTerm': 'CASH',
          },
          'SourceSystem': {
            'SystemNumber': 'TERM-01-POS',
            'CashierName': 'Abebe Bikila',
          },
          'ItemList': [
            {
              'ProductDescription': 'High Precision Thermal Receipt Printer 80mm',
              'NatureOfSupplies': 'G',
              'Unit': 'PCS',
              'Quantity': '2',
              'UnitPrice': '4500.00',
              'TaxCode': 'VAT-15%',
              'ExciseTaxValue': '0.00',
              'Discount': '0.00',
              'TotalLineAmount': '9000.00',
            },
            {
              'ProductDescription': 'Wireless Barcode 2D Scanner & Stand',
              'NatureOfSupplies': 'G',
              'Unit': 'PCS',
              'Quantity': '3',
              'UnitPrice': '2500.00',
              'TaxCode': 'VAT-15%',
              'ExciseTaxValue': '0.00',
              'Discount': '500.00',
              'TotalLineAmount': '7000.00',
            },
            {
              'ProductDescription': 'Deresegn Annual Cloud ERP Integration License',
              'NatureOfSupplies': 'S',
              'Unit': 'YR',
              'Quantity': '1',
              'UnitPrice': '2500.00',
              'TaxCode': 'VAT-15%',
              'ExciseTaxValue': '0.00',
              'Discount': '0.00',
              'TotalLineAmount': '2500.00',
            },
          ],
          'ValueDetails': {
            'TotalValue': '18500.00',
            'TaxValue': '2413.04',
            'Discount': '500.00',
            'ExciseValue': '0.00',
            'TransactionWithholdValue': '0.00',
            'IncomeWithholdValue': '0.00',
          },
        },
      );

      final pdfBytes = await InvoicePdfService.generate(sampleInvoice);
      Get.to(
        () => PdfPreviewScreen(
          pdfBytes: pdfBytes,
          title: 'Sample Invoice PDF Preview',
        ),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to generate preview: $e');
    }
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0, top: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.primaryColor,
          fontWeight: FontWeight.w600,
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

  void _handleCreateBranch(BuildContext context) {
    if (ConfigPreference.getCompanyAccessToken() != null &&
        ConfigPreference.getCompanyAccessToken()!.isNotEmpty) {
      Get.to(() => const BranchSetupScreen());
    } else {
      _showCompanyLoginDialog(context);
    }
  }

  void _showCompanyLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CompanyLoginDialog(),
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

class CompanyLoginDialog extends StatefulWidget {
  const CompanyLoginDialog({super.key});

  @override
  State<CompanyLoginDialog> createState() => _CompanyLoginDialogState();
}

class _CompanyLoginDialogState extends State<CompanyLoginDialog> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyIdController = TextEditingController();

  final _authController = Get.isRegistered<AuthController>()
      ? Get.find<AuthController>()
      : Get.put(AuthController());

  bool _loadingCompanies = true;
  bool _companiesFailed = false;
  bool _obscurePassword = true;
  List<CompanySummary> _companies = [];

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _companyIdController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _loadingCompanies = true;
      _companiesFailed = false;
    });
    ApiService.fetchCompanies(
      onSuccess: (items) {
        if (mounted) {
          setState(() {
            _companies = items;
            _loadingCompanies = false;
          });
        }
      },
      onFailure: (_, _) {
        if (mounted) {
          setState(() {
            _loadingCompanies = false;
            _companiesFailed = true;
          });
        }
      },
    );
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final companyId = _companyIdController.text.trim();

    if (phone.isEmpty) {
      Get.snackbar('Missing details', 'Please enter phone number.');
      return;
    }
    if (password.isEmpty) {
      Get.snackbar('Missing details', 'Please enter password.');
      return;
    }
    if (companyId.isEmpty) {
      Get.snackbar('Missing details', 'Please select a company.');
      return;
    }

    final success = await _authController.loginCompany(
      phone,
      password,
      companyId,
    );
    if (success) {
      Get.back();
      Get.to(() => const BranchSetupScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.business_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Company Authentication',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Sign in as company owner to create a branch.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_loadingCompanies)
                Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.inputDecorationTheme.fillColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_companiesFailed)
                OutlinedButton.icon(
                  onPressed: _loadCompanies,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Failed to load companies. Tap to retry'),
                )
              else
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Choose company',
                    prefixIcon: const Icon(Icons.apartment_outlined, size: 20),
                    filled: true,
                    fillColor: theme.inputDecorationTheme.fillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  initialValue: _companies.any(
                    (item) => item.id == _companyIdController.text,
                  )
                      ? _companyIdController.text
                      : null,
                  hint: const Text('Select a company'),
                  items: _companies
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text('${item.name} (${item.id})'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) _companyIdController.text = val;
                  },
                ),
              const SizedBox(height: 20),
              Obx(() {
                final loading = _authController.isCompanyLoading.value;
                return SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: theme.colorScheme.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Authenticate & Proceed',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                );
              }),
            ],
          ),
        ),
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
