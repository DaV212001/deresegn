import 'dart:async';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../config/dio_config.dart';

class DioService {
  static const int _maxRetryableGetAttempts = 2;
  static const Duration _maxForegroundRetryDelay = Duration(seconds: 5);

  static bool _shouldRetry(DioException error) {
    final response = error.response;
    if (response == null) return false;
    final data = response.data;
    final isMarkedRetryable = data is Map && data['retryable'] == true;
    return response.statusCode == 520 || isMarkedRetryable;
  }

  static Duration _retryDelay(DioException error, int attempt) {
    final data = error.response?.data;
    final retryAfter = data is Map ? data['retry_after'] : null;
    final seconds = retryAfter is num ? retryAfter.toInt() : attempt * 2;
    final delay = Duration(seconds: seconds);
    return delay > _maxForegroundRetryDelay ? _maxForegroundRetryDelay : delay;
  }

  static Future<Response> _getWithRetry({
    required String path,
    Options? options,
    Object? data,
    Map<String, String>? queryParameters,
  }) async {
    var attempt = 0;
    while (true) {
      try {
        return await (await DioConfig.dio()).get(
          path,
          options: options,
          data: data,
          queryParameters: queryParameters,
        );
      } on DioException catch (error) {
        attempt += 1;
        if (attempt >= _maxRetryableGetAttempts || !_shouldRetry(error)) {
          rethrow;
        }
        final delay = _retryDelay(error, attempt);
        Logger().w(
          'Retrying GET $path after ${delay.inSeconds}s due to HTTP ${error.response?.statusCode}',
        );
        await Future.delayed(delay);
      }
    }
  }

  static Future<void> dioPost({
    required String path,
    Options? options,
    Map<String, dynamic>? data,
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    Response response = Response(requestOptions: RequestOptions());
    try {
      response = await (await DioConfig.dio()).post(
        path,
        options: options,
        data: data,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (onSuccess != null) onSuccess(response);
      } else {
        if (onFailure != null) onFailure(response.statusCode!, response);
      }
    } catch (e) {
      if (onFailure != null) onFailure(e, response);
    }
  }

  static Future<void> dioGet({
    required String path,
    Options? options,
    Object? data,
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
    Map<String, String>? queryParameters,
  }) async {
    Response response = Response(
      requestOptions: RequestOptions(queryParameters: queryParameters),
    );
    try {
      response = await _getWithRetry(
        path: path,
        options: options,
        data: data,
        queryParameters: queryParameters,
      );
      if (response.statusCode == 200) {
        if (onSuccess != null) onSuccess(response);
      } else {
        if (onFailure != null) onFailure(response.statusCode!, response);
      }
    } catch (e) {
      if (onFailure != null) onFailure(e, response);
    }
  }

  static Future<void> dioDelete({
    required String path,
    Options? options,
    Function(Response)? onSuccess,
    Function(Object, Response)? onFailure,
  }) async {
    Response response = Response(requestOptions: RequestOptions());
    try {
      response = await (await DioConfig.dio()).delete(path, options: options);
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (onSuccess != null) onSuccess(response);
      } else {
        if (onFailure != null) onFailure(response.statusCode!, response);
      }
    } catch (e) {
      if (onFailure != null) onFailure(e, response);
    }
  }
}
