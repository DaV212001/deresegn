import 'package:deresegn/config/dio_config.dart';
import 'package:dio/dio.dart' as dio_lib;
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../config/config_preference.dart';
import '../models/auth_models.dart';
import '../models/company_models.dart';
import '../services/api_service.dart';

class AuthController extends GetxController {
  var isLinked = false.obs;
  var isLoggingIn = false.obs;
  var isCompanyLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    isLinked.value = ConfigPreference.getCompanyAccessToken() != null;
  }

  Future<void> checkDeviceLink() async {
    isLinked.value = ConfigPreference.getCompanyAccessToken() != null;
  }

  Future<void> registerCompany(
    String companyName,
    String tin,
    String owner,
    String phone,
    String password,
    String email,
    String website,
  ) async {
    isCompanyLoading.value = true;
    await ApiService.registerCompany(
      CompanyRegisterRequest(
        companyName: companyName,
        tinNumber: tin,
        ownerName: owner,
        phone: phone,
        password: password,
        email: email,
        website: website,
      ),
      onSuccess: (response) async {
        final token = _tokenFromResponse(response.data);
        if (token != null) {
          await ConfigPreference.updateCompanyToken(token);
          await ConfigPreference.clearMorTokens();
          await ConfigPreference.clearBranch();
          await ConfigPreference.saveCompanyContext(
            companyId: _idFromResponse(response.data) ?? '',
          );
          Get.offAllNamed('/branch-setup');
        } else {
          Get.snackbar('Registered', 'Company created. You can now log in.');
        }
      },
      onFailure: (e, r) => _handleError(e, r),
    );
    isCompanyLoading.value = false;
  }

  Future<void> loginCompany(
    String phone,
    String password,
    String companyId,
  ) async {
    if (phone.trim().isEmpty || password.isEmpty || companyId.trim().isEmpty) {
      Get.snackbar(
        'Missing details',
        'Phone, password, and company ID are required.',
      );
      return;
    }
    isCompanyLoading.value = true;
    await ApiService.loginCompany(
      CompanyLoginRequest(
        phone: phone.trim(),
        password: password,
        companyId: companyId.trim(),
      ),
      onSuccess: (response) async {
        final body = response.data is Map ? response.data : <String, dynamic>{};
        final data = body['data'] is Map ? body['data'] : body;
        final token =
            data['accessToken'] ?? data['access_token'] ?? data['token'];
        if (token == null) {
          Get.snackbar(
            'Login failed',
            'The server did not return an access token.',
          );
          return;
        }
        await ConfigPreference.updateCompanyToken('$token');
        await ConfigPreference.clearBranch();
        await ConfigPreference.saveCompanyContext(
          companyId: '${data['company_id'] ?? data['companyId'] ?? companyId}',
        );
        Get.offAllNamed('/branch-setup');
      },
      onFailure: (e, r) => _handleError(e, r),
    );
    isCompanyLoading.value = false;
  }

  Future<void> performMachineLogin() async {
    isLoggingIn.value = true;
    final clientId = await ConfigPreference.getClientId();
    final clientSecret = await ConfigPreference.getClientSecret();
    final apiKey = await ConfigPreference.getApiKey();
    final tin = await ConfigPreference.getTin();

    // if (clientId == null ||
    //     clientSecret == null ||
    //     apiKey == null ||
    //     tin == null) {
    //   isLinked.value = false;
    //   if (Get.currentRoute != '/setup_unlinked') {
    //     Get.offAllNamed('/setup_unlinked');
    //   }
    //   return;
    // }

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

  String? _tokenFromResponse(dynamic response) {
    if (response is! Map) return null;
    final data = response['data'] is Map ? response['data'] : response;
    return '${data['accessToken'] ?? data['access_token'] ?? data['token']}' ==
            'null'
        ? null
        : '${data['accessToken'] ?? data['access_token'] ?? data['token']}';
  }

  String? _idFromResponse(dynamic response) {
    if (response is! Map) return null;
    final data = response['data'] is Map ? response['data'] : response;
    final id = data['company_id'] ?? data['companyId'] ?? data['id'];
    return id == null ? null : '$id';
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
    if (data is! Map) return data.toString();
    final dynamic message = data['message'] ?? data['messages'];
    if (message == null) return null;

    if (message is List) {
      return message.join('\n');
    }
    return message.toString();
  }
}
