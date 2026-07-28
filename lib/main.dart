import 'package:deresegn/utils/app_translations.dart';
import 'package:deresegn/utils/initial_navigation_middleware.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'config/config_preference.dart';
import 'controllers/auth_controller.dart';
import 'services/offline_queue_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/setup_terminal_screen.dart';
import 'screens/company_auth_screen.dart';
import 'screens/branch_setup_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigPreference.init();
  final themeService = Get.put(ThemeService());

  // Initialize Offline Queue Service
  await Get.putAsync(() => OfflineQueueService().init());
  Get.put(AuthController(), permanent: true);

  runApp(DeresegnApp(themeService: themeService));
}

class DeresegnApp extends StatelessWidget {
  final ThemeService themeService;

  const DeresegnApp({Key? key, required this.themeService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Deresegn Client',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeService.themeMode,
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('en', 'US'),
      initialRoute: '/dashboard',
      initialBinding: BindingsBuilder(() {
        if (!Get.isRegistered<AuthController>()) {
          Get.put(AuthController(), permanent: true);
        }
      }),
      getPages: [
        GetPage(name: '/splash', page: () => SplashScreen()),
        GetPage(name: '/company-auth', page: () => const CompanyAuthScreen()),
        GetPage(name: '/branch-setup', page: () => const BranchSetupScreen()),
        GetPage(name: '/setup_unlinked', page: () => SetupTerminalScreen()),
        GetPage(
          name: '/dashboard',
          page: () => DashboardScreen(),
          middlewares: [InitialNavigationMiddleware()],
        ),
      ],
    );
  }
}

class SplashScreen extends StatelessWidget {
  SplashScreen({Key? key}) : super(key: key);

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
