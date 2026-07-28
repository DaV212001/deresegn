import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../config/config_preference.dart';

class InitialNavigationMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (ConfigPreference.getCompanyAccessToken() == null) {
      Logger().i('Company authentication required');
      return const RouteSettings(name: '/company-auth');
    }
    if (ConfigPreference.getBranchId() == null ||
        !ConfigPreference.isLoggedIn()) {
      Logger().i('Branch setup or background MOR login required');
      return const RouteSettings(name: '/branch-setup');
    }
    return null;
  }
}
