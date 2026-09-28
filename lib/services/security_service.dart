import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../config/config_preference.dart';
import '../config/dio_config.dart';

/// Result of comprehensive device integrity and tamper detection checks.
class SecurityCheckResult {
  final bool isCompromised;
  final List<String> violations;
  final bool isRooted;
  final bool isJailbroken;
  final bool isFridaDetected;
  final bool isDevMode;

  const SecurityCheckResult({
    required this.isCompromised,
    required this.violations,
    this.isRooted = false,
    this.isJailbroken = false,
    this.isFridaDetected = false,
    this.isDevMode = false,
  });

  static const clean = SecurityCheckResult(
    isCompromised: false,
    violations: [],
  );
}

/// Security Service responsible for Root Detection, Jailbreak Detection,
/// and Dynamic Instrumentation (Frida / Xposed) defenses.
class SecurityService extends GetxService {
  static final Logger _logger = Logger();

  final RxBool isCompromised = false.obs;
  final RxList<String> detectedViolations = <String>[].obs;

  /// Known su binary / superuser paths on Android
  static const List<String> _knownSuPaths = [
    '/system/app/Superuser.apk',
    '/sbin/su',
    '/system/bin/su',
    '/system/xbin/su',
    '/data/local/xbin/su',
    '/data/local/bin/su',
    '/system/sd/xbin/su',
    '/system/bin/failsafe/su',
    '/data/local/su',
    '/su/bin/su',
    '/system/bin/.ext/.su',
    '/system/usr/we-need-root/su-backup',
  ];

  /// Known Frida binary / artifact paths on Android
  static const List<String> _knownFridaPaths = [
    '/data/local/tmp/frida-server',
    '/data/local/tmp/re.frida.server',
    '/data/local/tmp/frida',
    '/sdcard/frida-server',
  ];

  /// Performs a full security audit of the device and runtime environment.
  /// If [enforceAction] is true and violations are detected, all tokens are wiped
  /// and the app is locked with [SecurityAlertScreen].
  Future<SecurityCheckResult> checkDeviceIntegrity({
    bool enforceAction = true,
  }) async {
    final violations = <String>[];
    bool isRooted = false;
    bool isJailbroken = false;
    bool isFridaDetected = false;
    bool isDevMode = false;

    // 1. Native Root / Jailbreak / DevMode checks via flutter_jailbreak_detection
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final isJailbrokenOrRooted = await FlutterJailbreakDetection.jailbroken;
        if (isJailbrokenOrRooted) {
          if (Platform.isAndroid) {
            isRooted = true;
            violations.add('Android Root detected (RootBeer check positive)');
          } else {
            isJailbroken = true;
            violations.add('iOS Jailbreak detected');
          }
        }
        if (Platform.isAndroid) {
          isDevMode = await FlutterJailbreakDetection.developerMode;
          if (isDevMode) {
            _logger.w('⚠️ Developer mode / USB debugging enabled on device.');
          }
        }
      }
    } on MissingPluginException {
      _logger.d('flutter_jailbreak_detection plugin not available on this platform');
    } on PlatformException catch (e) {
      _logger.w('PlatformException during jailbreak check: ${e.message}');
    } catch (e) {
      _logger.w('Error querying native jailbreak detection: $e');
    }

    // 2. Direct filesystem su binary presence checks (Android/Linux)
    if (Platform.isAndroid || Platform.isLinux) {
      for (final path in _knownSuPaths) {
        try {
          if (File(path).existsSync()) {
            isRooted = true;
            violations.add('Root binary identified at $path');
            break;
          }
        } catch (_) {}
      }
    }

    // 3. Dynamic Instrumentation / Frida Server Detection (TCP Probe on 27042 / 27043)
    if (Platform.isAndroid || Platform.isIOS || Platform.isLinux) {
      final fridaPortDetected = await _checkFridaPorts();
      if (fridaPortDetected) {
        isFridaDetected = true;
        violations.add('Active Frida Server detected listening on default port (27042/27043)');
      }

      // Check filesystem for known Frida server artifacts
      for (final path in _knownFridaPaths) {
        try {
          if (File(path).existsSync()) {
            isFridaDetected = true;
            violations.add('Frida server artifact discovered at $path');
            break;
          }
        } catch (_) {}
      }

      // Check /proc/self/maps for injected Frida / Xposed / Substrate agent libraries
      final mapsHookDetected = await _checkMemoryMaps();
      if (mapsHookDetected != null) {
        isFridaDetected = true;
        violations.add('Injected runtime hook library detected: $mapsHookDetected');
      }
    }

    final compromised = violations.isNotEmpty;
    isCompromised.value = compromised;
    detectedViolations.assignAll(violations);

    final result = SecurityCheckResult(
      isCompromised: compromised,
      violations: violations,
      isRooted: isRooted,
      isJailbroken: isJailbroken,
      isFridaDetected: isFridaDetected,
      isDevMode: isDevMode,
    );

    if (compromised) {
      _logger.e(
        '🚨 [SECURITY-INCIDENT] Device integrity check failed!\n'
        'Violations:\n - ${violations.join('\n - ')}',
      );

      if (enforceAction) {
        await _handleCompromisedDevice();
      }
    } else {
      _logger.i('🛡️ [SECURITY] Device integrity verified. Environment secure.');
    }

    return result;
  }

  /// Probes local loopback ports typically utilized by Frida server.
  Future<bool> _checkFridaPorts() async {
    for (final port in [27042, 27043]) {
      try {
        final socket = await Socket.connect(
          '127.0.0.1',
          port,
          timeout: const Duration(milliseconds: 200),
        );
        socket.destroy();
        return true;
      } catch (_) {
        // Port closed or unreachable, normal expected behavior
      }
    }
    return false;
  }

  /// Scans /proc/self/maps for dynamic hooking frameworks (Frida, Xposed, Substrate).
  Future<String?> _checkMemoryMaps() async {
    try {
      final mapsFile = File('/proc/self/maps');
      if (await mapsFile.exists()) {
        final lines = await mapsFile.readAsLines();
        for (final line in lines) {
          final lower = line.toLowerCase();
          if (lower.contains('frida-agent') ||
              lower.contains('frida-gadget') ||
              lower.contains('libfrida') ||
              lower.contains('xposed') ||
              lower.contains('substrate') ||
              lower.contains('cydiaSubstrate')) {
            return line.split(' ').last;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Incident response execution on compromised device.
  Future<void> _handleCompromisedDevice() async {
    _logger.e('🛡️ Purging sensitive session tokens, credentials, and active HTTP sessions...');

    // 1. Wipe all stored session tokens and branch credentials
    await ConfigPreference.clearAll();

    // 2. Reset Dio HTTP client instance
    DioConfig.resetDio();

    // 3. Direct navigation to the non-dismissible security alert screen
    if (Get.currentRoute != '/security-alert') {
      Get.offAllNamed('/security-alert');
    }
  }
}
