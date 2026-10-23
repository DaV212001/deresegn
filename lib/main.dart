import 'package:deresegn/utils/app_translations.dart';
import 'package:deresegn/utils/initial_navigation_middleware.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'config/config_preference.dart';
import 'controllers/auth_controller.dart';
import 'services/offline_queue_service.dart';
import 'services/cancelled_invoices_storage.dart';
import 'services/push_notification_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/setup_terminal_screen.dart';
import 'screens/company_auth_screen.dart';
import 'screens/branch_setup_screen.dart';
import 'screens/delete_account_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/payment_packages_screen.dart';
import 'screens/security_alert_screen.dart';
import 'services/security_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Security Module before loading sensitive state
  final securityService = Get.put(SecurityService(), permanent: true);
  final securityResult = await securityService.checkDeviceIntegrity(enforceAction: true);

  await ConfigPreference.init();
  await CancelledInvoicesStorage.init();
  final themeService = Get.put(ThemeService());

  // Initialize Push Notification Service (Firebase Cloud Messaging + AwesomeNotifications)
  await PushNotificationService.initialize();

  // Initialize Offline Queue Service
  await Get.putAsync(() => OfflineQueueService().init());
  Get.put(AuthController(), permanent: true);

  runApp(DeresegnApp(
    themeService: themeService,
    isCompromised: securityResult.isCompromised,
  ));
}

class DeresegnApp extends StatefulWidget {
  final ThemeService themeService;
  final bool isCompromised;

  const DeresegnApp({
    super.key,
    required this.themeService,
    this.isCompromised = false,
  });

  @override
  State<DeresegnApp> createState() => _DeresegnAppState();
}

class _DeresegnAppState extends State<DeresegnApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (Get.isRegistered<SecurityService>()) {
        Get.find<SecurityService>().checkDeviceIntegrity(enforceAction: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Deresegn Client',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: widget.themeService.themeMode,
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('en', 'US'),
      initialRoute: widget.isCompromised ? '/security-alert' : '/dashboard',
      initialBinding: BindingsBuilder(() {
        if (!Get.isRegistered<AuthController>()) {
          Get.put(AuthController(), permanent: true);
        }
      }),
      getPages: [
        GetPage(name: '/splash', page: () => const SplashScreen()),
        GetPage(name: '/security-alert', page: () => const SecurityAlertScreen()),
        GetPage(name: '/company-auth', page: () => const CompanyAuthScreen()),
        GetPage(name: '/branch-setup', page: () => const BranchSetupScreen()),
        GetPage(name: '/setup_unlinked', page: () => SetupTerminalScreen()),
        GetPage(
          name: '/dashboard',
          page: () => DashboardScreen(),
          middlewares: [InitialNavigationMiddleware()],
        ),
        GetPage(name: '/delete-account', page: () => const DeleteAccountScreen()),
        GetPage(
          name: '/otp-verification',
          page: () => const OtpVerificationScreen(phone: ''),
        ),
        GetPage(
          name: '/payment-packages',
          page: () => const PaymentPackagesScreen(),
        ),
      ],
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: theme.primaryColor),
            SizedBox(height: 24),
            CircularProgressIndicator(color: theme.primaryColor),
            SizedBox(height: 16),
            Text(
              'Initializing Security Module...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
