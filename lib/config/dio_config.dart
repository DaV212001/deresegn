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

  Future<void> _redirectToLogin() async {
    await ConfigPreference.clearMorTokens();
    Get.offAllNamed('/company-auth');
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final isPublicEndpoint =
        options.path.contains('/company/register') ||
        options.path.contains('/company/login') ||
        options.path == '/api/companies' ||
        options.path == '/api/branch/login';
    final isCompanyEndpoint = options.path.startsWith('/api/branches');
    if (isPublicEndpoint || isCompanyEndpoint) {
      // Ensure company endpoints have Authorization header if not already set
      if (isCompanyEndpoint && !options.headers.containsKey('Authorization')) {
        final compToken =
            ConfigPreference.getCompanyAccessToken() ??
            ConfigPreference.getAccessToken();
        if (compToken != null) {
          options.headers['Authorization'] = 'Bearer $compToken';
        }
      }
      return handler.next(options);
    }

    final branchId = ConfigPreference.getBranchId();
    if (branchId != null &&
        branchId.isNotEmpty &&
        !options.path.contains('supplies')) {
      options.headers['Branch-Id'] = branchId;
    }
    if (ConfigPreference.isAccessTokenExpired()) {
      Logger().d('Branch token expired. Logging out...');
      await _redirectToLogin();
      return handler.reject(_sessionExpiredException(options));
    }

    final isSuppliesOrCompany =
        options.path.contains('supplies') ||
        options.path.startsWith('/api/branches');

    final token = isSuppliesOrCompany
        ? (ConfigPreference.getCompanyAccessToken() ??
              ConfigPreference.getAccessToken())
        : ConfigPreference.getAccessToken();

    if (!options.headers.containsKey('Authorization') && token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    if (options.path != '/api/login') {
      final morToken = ConfigPreference.getMorToken();
      if (morToken != null) {
        options.headers['Mor-Token'] = 'Bearer $morToken';
      }
    }

    return handler.next(options);
  }

  static bool _isAuthOrPublicEndpoint(String path) {
    return path.contains('/company/register') ||
        path.contains('/company/login') ||
        path.contains('/branch/login') ||
        path.contains('/verify') ||
        path.contains('/resend-otp') ||
        path.contains('/refresh/token') ||
        path.startsWith('/api/branches') ||
        path.contains('supplies') ||
        path == '/api/companies' ||
        path == '/api/login';
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final path = err.requestOptions.path;

    if (err.response?.statusCode == 401 && !_isAuthOrPublicEndpoint(path)) {
      if (path.contains('supplies')) {
        Logger().w(
          '⚠️ [SUPPLIES] Received 401 Unauthorized for supplies endpoint ($path). Preserving branch session.',
        );
        return handler.next(err);
      }

      final data = err.response?.data;
      final isMorError =
          data is Map &&
          (data['code'] == '4503' || data['message'] == 'GATEWAY ERROR');

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
        Logger().d('Branch 401 Unauthorized detected. Logging out...');
        await _redirectToLogin();
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
