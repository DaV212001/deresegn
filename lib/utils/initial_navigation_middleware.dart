import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../config/config_preference.dart';
import '../services/security_service.dart';

class InitialNavigationMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (Get.isRegistered<SecurityService>() &&
        Get.find<SecurityService>().isCompromised.value) {
      Logger().e('Navigation blocked: device integrity compromised');
      return const RouteSettings(name: '/security-alert');
    }
    if (!ConfigPreference.isLoggedIn() ||
        ConfigPreference.getBranchId() == null) {
      Logger().i('Branch authentication required');
      return const RouteSettings(name: '/company-auth');
    }
    if (ConfigPreference.getBranchStatus() != null &&
        !ConfigPreference.isBranchActive()) {
      Logger().i('Branch subscription inactive or expired. Redirecting to payment packages');
      return const RouteSettings(name: '/payment-packages');
    }
    return null;
  }
}
