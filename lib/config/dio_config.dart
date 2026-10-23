import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../services/ssl_pinning_service.dart';
import 'config_preference.dart';

const String kApiBaseUrl = "https://api.deresegn.com";

class AuthInterceptor extends Interceptor {
  static Future<String?>? _refreshFuture;

  DioException _sessionExpiredException(
    RequestOptions requestOptions, {
    Response? response,
  }) {
    return DioException(
      requestOptions: requestOptions,
      response: response,
      type: DioExceptionType.unknown,
      message: 'Session expired. Please log in again.',
    );
  }

  static bool _isRedirecting = false;

  Future<void> _redirectToLogin({String? reason}) async {
    if (_isRedirecting) return;
    _isRedirecting = true;
    try {
      await ConfigPreference.clearTokens();
  
      if (Get.currentRoute != '/company-auth') {
    
        Get.offAllNamed('/company-auth');
        Get.snackbar(
          'Session Expired',
          reason ?? 'Please log in again.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      Logger().e('Error in _redirectToLogin: $e');
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        _isRedirecting = false;
      });
    }


  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Always request JSON to prevent backend from returning 302 web HTML views
    options.headers['Accept'] = 'application/json';

    final isUnauthenticated = _isUnauthenticatedEndpoint(options.path);
    if (isUnauthenticated) {
      return handler.next(options);
    }

    final rawBranchId = ConfigPreference.getBranchId();
    final branchId = rawBranchId?.trim().replaceAll(RegExp(r'^/+'), '');
    if (branchId != null &&
        branchId.isNotEmpty &&
        !options.path.contains('supplies')) {
      options.headers['Branch-Id'] = branchId;
    }

    final branchToken = ConfigPreference.getAccessToken();
    final companyToken = ConfigPreference.getCompanyAccessToken();

    // If both tokens are missing on a protected endpoint, reject
    if ((branchToken == null || branchToken.isEmpty) &&
        (companyToken == null || companyToken.isEmpty) &&
        options.path != '/api/login') {
      Logger().w('No authentication token available for ${options.path}');
      await _redirectToLogin();
      return handler.reject(_sessionExpiredException(options));
    }

    final isCompanyOnly =
        options.path.startsWith('/api/company') ||
        (options.path == '/api/branches' && options.method.toUpperCase() == 'POST');

    final token = isCompanyOnly
        ? (companyToken ?? branchToken)
        : (branchToken ?? companyToken);

    final existingAuth = options.headers['Authorization']?.toString();
    final isInvalidExistingAuth = existingAuth == null ||
        existingAuth.trim().isEmpty ||
        existingAuth == 'Bearer null' ||
        existingAuth == 'Bearer ';

    if (isInvalidExistingAuth && token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    if (options.path != '/api/login') {
      final morToken = ConfigPreference.getMorToken();
      if (morToken != null && morToken.isNotEmpty) {
        options.headers['Mor-Token'] = 'Bearer $morToken';
      }
    }

    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final data = response.data;
    final isHtml = data is String &&
        (data.trimLeft().toLowerCase().startsWith('<!doctype html') ||
            data.toLowerCase().contains('<html'));

    if (isHtml && response.requestOptions.path.startsWith('/api')) {
      Logger().w(
        'API endpoint ${response.requestOptions.path} returned HTML instead of JSON. Session likely expired.',
      );
      await _redirectToLogin();
      return handler.reject(
        _sessionExpiredException(response.requestOptions, response: response),
      );
    }

    return super.onResponse(response, handler);
  }


  static bool _isUnauthenticatedEndpoint(String path) {
    return path.contains('/company/register') ||
        path.contains('/company/login') ||
        path.contains('/branch/login') ||
        path.contains('/verify') ||
        path.contains('/verify-phone') ||
        path.contains('/resend-otp') ||
        path == '/api/companies';
  }

  static bool _isAuthEntrypoint(String path) {
    return path.contains('/company/register') ||
        path.contains('/company/login') ||
        path.contains('/branch/login') ||
        path.contains('/verify') ||
        path.contains('/verify-phone') ||
        path.contains('/resend-otp') ||
        path == '/api/companies' ||
        path == '/api/login';
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final path = err.requestOptions.path;
    final statusCode = err.response?.statusCode;
    final data = err.response?.data;

    final isUnauthenticated = statusCode == 401 ||
        (data is Map &&
            data['message']?.toString().toLowerCase().contains('unauthenticated') == true);

    if (isUnauthenticated && !_isAuthEntrypoint(path)) {
      final isMorError = data is Map &&
          (data['code'] == '4503' ||
           data['message'] == 'GATEWAY ERROR' ||
           (data['message']?.toString().toLowerCase().contains('mor') ?? false));

      if (isMorError) {
        Logger().d(
          'MoR 401 Unauthorized detected. Attempting reactive refresh...',
        );
        final newToken = await _refreshAccessToken();
        if (newToken != null) {
          final req = err.requestOptions;
          req.headers['Mor-Token'] = 'Bearer $newToken';

          final dio = await DioConfig.dio();
          try {
            final cloneResponse = await dio.fetch(req);
            return handler.resolve(cloneResponse);
          } catch (e) {
            return handler.next(err);
          }
        } else {
          Logger().w('MoR Token refresh failed. Clearing MoR token...');
          await ConfigPreference.clearMorTokens();
          return handler.next(err);
        }
      } else {
        Logger().w('Session expired or unauthenticated on $path (401). Logging out...');
        await _redirectToLogin(reason: 'Session expired. Please log in again.');
        return handler.reject(
          _sessionExpiredException(err.requestOptions, response: err.response),
        );
      }
    }
    return handler.next(err);
  }

  Future<String?> _refreshAccessToken() async {
    if (_refreshFuture != null) {
      Logger().d('Token refresh already in progress, joining future...');
      return _refreshFuture;
    }

    _refreshFuture = _performTokenRefresh();
    try {
      final result = await _refreshFuture;
      return result;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<String?> _performTokenRefresh() async {
    Logger().d('Starting MoR token refresh request...');
    final refreshToken = ConfigPreference.getRefreshToken();
    if (refreshToken == null) {
      Logger().e('No refresh token found in storage');
      return null;
    }

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: kApiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
        ),
      );
      dio.httpClientAdapter = SslPinningService.createPinnedAdapter();

      final response = await dio.post(
        '/api/refresh/token',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final data = response.data['data'];
        if (data != null) {
          final newAccessToken = data['accessToken'];
          final newRefreshToken = data['refreshToken'] ?? refreshToken;
          final expiresIn = data['expiresIn'] ?? 3600;

          if (newAccessToken != null) {
            await ConfigPreference.updateMorTokens(
              newAccessToken,
              newRefreshToken,
              expiresIn,
            );
            Logger().i('MoR Token refresh successful');
            return newAccessToken;
          }
        }
      }
    } catch (e) {
      Logger().e('MoR Token refresh failed with exception', error: e);
    }
    return null;
  }
}

class LoggingInterceptor extends Interceptor {
  final _encoder = const JsonEncoder.withIndent('  ');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    Logger().i({
      'url': options.uri.toString(),
      'method': options.method,
      'headers': options.headers,
      'body': options.data,
    });
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    Logger().i(
      '✅ ${response.statusCode} ${response.requestOptions.uri}\n'
      'Response:\n${_encoder.convert(response.data)}',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    Logger().e(
      '❌ ${err.response?.statusCode} ${err.requestOptions.uri}\n'
      'Error Body:\n${_encoder.convert(err.response?.data)}',
    );
    super.onError(err, handler);
  }
}

class DioConfig {
  static bool isTestMode = false;
  static PersistCookieJar? cookieJar;
  static Dio? _dioInstance;

  static void resetDio() {
    _dioInstance = null;
  }

  static bool isSessionExpiredError(Object error) {
    return error is DioException &&
        error.message == 'Session expired. Please log in again.';
  }

  static String convertDioError(DioException e) {
    String errorMessage = 'Unknown error occurred';
    switch (e.type) {
      case DioExceptionType.cancel:
        errorMessage = 'Request cancelled';
        break;
      case DioExceptionType.connectionTimeout:
        errorMessage = 'Connection timeout';
        break;
      case DioExceptionType.sendTimeout:
        errorMessage = 'Send timeout';
        break;
      case DioExceptionType.receiveTimeout:
        errorMessage = 'Receive timeout';
        break;
      case DioExceptionType.badResponse:
        errorMessage =
            'HTTP error ${e.response!.statusCode}: ${e.response!.statusMessage}';
        break;
      case DioExceptionType.unknown:
        errorMessage = e.message ?? 'Other Dio error occurred';
        break;
      case DioExceptionType.badCertificate:
        errorMessage =
            'Security Alert: SSL/TLS certificate verification failed. Untrusted network connection detected.';
        break;
      case DioExceptionType.connectionError:
        errorMessage = 'Connection error, check your internet';
        break;
      case DioExceptionType.transformTimeout:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
    return errorMessage;
  }

  static Future<Dio> dio() async {
    if (_dioInstance != null) return _dioInstance!;

    if (cookieJar == null) {
      final dir = await getApplicationDocumentsDirectory();
      cookieJar = PersistCookieJar(
        storage: FileStorage('${dir.path}/.cookies/'),
      );
    }

    _dioInstance = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 120),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    // Enforce SSL/TLS Certificate Pinning on all requests
    _dioInstance!.httpClientAdapter = SslPinningService.createPinnedAdapter();

    if (!isTestMode) {
      _dioInstance!.interceptors.addAll([
        AuthInterceptor(),
        LoggingInterceptor(),
      ]);
    }

    return _dioInstance!;
  }
}
