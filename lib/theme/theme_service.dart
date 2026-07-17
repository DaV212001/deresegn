import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/config_preference.dart';

class ThemeService extends GetxController {
  final _isDarkMode = true.obs;

  bool get isDarkMode => _isDarkMode.value;

  ThemeMode get themeMode => _isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  @override
  void onInit() {
    super.onInit();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    _isDarkMode.value = await ConfigPreference.isDarkMode();
    Get.changeThemeMode(themeMode);
  }

  Future<void> toggleTheme() async {
    _isDarkMode.value = !_isDarkMode.value;
    await ConfigPreference.setDarkMode(_isDarkMode.value);
    Get.changeThemeMode(themeMode);
  }
}
