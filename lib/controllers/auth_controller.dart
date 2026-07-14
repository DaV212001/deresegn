import 'package:deresegn/config/dio_config.dart';
import 'package:dio/dio.dart' as dio_lib;
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../config/config_preference.dart';
import '../models/auth_models.dart';
import '../services/api_service.dart';

class AuthController extends GetxController {
  var isLinked = false.obs;
  var isLoggingIn = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkDeviceLink();
  }

  Future<void> checkDeviceLink() async {
    isLinked.value = await ConfigPreference.isLoggedIn();
    if (!isLinked.value) {
      //   if (Get.currentRoute != '/setup_unlinked') {
      //     Get.offAllNamed('/setup_unlinked');
      //   }
      // } else {
      performMachineLogin();
    }
  }

  Future<void> performMachineLogin() async {
    isLoggingIn.value = true;
    final clientId = await ConfigPreference.getClientId();
    final clientSecret = await ConfigPreference.getClientSecret();
    final apiKey = await ConfigPreference.getApiKey();
    final tin = await ConfigPreference.getTin();

    if (clientId == null ||
        clientSecret == null ||
        apiKey == null ||
        tin == null) {
      isLinked.value = false;
      if (Get.currentRoute != '/setup_unlinked') {
        Get.offAllNamed('/setup_unlinked');
      }
      return;
    }

    final request = LoginRequest(
      clientId: clientId,
      clientSecret: clientSecret,
      apikey: apiKey,
      tin: tin,
    );

    await ApiService.login(
      request,
      onSuccess: (response) async {
        final data = response.data['data'];
        if (data != null) {
          final token = data['accessToken'];
          final refresh = data['refreshToken'] ?? '';
          final expires = data['expiresIn'] ?? 3600;
          await ConfigPreference.updateTokens(token, refresh, expires);
          Logger().i('Machine login successful.');
          Get.offAllNamed('/dashboard');
        } else {
          Logger().w('Login returned 200 but no token payload.');
        }
      },
      onFailure: (error, response) {
        Logger().e('Machine login failed: $error');
        _handleError(error, response);
        isLoggingIn.value = false;
        Get.snackbar(
          'Login Failed',
          'Could not authenticate device. Status: ${response.statusCode}',
        );
      },
    );
    isLoggingIn.value = false;
  }

  void _handleError(dynamic error, dynamic response) {
    String errorMsg = "An error occurred while processing your request";

    if (error is dio_lib.DioException) {
      errorMsg = DioConfig.convertDioError(error);
      Logger().d(errorMsg);
      if (error.response?.data != null) {
        final backendMsg = _parseMessage(error.response!.data);
        Logger().d(backendMsg);
        if (backendMsg != null) errorMsg = backendMsg;
      }
    } else if (response != null && response.data != null) {
      final backendMsg = _parseMessage(response.data);
      Logger().d(backendMsg);
      if (backendMsg != null) errorMsg = backendMsg;
    }
    Get.snackbar('Error', errorMsg, snackPosition: SnackPosition.BOTTOM);
  }

  String? _parseMessage(dynamic data) {
    if (data == null) return null;
    final dynamic message = data['message'] ?? data['messages'];
    if (message == null) return null;

    if (message is List) {
      return message.join('\n');
    }
    return message.toString();
  }
}
