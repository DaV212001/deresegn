import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/branch_certificate_controller.dart';
import '../services/insa_request_form_service.dart';

class BranchCertificateScreen extends StatefulWidget {
  final int branchId;
  final String tin;
  final String organizationName;
  final String organizationalUnit;
  final String email;
  final String systemNumber;
  final String ownerName;
  final String phone;
  final bool isFromRegistration;

  const BranchCertificateScreen({
    super.key,
    required this.branchId,
    this.tin = '',
    this.organizationName = '',
    this.organizationalUnit = 'Head Office',
    this.email = '',
    this.systemNumber = 'SYS-0001',
    this.ownerName = '',
    this.phone = '',
    this.isFromRegistration = false,
    this.startAtUpload = false,
  });

  final bool startAtUpload;

  @override
  State<BranchCertificateScreen> createState() => _BranchCertificateScreenState();
}

class _BranchCertificateScreenState extends State<BranchCertificateScreen> {
  late final BranchCertificateController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      BranchCertificateController(
        branchId: widget.branchId,
        initialTin: widget.tin,
        initialOrgName: widget.organizationName,
        initialOrgUnit: widget.organizationalUnit,
        initialEmail: widget.email,
        initialSystemNumber: widget.systemNumber,
        initialOwnerName: widget.ownerName,
        initialPhone: widget.phone,
        startAtUpload: widget.startAtUpload,
      ),
      tag: 'branch_cert_${widget.branchId}',
    );
  }

  @override
  void dispose() {
    Get.delete<BranchCertificateController>(tag: 'branch_cert_${widget.branchId}');
    super.dispose();
  }

  InputDecoration _inputDecoration(
    BuildContext context,
    String label, {
    IconData? icon,
    String? helperText,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      filled: true,
      fillColor: theme.inputDecorationTheme.fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('MoR Digital Certificate'),
        leading: widget.isFromRegistration
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Get.back(),
              ),
        actions: [
          if (widget.isFromRegistration)
            TextButton(
              onPressed: () => Get.offAllNamed('/dashboard'),
              child: const Text('Setup Later'),
            ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          final isDone = controller.isCertificateInstalled.value;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Status Card
                    _buildHeaderBanner(context, isDone),
                    const SizedBox(height: 20),

                    // Step Indicator
                    _buildStepIndicator(context),
                    const SizedBox(height: 24),

                    // Active Step View
                    if (controller.currentStep.value == 1) ...[
                      _buildStep1Card(context),
                    ] else if (controller.currentStep.value == 2) ...[
                      _buildStep2Card(context),
                    ] else if (controller.currentStep.value == 3) ...[
                      _buildStep3Card(context),
                    ] else if (controller.currentStep.value == 4) ...[
                      _buildStep4Card(context),
                      if (!isDone) ...[
                        const SizedBox(height: 24),
                        _buildAccordionForOtherSteps(context),
                      ],
                    ],
                    const SizedBox(height: 32),

                    // Bottom Navigation / Complete Button
                    if (isDone || widget.isFromRegistration)
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => Get.offAllNamed('/dashboard'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: Text(
                            isDone ? 'Continue to Dashboard' : 'Finish & Go to Dashboard',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context, bool isDone) {
    final theme = Theme.of(context);

    if (isDone) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Certificate Installed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Branch #${widget.branchId} is certified and ready to sign invoices with INSA & MoR.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final hasMismatch = controller.hasCertificate.value && !controller.certificateMatchesKey.value;
    final hasKeyOnly = controller.hasPrivateKey.value && !controller.hasCertificate.value;

    if (hasMismatch) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Certificate Key Mismatch',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The certificate does not match this branch\'s private key. Please re-upload the matching certificate or generate a new CSR.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (hasKeyOnly) {
      final noCsrOnDevice = !controller.hasCsrOnDevice;
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                noCsrOnDevice ? Icons.vpn_key_off_rounded : Icons.vpn_key_rounded,
                color: Colors.amber,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    noCsrOnDevice ? 'No CSR on Device (Server Key Exists)' : 'Private Key Ready',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    noCsrOnDevice
                        ? 'The server has a private key for this branch, but there isn\'t a CSR on this device. Go back to Step 1 to generate one again.'
                        : 'Branch #${widget.branchId} has generated a CSR and private key. Please upload the certificate once issued by INSA.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primaryColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_outlined, color: theme.colorScheme.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INSA Certificate Setup',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'To digitally sign and transmit e-invoices to MoR, obtain and install your INSA certificate.',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final current = controller.currentStep.value;
    final steps = const [
      {'step': 1, 'label': 'CSR'},
      {'step': 2, 'label': 'Save'},
      {'step': 3, 'label': 'INSA'},
      {'step': 4, 'label': 'Upload'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 340;
          final isMini = constraints.maxWidth < 220;

          return Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                final prevStep = (index ~/ 2) + 1;
                final isDividerActive = current > prevStep;
                return Expanded(
                  child: Container(
                    height: 2,
                    margin: EdgeInsets.symmetric(horizontal: isCompact ? 2 : 4),
                    color: isDividerActive
                        ? theme.colorScheme.primary
                        : theme.dividerColor.withOpacity(0.35),
                  ),
                );
              }

              final stepIndex = index ~/ 2;
              final stepItem = steps[stepIndex];
              final stepNum = stepItem['step'] as int;
              final label = stepItem['label'] as String;
              final isPast = current > stepNum;
              final isCurrent = current == stepNum;
              final isActive = current >= stepNum;

              return InkWell(
                key: Key('step_indicator_$stepNum'),
                onTap: () {
                  if (stepNum == 1) {
                    controller.goToStep1();
                  } else {
                    controller.currentStep.value = stepNum;
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: isCompact ? 9 : 10,
                        backgroundColor: isActive
                            ? theme.colorScheme.primary
                            : theme.dividerColor.withOpacity(0.3),
                        child: isPast
                            ? Icon(Icons.check, size: isCompact ? 10 : 12, color: Colors.white)
                            : Text(
                                '$stepNum',
                                style: TextStyle(
                                  fontSize: isCompact ? 9 : 10,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.white : theme.textTheme.bodySmall?.color,
                                ),
                              ),
                      ),
                      if (!isMini && (!isCompact || isCurrent)) ...[
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: isCompact ? 10 : 11,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isActive ? theme.colorScheme.primary : Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  // --- Step 1 Card: CSR Generation ---
  Widget _buildStep1Card(BuildContext context) {
    final theme = Theme.of(context);
    final hasExistingKeyOrCsr = controller.hasCsrOnDevice;

    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (controller.hasPrivateKey.value && !controller.hasCsrOnDevice) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.vpn_key_off_rounded, color: Colors.amber, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No CSR on Device',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'The server has a private key for this branch, but there isn\'t a CSR on this device, so you should generate one again.',
                            style: TextStyle(fontSize: 12, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Generate Certificate Signing Request',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller.tinController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: _inputDecoration(
                context,
                'Taxpayer TIN (Common Name)',
                icon: Icons.badge_outlined,
                helperText: '10-digit TIN registered with MoR',
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller.systemNumberController,
              decoration: _inputDecoration(
                context,
                'System Number (Serial Number)',
                icon: Icons.confirmation_number_outlined,
                helperText: 'e.g., SYS-0001 or POS System ID',
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller.orgNameController,
              decoration: _inputDecoration(
                context,
                'Organization Name',
                icon: Icons.business_outlined,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller.orgUnitController,
              decoration: _inputDecoration(
                context,
                'Organizational Unit',
                icon: Icons.store_outlined,
                helperText: 'e.g. Head Office, Main Branch',
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller.emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration(
                context,
                'Email Address',
                icon: Icons.email_outlined,
              ),
            ),
            const SizedBox(height: 18),

            // Optional Contact Person Details (included in the INSA Request Form)
            ExpansionTile(
              initiallyExpanded: false,
              tilePadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline, size: 20),
              title: const Text(
                'Contact Person Information (For INSA Form)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              children: [
                const SizedBox(height: 8),
                TextField(
                  controller: controller.ownerNameController,
                  decoration: _inputDecoration(
                    context,
                    'Full Name',
                    icon: Icons.person_outline,
                    helperText: 'Contact person submitting to INSA',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller.phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration(
                    context,
                    'Telephone Number',
                    icon: Icons.phone_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller.addressController,
                  decoration: _inputDecoration(
                    context,
                    'Address / City',
                    icon: Icons.location_on_outlined,
                    helperText: 'e.g. Addis Ababa',
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),

            const SizedBox(height: 22),
            if (controller.is409Conflict.value) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.amber),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Certificate already installed. To re-issue, replace with force: true.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () => controller.confirmReplaceAndRegenerate(),
                      child: const Text('Replace'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: controller.isLoading.value
                    ? null
                    : () => controller.generateCsr(),
                icon: controller.isLoading.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.vpn_key_rounded),
                label: const Text(
                  'Generate CSR',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),

            if (hasExistingKeyOrCsr) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => controller.currentStep.value = 2,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Proceed to Download Files (Step 2)',
                      maxLines: 1,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Step 2 Card: Saved PEM file & INSA Request Form ---
  Widget _buildStep2Card(BuildContext context) {
    final theme = Theme.of(context);
    final csrPath = controller.csrFilePath.value ?? 'branch-${widget.branchId}-csr.pem';
    final isCsrPublic = controller.isCsrInPublicDir.value;
    final publicCsr = controller.publicCsrPath.value;
    final hasCsrCache = controller.csrFilePath.value != null;

    final isFormPublic = controller.isRequestFormInPublicDir.value;
    final publicForm = controller.publicRequestFormPath.value;
    final hasFormCache = controller.requestFormFilePath.value != null;

    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.green.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.green,
                  child: Icon(Icons.check, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Step 2: Download CSR & Request Form',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'INSA requires BOTH files to be attached to your email. You can find them in your public Downloads directory or share/preview them below.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 18),

            // --- FILE 1: CSR .PEM FILE ---
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.vpn_key_rounded, color: Colors.blueGrey, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'branch-${widget.branchId}-csr.pem',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              hasCsrCache ? 'Path: $csrPath' : 'Status: Not on device',
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isCsrPublic && publicCsr != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ready in Public Downloads:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  publicCsr,
                                  style: const TextStyle(fontSize: 11, fontFamily: 'Courier'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            tooltip: 'Copy path',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: publicCsr));
                              Get.snackbar('Copied', 'CSR path copied: $publicCsr');
                            },
                          ),
                        ],
                      ),
                    ),
                  ] else if (hasCsrCache) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Cached in app storage. Save to public Downloads to attach easily.',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                            onPressed: () => controller.downloadCsrToPublicDirectory(),
                            icon: const Icon(Icons.download_rounded, size: 14),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Download', maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'CSR file not found on this device. Please return to Step 1 to generate it.',
                              style: TextStyle(fontSize: 11, color: Colors.red),
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                            onPressed: () => controller.goToStep1(),
                            icon: const Icon(Icons.arrow_back_rounded, size: 14),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Go to Step 1', maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          ),
                          onPressed: () => controller.copyCsrToClipboard(),
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Copy CSR Text', maxLines: 1, style: TextStyle(fontSize: 11.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          ),
                          onPressed: () => controller.shareCsrFile(),
                          icon: const Icon(Icons.share_outlined, size: 14),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Share / Export', maxLines: 1, style: TextStyle(fontSize: 11.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // --- FILE 2: INSA REQUEST FORM (PDF) ---
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'branch-${widget.branchId}-insa-request-form.pdf',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Text(
                              'Digital Certificate Request Form (INSA Official)',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isFormPublic && publicForm != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ready in Public Downloads:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  publicForm,
                                  style: const TextStyle(fontSize: 11, fontFamily: 'Courier'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            tooltip: 'Copy path',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: publicForm));
                              Get.snackbar('Copied', 'Request form path copied: $publicForm');
                            },
                          ),
                        ],
                      ),
                    ),
                  ] else if (hasFormCache) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Generated and cached. Save to public Downloads to attach easily.',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                            onPressed: () => controller.downloadRequestFormToPublicDirectory(),
                            icon: const Icon(Icons.download_rounded, size: 14),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Download', maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Request form not found. Please return to Step 1 to generate CSR and form.',
                              style: TextStyle(fontSize: 11, color: Colors.red),
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                            onPressed: () => controller.goToStep1(),
                            icon: const Icon(Icons.arrow_back_rounded, size: 14),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Go to Step 1', maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          ),
                          onPressed: () => controller.previewRequestForm(),
                          icon: const Icon(Icons.visibility_outlined, size: 14),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Preview PDF', maxLines: 1, style: TextStyle(fontSize: 11.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          ),
                          onPressed: () => controller.shareRequestFormFile(),
                          icon: const Icon(Icons.share_outlined, size: 14),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Share / Export', maxLines: 1, style: TextStyle(fontSize: 11.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Step 2 Navigation Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                    onPressed: () => controller.goToStep1(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 15),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Back to Step 1', maxLines: 1, style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                    onPressed: () => controller.currentStep.value = 3,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Next: Step 3 (INSA)', maxLines: 1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 3 Card: Submission to INSA ---
  Widget _buildStep3Card(BuildContext context) {
    final theme = Theme.of(context);
    final isCsrReady = controller.hasCsrOnDevice &&
        (controller.publicCsrPath.value != null || controller.csrFilePath.value != null);
    final isFormReady =
        controller.publicRequestFormPath.value != null || controller.requestFormFilePath.value != null;

    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                  child: Text(
                    '3',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Step 3: Send CSR & Request Form to INSA',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Send an email to INSA with BOTH generated files attached. Once INSA verifies your request, they will reply with your digital certificate.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 16),

            // Attachments Checklist Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Required Attachments Checklist:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        isCsrReady ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        size: 16,
                        color: isCsrReady ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '1. branch-${widget.branchId}-csr.pem (CSR file)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isCsrReady ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (controller.publicCsrPath.value != null)
                        const Text('In Downloads ✓', style: TextStyle(fontSize: 11, color: Colors.green)),
                    ],
                  ),
                  const Divider(height: 12),
                  Row(
                    children: [
                      Icon(
                        isFormReady ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        size: 16,
                        color: isFormReady ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '2. branch-${widget.branchId}-insa-request-form.pdf (Request Form)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isFormReady ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (controller.publicRequestFormPath.value != null)
                        const Text('In Downloads ✓', style: TextStyle(fontSize: 11, color: Colors.green)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Email Details Container
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('To', BranchCertificateController.insaEmail),
                  const Divider(height: 16),
                  _infoRow('Subject', controller.emailSubject),
                  const Divider(height: 16),
                  const Text(
                    'Body Preview:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.emailBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'Courier',
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => controller.openEmailWithAttachmentReminder(),
                icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Open Gmail / Email App',
                    maxLines: 1,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => controller.copyEmailTemplate(),
                icon: const Icon(Icons.content_copy_rounded, size: 15),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Copy Email Template', maxLines: 1, style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'View E-Invoice Digital Certificate Request Form details',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    InsaRequestFormService.generateText(controller.getRequestFormData()),
                    style: const TextStyle(fontSize: 11, fontFamily: 'Courier', height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Step 3 Navigation Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                    onPressed: () => controller.currentStep.value = 2,
                    icon: const Icon(Icons.arrow_back_rounded, size: 15),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Back to Step 2', maxLines: 1, style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                    onPressed: () => controller.currentStep.value = 4,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Next: Step 4 (Upload)', maxLines: 1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 4 Card: Upload Certificate ---
  Widget _buildStep4Card(BuildContext context) {
    final theme = Theme.of(context);
    final isMatched = controller.matchesPrivateKey.value;

    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isMatched == true
              ? Colors.green
              : (isMatched == false ? Colors.amber.shade700 : theme.dividerColor.withOpacity(0.4)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                  child: Text(
                    '4',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Step 4: Upload INSA-Issued Certificate',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'When INSA replies with the certificate file (.pem, .crt, or .cer), select or paste it below to install and activate your branch.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            if (controller.hasPrivateKey.value && !controller.hasCsrOnDevice) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.vpn_key_off_rounded, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No CSR on Device',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'The server has a private key for this branch, but there isn\'t a CSR on this device, so you should generate one again.',
                      style: TextStyle(fontSize: 12, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => controller.goToStep1(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 15),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Go to Step 1: Generate CSR Again',
                            maxLines: 1,
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Pick Button
            OutlinedButton.icon(
              onPressed: () => controller.pickCertificateFile(),
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  controller.selectedCertFileName.value ?? 'Pick Certificate File (.pem, .crt, .cer)',
                  maxLines: 1,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Optional Paste Field
            TextField(
              controller: controller.certManualInputController,
              maxLines: 4,
              style: const TextStyle(fontFamily: 'Courier', fontSize: 11),
              decoration: _inputDecoration(
                context,
                'Or Paste Certificate Text (starts with -----BEGIN CERTIFICATE-----)',
                helperText: 'Must begin with -----BEGIN CERTIFICATE-----',
              ),
              onChanged: (val) {
                controller.selectedCertContent.value = val;
              },
            ),
            const SizedBox(height: 16),

            // Mismatch or Installed Status
            if (isMatched == false) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This certificate doesn’t match this branch’s key. Generate a new request and send it to INSA again.',
                        style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => controller.confirmReplaceAndRegenerate(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Generate New Request (force: true)', maxLines: 1, style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (isMatched == true) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_rounded, color: Colors.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Certificate installed successfully! Matches private key.',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: controller.isLoading.value
                    ? null
                    : () => controller.uploadCertificate(),
                icon: controller.isLoading.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Upload Certificate',
                    maxLines: 1,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => controller.currentStep.value = 3,
                icon: const Icon(Icons.arrow_back_rounded, size: 15),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Back to Step 3: INSA Submission', maxLines: 1, style: TextStyle(fontSize: 12.5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccordionForOtherSteps(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
          ),
          child: ExpansionTile(
            title: const Text(
              'Need to review CSR, download files, or instructions?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            leading: const Icon(Icons.history_rounded, size: 20),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        radius: 12,
                        child: Text('1', style: TextStyle(fontSize: 11)),
                      ),
                      title: const Text('Step 1: Generate / Replace CSR',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => controller.goToStep1(),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const CircleAvatar(
                        radius: 12,
                        child: Text('2', style: TextStyle(fontSize: 11)),
                      ),
                      title: const Text('Step 2: Download CSR & Request Form',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => controller.currentStep.value = 2,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const CircleAvatar(
                        radius: 12,
                        child: Text('3', style: TextStyle(fontSize: 11)),
                      ),
                      title: const Text('Step 3: INSA Email Template & Checklist',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => controller.currentStep.value = 3,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
