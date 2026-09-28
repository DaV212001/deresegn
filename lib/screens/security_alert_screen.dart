import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../services/security_service.dart';

/// Non-dismissible security blocking screen shown when a device is rooted,
/// jailbroken, or dynamic instrumentation (Frida) is detected.
class SecurityAlertScreen extends StatelessWidget {
  const SecurityAlertScreen({super.key});

  void _exitApp() {
    try {
      SystemNavigator.pop();
    } catch (_) {}
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final securityService = Get.isRegistered<SecurityService>()
        ? Get.find<SecurityService>()
        : null;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF181111) : const Color(0xFFFFF5F5),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Shield Icon Container
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.gpp_bad_rounded,
                      size: 58,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Header Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, size: 14, color: Colors.redAccent),
                        SizedBox(width: 6),
                        Text(
                          'SECURITY COMPLIANCE ENFORCEMENT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title
                  const Text(
                    'Device Integrity Violation Detected',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Description
                  Text(
                    'This device is rooted, jailbroken, or has active dynamic analysis/instrumentation '
                    'tools (such as Frida or Xposed) running. To safeguard Ethiopian Ministry of Revenues '
                    '(MoR) e-invoicing keys, fiscal signatures, and sensitive commercial data, '
                    'Deresegn POS cannot operate in an unverified environment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Violation Details Card (if any violations detected)
                  if (securityService != null)
                    Obx(() {
                      final violations = securityService.detectedViolations;
                      if (violations.isEmpty) return const SizedBox.shrink();

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF251A1A) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 18, color: Colors.orangeAccent),
                                SizedBox(width: 8),
                                Text(
                                  'Detected Indicators:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...violations.map(
                              (v) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ',
                                        style: TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold)),
                                    Expanded(
                                      child: Text(
                                        v,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontFamily: 'monospace',
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _exitApp,
                      icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white),
                      label: const Text(
                        'Exit Application',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (securityService != null)
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await securityService.checkDeviceIntegrity(
                            enforceAction: false,
                          );
                          if (!result.isCompromised) {
                            Get.offAllNamed('/dashboard');
                          } else {
                            Get.snackbar(
                              'Security Alert',
                              'Device is still compromised. Access denied.',
                              backgroundColor: Colors.redAccent,
                              colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Re-check Environment'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
}
