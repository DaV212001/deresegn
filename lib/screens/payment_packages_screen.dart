import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../config/config_preference.dart';
import '../config/dio_config.dart';
import '../models/payment_package_models.dart';
import '../services/api_service.dart';
import '../utils/phone_utils.dart';
import 'branch_certificate_screen.dart';
import 'in_app_payment_browser_screen.dart';

class PaymentPackagesScreen extends StatefulWidget {
  final int? branchId;
  final String? branchName;
  final String? phone;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? currentStatus;
  final String? expiredDate;
  final bool isFromRegistration;

  const PaymentPackagesScreen({
    super.key,
    this.branchId,
    this.branchName,
    this.phone,
    this.email,
    this.firstName,
    this.lastName,
    this.currentStatus,
    this.expiredDate,
    this.isFromRegistration = false,
  });

  @override
  State<PaymentPackagesScreen> createState() => _PaymentPackagesScreenState();
}

class _PaymentPackagesScreenState extends State<PaymentPackagesScreen> {
  bool _isLoading = true;
  String? _fetchError;
  List<PaymentPackage> _packages = [];
  PaymentPackage? _selectedPackage;

  // Resolved branch details
  late int _branchId;
  late String _phone;
  late String _email;
  late String _firstName;
  late String _lastName;
  late String _status;
  late bool _isFromRegistration;

  bool _isProcessingPayment = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _resolveParameters();
    _loadPackages();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _resolveParameters() {
    final args = Get.arguments is Map ? Get.arguments as Map : {};

    _isFromRegistration = widget.isFromRegistration ||
        (args['is_from_registration'] == true);

    final rawBranchId = widget.branchId ??
        args['branch_id'] ??
        ConfigPreference.getBranchId();
    _branchId = rawBranchId is int
        ? rawBranchId
        : int.tryParse('$rawBranchId') ?? 0;

    _phone = widget.phone ??
        args['phone'] ??
        ConfigPreference.getBranchPhone() ??
        '';
    _email = widget.email ??
        args['email'] ??
        ConfigPreference.getBranchEmail() ??
        '';
    _firstName = widget.firstName ?? args['first_name'] ?? 'Owner';
    _lastName = widget.lastName ?? args['last_name'] ?? 'Account';
    _status = widget.currentStatus ??
        args['status'] ??
        ConfigPreference.getBranchStatus() ??
        'pending';
  }

  Future<void> _loadPackages() async {
    setState(() {
      _isLoading = true;
      _fetchError = null;
    });

    await ApiService.fetchPackages(
      onSuccess: (packages) {
        if (mounted) {
          setState(() {
            _packages = packages;
            _isLoading = false;
            if (_packages.isNotEmpty) {
              // Default select Standard or first package
              _selectedPackage = _packages.firstWhereOrNull(
                    (p) => p.name.toLowerCase().contains('standard'),
                  ) ??
                  _packages.first;
            }
          });
        }
      },
      onFailure: (error, response) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _fetchError = 'Could not load payment packages. Please try again.';
          });
        }
      },
    );
  }

  void _showPayerDetailsSheet() {
    if (_selectedPackage == null) {
      Get.snackbar('Select Package', 'Please choose a package to proceed.');
      return;
    }

    final firstNameController = TextEditingController(text: _firstName);
    final lastNameController = TextEditingController(text: _lastName);
    final emailController = TextEditingController(text: _email);
    final phoneController = TextEditingController(text: _phone);

    final theme = Theme.of(context);

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payer Information',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Subscribing to ${_selectedPackage!.name} (${_selectedPackage!.formattedPrice})',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: firstNameController,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '09xxxx or 9xxxxx',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_outlined, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '+251',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 20,
                          width: 1,
                          color: Colors.grey.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final fn = firstNameController.text.trim();
                  final ln = lastNameController.text.trim();
                  final em = emailController.text.trim();
                  final ph = phoneController.text.trim();

                  if (fn.isEmpty || ln.isEmpty || em.isEmpty || ph.isEmpty) {
                    Get.snackbar(
                      'Missing Information',
                      'Please complete all payer information fields.',
                    );
                    return;
                  }

                  if (!PhoneUtils.isValidEthiopianPhone(ph)) {
                    Get.snackbar(
                      'Invalid Phone Number',
                      'Please enter a valid phone number (09xxxx or 9xxxxx).',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                    return;
                  }

                  Get.back();
                  _startPayment(
                    firstName: fn,
                    lastName: ln,
                    email: em,
                    phone: PhoneUtils.normalize(ph),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Confirm & Pay Now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _startPayment({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    if (_selectedPackage == null) return;

    setState(() => _isProcessingPayment = true);

    final req = PaymentInitializeRequest(
      branchId: _branchId,
      packageId: _selectedPackage!.id,
      email: email,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phone,
    );

    await ApiService.initializePayment(
      request: req,
      onSuccess: (res) async {
        setState(() => _isProcessingPayment = false);
        final url = res.checkoutUrl;
        final txRef = res.txRef;

        if (url != null && url.isNotEmpty) {
          // Open in in-app browser and monitor for receipt redirection
          final returnedFromReceipt = await Get.to<bool>(
            () => InAppPaymentBrowserScreen(
              checkoutUrl: url,
              txRef: txRef,
            ),
          );

          if (returnedFromReceipt == true && txRef != null && txRef.isNotEmpty) {
            // Receipt detected! Automatically verify status and activate branch.
            _verifyAndActivatePayment(txRef);
            return;
          }
        }

        // Show monitoring sheet with txRef if user closed without receipt
        if (txRef != null && txRef.isNotEmpty) {
          _showPaymentStatusSheet(txRef);
        } else {
          Get.snackbar(
            'Payment Initiated',
            'Please complete payment in the checkout window.',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      },
      onFailure: (error, response) {
        setState(() => _isProcessingPayment = false);
        final dynamic respData = response.data;
        final serverMsg = DioConfig.extractErrorMessage(respData);
        final String msg;
        if (serverMsg != null && serverMsg.isNotEmpty) {
          msg = serverMsg;
        } else if (response.statusCode == 401) {
          msg = 'Payment authorization failed. If you logged in with branch credentials, package subscriptions may require company admin authorization.';
        } else if (error is DioException) {
          msg = DioConfig.convertDioError(error);
        } else {
          msg = 'Payment initialization failed. Please try again.';
        }
        Get.snackbar(
          'Payment Error',
          msg,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade900.withValues(alpha: 0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      },
    );
  }

  Future<void> _verifyAndActivatePayment(String txRef) async {
    Get.showOverlay(
      asyncFunction: () async {
        await ApiService.checkPaymentStatus(
          txRef: txRef,
          onSuccess: (statusRes) async {
            if (statusRes.isSuccess) {
              final branchData = statusRes.branch;
              final newExpiry = branchData?['expired_date']?.toString();
              final newPkgId = branchData?['package_id'] != null
                  ? int.tryParse('${branchData!['package_id']}')
                  : _selectedPackage?.id;
              final paidDate = branchData?['payment_date']?.toString() ??
                  branchData?['paid_date']?.toString() ??
                  branchData?['paid_at']?.toString() ??
                  statusRes.paidAt ??
                  DateTime.now().toIso8601String();

              await ConfigPreference.saveBranchSubscription(
                status: 'active',
                packageId: newPkgId,
                expiredDate: newExpiry,
                paidDate: paidDate,
                phone: _phone,
                email: _email,
              );

              _showPaymentSuccessDialog(statusRes);
            } else {
              _showPaymentStatusSheet(txRef);
            }
          },
          onFailure: (err, res) {
            _showPaymentStatusSheet(txRef);
          },
        );
      },
      loadingWidget: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _showPaymentStatusSheet(String txRef) {
    int attempts = 0;
    _pollingTimer?.cancel();

    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      attempts++;
      if (attempts > 30) {
        timer.cancel();
        return;
      }

      await ApiService.checkPaymentStatus(
        txRef: txRef,
        onSuccess: (statusRes) async {
          if (statusRes.isSuccess) {
            timer.cancel();
            if (Get.isBottomSheetOpen == true) {
              Get.back();
            }

            final branchData = statusRes.branch;
            final newExpiry = branchData?['expired_date']?.toString();
            final newPkgId = branchData?['package_id'] != null
                ? int.tryParse('${branchData!['package_id']}')
                : _selectedPackage?.id;
            final paidDate = branchData?['payment_date']?.toString() ??
                branchData?['paid_date']?.toString() ??
                branchData?['paid_at']?.toString() ??
                statusRes.paidAt ??
                DateTime.now().toIso8601String();

            await ConfigPreference.saveBranchSubscription(
              status: 'active',
              packageId: newPkgId,
              expiredDate: newExpiry,
              paidDate: paidDate,
              phone: _phone,
              email: _email,
            );

            _showPaymentSuccessDialog(statusRes);
          }
        },
        onFailure: (err, res) {},
      );
    });

    final theme = Theme.of(context);

    Get.bottomSheet(
      PopScope(
        onPopInvokedWithResult: (didPop, result) => _pollingTimer?.cancel(),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: Colors.amber,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Awaiting Payment Confirmation',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please complete your payment in the checkout window. This screen will automatically update once verified.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                'Reference: $txRef',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _pollingTimer?.cancel();
                        Get.back();
                      },
                      child: const Text('Cancel / Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.showOverlay(
                          asyncFunction: () async {
                            await ApiService.checkPaymentStatus(
                              txRef: txRef,
                              onSuccess: (statusRes) async {
                                if (statusRes.isSuccess) {
                                  _pollingTimer?.cancel();
                                  Get.back();
                                  _showPaymentSuccessDialog(statusRes);
                                } else {
                                  Get.snackbar(
                                    'Status: ${statusRes.status}',
                                    'Payment has not been completed yet.',
                                  );
                                }
                              },
                              onFailure: (err, res) {
                                Get.snackbar('Status Check', 'Could not verify payment yet.');
                              },
                            );
                          },
                          loadingWidget: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      child: const Text('Check Status'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      isDismissible: false,
    );
  }

  void _showPaymentSuccessDialog(PaymentStatusResponse statusRes) {
    final theme = Theme.of(context);
    Get.dialog(
      Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Payment Successful!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Your branch subscription is now ACTIVE. You can now use all fiscal POS features.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    final branchId = widget.branchId != null && widget.branchId != 0
                        ? widget.branchId!
                        : (int.tryParse(ConfigPreference.getBranchId() ?? '') ?? 0);
                    if (!ConfigPreference.isBranchCertificateInstalled() && branchId != 0) {
                      Get.off(() => BranchCertificateScreen(
                            branchId: branchId,
                            email: _email,
                            ownerName: '$_firstName $_lastName'.trim(),
                            phone: _phone,
                            isFromRegistration: true,
                          ));
                    } else {
                      Get.offAllNamed('/dashboard');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Go to Dashboard',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _handleSkip() {
    _pollingTimer?.cancel();
    if (_isFromRegistration) {
      final branchId = _branchId != 0
          ? _branchId
          : (int.tryParse(ConfigPreference.getBranchId() ?? '') ?? 0);
      if (!ConfigPreference.isBranchCertificateInstalled() && branchId != 0) {
        Get.off(() => BranchCertificateScreen(
              branchId: branchId,
              email: _email,
              ownerName: '$_firstName $_lastName'.trim(),
              phone: _phone,
              isFromRegistration: true,
            ));
      } else {
        Get.offAllNamed('/dashboard');
      }
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    // Default skip/back without backstack navigates to dashboard without clearing session
    Get.offAllNamed('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = _status.toLowerCase() == 'active';
    final canPop = Navigator.canPop(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleSkip();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Payment Packages'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            key: const Key('payment_back_button'),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: canPop ? 'Back' : 'Skip',
            onPressed: _handleSkip,
          ),
          actions: [
            if (!isActive)
              TextButton(
                key: const Key('payment_skip_button'),
                onPressed: _handleSkip,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            if (canPop || isActive)
              IconButton(
                key: const Key('payment_close_button'),
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
                onPressed: _handleSkip,
              ),
          ],
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _fetchError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline_rounded,
                                size: 56, color: Colors.red.shade400),
                            const SizedBox(height: 16),
                            Text(_fetchError!, textAlign: TextAlign.center),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _loadPackages,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              key: const Key('payment_error_skip_button'),
                              onPressed: _handleSkip,
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text('Skip for Now'),
                            ),
                          ],
                        ),
                      ),
                    )
                : Column(
                    children: [
                      // Subscription Status Banner
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.amber.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isActive
                                ? Colors.green.withValues(alpha: 0.3)
                                : Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isActive
                                  ? Icons.verified_rounded
                                  : Icons.info_outline_rounded,
                              color: isActive ? Colors.green : Colors.amber.shade800,
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isActive
                                        ? 'Branch License: Active'
                                        : 'Payment Required (${_status.toUpperCase()})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isActive
                                          ? Colors.green.shade900
                                          : Colors.amber.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isActive
                                        ? (widget.expiredDate != null
                                            ? 'Expires on ${widget.expiredDate!.split('T')[0]}'
                                            : 'Select a plan to renew or upgrade your branch.')
                                        : 'Please select a package to activate POS invoicing and MoR integration.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isActive
                                          ? Colors.green.shade800
                                          : Colors.amber.shade900.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Packages List
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _packages.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final pkg = _packages[index];
                            final isSelected = _selectedPackage?.id == pkg.id;

                            // Badge info
                            String? badgeText;
                            Color badgeColor = theme.colorScheme.primary;
                            if (pkg.name.toLowerCase().contains('standard')) {
                              badgeText = 'MOST POPULAR';
                              badgeColor = Colors.orange;
                            } else if (pkg.name.toLowerCase().contains('premium') &&
                                !pkg.isAnnual) {
                              badgeText = 'RECOMMENDED';
                              badgeColor = Colors.purple;
                            } else if (pkg.isAnnual &&
                                pkg.name.toLowerCase().contains('premium')) {
                              badgeText = 'BEST VALUE';
                              badgeColor = Colors.teal;
                            }

                            return InkWell(
                              onTap: () {
                                setState(() => _selectedPackage = pkg);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.dividerColor.withValues(alpha: 0.25),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.15),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (badgeText != null) ...[
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3),
                                                  margin: const EdgeInsets.only(
                                                      bottom: 6),
                                                  decoration: BoxDecoration(
                                                    color: badgeColor
                                                        .withValues(alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    badgeText,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: badgeColor,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              Text(
                                                pkg.name,
                                                style: theme.textTheme.titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                pkg.description,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: theme.textTheme.bodySmall
                                                      ?.color
                                                      ?.withValues(alpha: 0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              pkg.formattedPrice,
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                            Text(
                                              pkg.isAnnual
                                                  ? '/ year'
                                                  : '/ ${pkg.durationDays} days',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: theme.textTheme.bodySmall
                                                    ?.color
                                                    ?.withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    const Divider(height: 1),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.receipt_long_rounded,
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          pkg.isUnlimitedInvoices
                                              ? 'Unlimited Daily Invoices'
                                              : '${pkg.dailyInvoiceLimit} Invoices / Day',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: theme.textTheme.bodyMedium?.color,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          isSelected
                                              ? Icons.radio_button_checked_rounded
                                              : Icons.radio_button_off_rounded,
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : Colors.grey,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Bottom Action Bar
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              offset: const Offset(0, -3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isProcessingPayment
                                      ? null
                                      : _showPayerDetailsSheet,
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isProcessingPayment
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _selectedPackage != null
                                              ? 'Subscribe with ${_selectedPackage!.name} (${_selectedPackage!.formattedPrice})'
                                              : 'Select a Package',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              if (canPop) ...[
                                const SizedBox(height: 6),
                                TextButton.icon(
                                  key: const Key('payment_bottom_back_button'),
                                  onPressed: _handleSkip,
                                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                                  label: const Text('Back to Invoices'),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 6),
                                TextButton.icon(
                                  key: const Key('payment_bottom_skip_button'),
                                  onPressed: _handleSkip,
                                  icon: const Icon(Icons.skip_next_rounded, size: 16),
                                  label: const Text('Skip for now'),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
      ),
    );
  }
}
