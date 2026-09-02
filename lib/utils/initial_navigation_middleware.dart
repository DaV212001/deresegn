import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../config/config_preference.dart';

class InitialNavigationMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (!ConfigPreference.isLoggedIn() ||
        ConfigPreference.getBranchId() == null) {
      Logger().i('Branch authentication required');
      return const RouteSettings(name: '/company-auth');
    }
    return null;
  }
}
