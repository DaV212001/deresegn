import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../config/config_preference.dart';

class InitialNavigationMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    // Check if the user is logged in
    bool isAuthenticated = ConfigPreference.isLoggedIn();
    if (!isAuthenticated) {
      Logger().i('Unauthenticated access attempted');
      return const RouteSettings(name: '/splash'); // Redirect to login page
    }

    // Check if onboarding is completed
    // if (!ConfigPreference.isOnboardingCompleted()) {
    //   Logger().i('Incomplete onboarding detected, redirecting to onboarding screen');
    //   return const RouteSettings(name: '/courier-onboarding'); // Redirect to onboarding
    // }

    return null; // Allow the navigation
  }
}
