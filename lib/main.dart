import 'package:deresegn/utils/initial_navigation_middleware.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'config/config_preference.dart';
import 'controllers/auth_controller.dart';
import 'screens/dashboard_screen.dart';
import 'screens/setup_terminal_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigPreference.init();

  runApp(const DeresegnApp());
}

class DeresegnApp extends StatelessWidget {
  const DeresegnApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Deresegn Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00FFB3),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFB3),
          secondary: Color(0xFFFF3366),
        ),
      ),
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
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Color(0xFF00FFB3)),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFF00FFB3)),
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
