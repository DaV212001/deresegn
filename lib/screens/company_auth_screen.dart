import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../models/company_models.dart';
import '../services/api_service.dart';

class CompanyAuthScreen extends StatefulWidget {
  const CompanyAuthScreen({super.key});

  @override
  State<CompanyAuthScreen> createState() => _CompanyAuthScreenState();
}

class _CompanyAuthScreenState extends State<CompanyAuthScreen> {
  final controller = Get.find<AuthController>();
  final phone = TextEditingController();
  final password = TextEditingController();
  final companyId = TextEditingController();
  final companyName = TextEditingController();
  final tin = TextEditingController();
  final owner = TextEditingController();
  final email = TextEditingController();
  final website = TextEditingController();

  bool register = false;
  bool companiesLoading = false;
  bool companiesFailed = false;
  List<CompanySummary> companies = [];

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    if (mounted) {
      setState(() {
        companiesLoading = true;
        companiesFailed = false;
      });
    }
    ApiService.fetchCompanies(
      onSuccess: (items) {
        if (mounted) {
          setState(() {
            companies = items;
            companiesLoading = false;
          });
        }
      },
      onFailure: (_, _) {
        if (mounted) {
          setState(() {
            companiesLoading = false;
            companiesFailed = true;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    for (final field in [
      phone,
      password,
      companyId,
      companyName,
      tin,
      owner,
      email,
      website,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  InputDecoration _decoration(String label, {IconData? icon}) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
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

  Widget _field(
    TextEditingController controller,
    String label, {
    IconData? icon,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: _decoration(label, icon: icon),
      ),
    );
  }

  Future<void> _submit() async {
    if (register) {
      await controller.registerCompany(
        companyName.text,
        tin.text,
        owner.text,
        phone.text,
        password.text,
        email.text,
        website.text,
      );
    } else {
      await controller.loginCompany(phone.text, password.text, companyId.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.dividerColor.withOpacity(.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.04),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Obx(
                  () => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.business_rounded,
                          color: theme.colorScheme.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        register ? 'Register your company' : 'Welcome back',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        register
                            ? 'Create a company account to get started.'
                            : 'Sign in as a company owner to continue.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _modeButton('Log in', !register, theme),
                            _modeButton('Register', register, theme),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (register) ...[
                        _field(
                          companyName,
                          'Company name',
                          icon: Icons.business_outlined,
                        ),
                        _field(tin, 'TIN number', icon: Icons.badge_outlined),
                        _field(owner, 'Owner name', icon: Icons.person_outline),
                      ],
                      _field(
                        phone,
                        'Phone number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      _field(
                        password,
                        'Password',
                        icon: Icons.lock_outline,
                        obscure: true,
                      ),
                      if (register) ...[
                        _field(
                          email,
                          'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        _field(
                          website,
                          'Website',
                          icon: Icons.language_outlined,
                        ),
                      ] else ...[
                        _buildCompanySelector(theme),
                      ],
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: controller.isCompanyLoading.value
                              ? null
                              : _submit,
                          icon: controller.isCompanyLoading.value
                              ? const SizedBox.shrink()
                              : Icon(
                                  register ? Icons.arrow_forward : Icons.login,
                                ),
                          label: controller.isCompanyLoading.value
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(register ? 'Create company' : 'Continue'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: controller.isCompanyLoading.value
                            ? null
                            : () => setState(() => register = !register),
                        child: Text(
                          register
                              ? 'Already have an account? Log in'
                              : 'Need an account? Register',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanySelector(ThemeData theme) {
    if (companiesLoading) {
      return Container(
        height: 56,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: theme.inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withOpacity(.35)),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (companiesFailed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: OutlinedButton.icon(
          onPressed: _loadCompanies,
          icon: const Icon(Icons.refresh),
          label: const Text('Could not load companies. Retry'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        decoration: _decoration(
          'Choose company',
          icon: Icons.apartment_outlined,
        ),
        initialValue: companies.any((item) => item.id == companyId.text)
            ? companyId.text
            : null,
        hint: const Text('Select a company'),
        items: companies
            .map(
              (item) => DropdownMenuItem(
                value: item.id,
                child: Text('${item.name} (${item.id})'),
              ),
            )
            .toList(),
        onChanged: companies.isEmpty
            ? null
            : (value) {
                if (value != null) companyId.text = value;
              },
      ),
    );
  }

  Widget _modeButton(String label, bool selected, ThemeData theme) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!selected && !controller.isCompanyLoading.value) {
            setState(() => register = !register);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? theme.cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(.06),
                      blurRadius: 5,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? theme.colorScheme.primary : theme.hintColor,
            ),
          ),
        ),
      ),
    );
  }
}
