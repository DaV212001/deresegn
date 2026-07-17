import 'package:deresegn/utils/initial_navigation_middleware.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'config/config_preference.dart';
import 'controllers/auth_controller.dart';
import 'screens/dashboard_screen.dart';
import 'screens/setup_terminal_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigPreference.init();
  final themeService = Get.put(ThemeService());

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
      initialRoute: '/dashboard',
      getPages: [
        GetPage(name: '/splash', page: () => SplashScreen()),
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
  SplashScreen({Key? key}) : super(key: key) {
    Get.put(AuthController(), permanent: true);
  }

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
