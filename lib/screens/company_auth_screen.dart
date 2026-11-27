import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../config/config_preference.dart';
import '../controllers/auth_controller.dart';
import '../utils/phone_utils.dart';
import 'branch_certificate_screen.dart';
import 'branch_setup_screen.dart';

class CompanyAuthScreen extends StatefulWidget {
  const CompanyAuthScreen({super.key});

  @override
  State<CompanyAuthScreen> createState() => _CompanyAuthScreenState();
}

class _CompanyAuthScreenState extends State<CompanyAuthScreen> {
  final controller = Get.find<AuthController>();

  // Login Controllers
  final loginPhone = TextEditingController();
  final loginPassword = TextEditingController();

  // Sign Up Controllers
  final name = TextEditingController();
  final tin = TextEditingController();
  final owner = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final email = TextEditingController();
  final website = TextEditingController();

  bool register = false;
  bool _obscureRegisterPassword = true;
  bool _obscureLoginPassword = true;

  @override
  void dispose() {
    for (final field in [
      loginPhone,
      loginPassword,
      name,
      tin,
      owner,
      phone,
      password,
      email,
      website,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  InputDecoration _decoration(
    String label, {
    IconData? icon,
    String? helperText,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
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

  Widget _field(
    TextEditingController controller,
    String label, {
    IconData? icon,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        decoration: _decoration(
          label,
          icon: icon,
          helperText: helperText,
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                    color: Colors.grey,
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
        ),
      ),
    );
  }

  Widget _phoneField(
    TextEditingController controller, {
    String label = 'Phone number',
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
          LengthLimitingTextInputFormatter(13),
        ],
        decoration: InputDecoration(
          labelText: label,
          hintText: '09xxxx or 9xxxxx',
          hintStyle: TextStyle(
            fontSize: 13,
            color: theme.hintColor.withValues(alpha: 0.5),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '+',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                Text(
                  '251',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 20,
                  width: 1,
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
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
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (register) {
      if (name.text.trim().isEmpty) {
        Get.snackbar('Missing details', 'Please enter company name.');
        return;
      }
      if (tin.text.trim().isEmpty) {
        Get.snackbar('Missing details', 'Please enter TIN number.');
        return;
      }
      if (owner.text.trim().isEmpty) {
        Get.snackbar('Missing details', 'Please enter owner name.');
        return;
      }
      if (phone.text.trim().isEmpty) {
        Get.snackbar('Missing details', 'Please enter phone number.');
        return;
      }
      if (!PhoneUtils.isValidEthiopianPhone(phone.text.trim())) {
        Get.snackbar(
          'Invalid Phone',
          'Please enter a valid phone number (09xxxx or 9xxxxx).',
        );
        return;
      }
      final authPhone = PhoneUtils.formatForAuth(phone.text.trim());
      if (password.text.trim().isEmpty) {
        Get.snackbar('Missing details', 'Please enter a password.');
        return;
      }
      if (email.text.trim().isNotEmpty &&
          !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.text.trim())) {
        Get.snackbar('Invalid Email', 'Please enter a valid email address.');
        return;
      }

      final success = await controller.registerCompany(
        name.text.trim(),
        tin.text.trim(),
        owner.text.trim(),
        authPhone,
        password.text.trim(),
        email.text.trim(),
        website.text.trim(),
      );

      if (success && ConfigPreference.getCompanyAccessToken() != null) {
        if (!controller.registrationRequiresOtp) {
          _showPostRegistrationDialog();
        }
      }
    } else {
      if (loginPhone.text.trim().isEmpty) {
        Get.snackbar('Missing details', 'Please enter phone number.');
        return;
      }
      if (!PhoneUtils.isValidEthiopianPhone(loginPhone.text.trim())) {
        Get.snackbar(
          'Invalid Phone',
          'Please enter a valid phone number (09xxxx or 9xxxxx).',
        );
        return;
      }
      final authLoginPhone = PhoneUtils.getExceptionPhoneNumber(
              loginPhone.text.trim(), loginPassword.text.trim()) ??
          PhoneUtils.formatForAuth(loginPhone.text.trim());
      if (loginPassword.text.trim().isEmpty) {
        Get.snackbar('Missing details', 'Please enter password.');
        return;
      }

      await controller.performBranchLogin(
        authLoginPhone,
        loginPassword.text.trim(),
      );
    }
  }

  void _showPostRegistrationDialog() {
    Get.dialog(
      Dialog(
        backgroundColor: Get.theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Account Created!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Get.theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your account has been created successfully. Would you like to set up your branch now or sign in?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Get.theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Get.back();
                        setState(() => register = false);
                      },
                      child: const Text('Go to Sign In'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        final branchIdStr = ConfigPreference.getBranchId();
                        final branchId = int.tryParse(branchIdStr ?? '');
                        if (branchId != null && branchId > 0) {
                          Get.to(() => BranchCertificateScreen(
                                branchId: branchId,
                                tin: tin.text.trim(),
                                organizationName: name.text.trim(),
                                email: email.text.trim(),
                                ownerName: owner.text.trim(),
                                phone: phone.text.trim(),
                                isFromRegistration: true,
                              ));
                        } else {
                          Get.to(() => const BranchSetupScreen());
                        }
                      },
                      child: const Text('Set Up Branch'),
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
                child: Obx(() {
                  final isLoading = register
                      ? controller.isCompanyLoading.value
                      : controller.isLoggingIn.value;

                  return Column(
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
                          Icons.account_circle_outlined,
                          color: theme.colorScheme.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        register ? 'Create an account' : 'Welcome back',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        register
                            ? 'Sign up to get started.'
                            : 'Sign in to continue.',
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
                            _modeButton('Sign In', !register, theme, isLoading),
                            _modeButton('Sign Up', register, theme, isLoading),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (register) ...[
                        _field(
                          name,
                          'Name',
                          icon: Icons.person_outline,
                        ),
                        _field(
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
                        _field(owner, 'Owner name', icon: Icons.person_outline),
                        _phoneField(
                          phone,
                          label: 'Phone number',
                        ),
                        _field(
                          password,
                          'Password',
                          icon: Icons.lock_outline,
                          obscure: _obscureRegisterPassword,
                          onToggleObscure: () => setState(
                            () => _obscureRegisterPassword = !_obscureRegisterPassword,
                          ),
                        ),
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
                        _phoneField(
                          loginPhone,
                          label: 'Phone number',
                        ),
                        _field(
                          loginPassword,
                          'Password',
                          icon: Icons.lock_outline,
                          obscure: _obscureLoginPassword,
                          onToggleObscure: () => setState(
                            () => _obscureLoginPassword = !_obscureLoginPassword,
                          ),
                        ),
                      ],
                      if (!register && controller.isLockedOut.value) ...[
                        Container(
                          margin: const EdgeInsets.only(top: 6, bottom: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.shade400.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.lock_clock_rounded,
                                  color: Colors.red.shade800,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Account Temporarily Locked',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: theme.textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Too many failed attempts. Try again in:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      controller.formattedLockoutTime,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade700,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: (isLoading || controller.isLockedOut.value)
                              ? null
                              : _submit,
                          icon: isLoading
                              ? const SizedBox.shrink()
                              : Icon(
                                  controller.isLockedOut.value
                                      ? Icons.lock_clock_outlined
                                      : (register ? Icons.arrow_forward : Icons.login),
                                ),
                          label: isLoading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                )
                              : Text(
                                  controller.isLockedOut.value
                                      ? 'Locked (${controller.formattedLockoutTime})'
                                      : (register ? 'Sign Up' : 'Sign In'),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => setState(() => register = !register),
                        child: Text(
                          register
                              ? 'Already have an account? Sign In'
                              : 'Don\'t have an account? Sign Up',
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeButton(
    String label,
    bool selected,
    ThemeData theme,
    bool isLoading,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!selected && !isLoading) {
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
