import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/token_storage.dart';
import '../ui/global_messenger.dart';
import 'api_endpoints.dart';
import 'api_exceptions.dart';

const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080/api/v1',
);

String fullPhotoUrl(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  final uri = Uri.parse(kApiBaseUrl);
  final host = '${uri.scheme}://${uri.host}:${uri.port}';
  return '$host$path';
}

final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Content-Type': 'application/json'},
    ),
  );
  dio.interceptors.add(_AuthInterceptor(ref, kApiBaseUrl));
  return dio;
});

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._ref, this.kApiBaseUrl);

  final Ref _ref;
  final String kApiBaseUrl;

  static const _retriedHeader = 'x-retried';

  static const _skipAuthPaths = <String>{
    ApiEndpoints.authEmailLogin,
    ApiEndpoints.authEmailRegister,
    ApiEndpoints.authOAuthGoogle,
    ApiEndpoints.authRefresh,
  };

  bool _isSkipAuth(String path) {
    for (final p in _skipAuthPaths) {
      if (path.endsWith(p)) return true;
    }
    return false;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isSkipAuth(options.path)) {
      final token = await _ref.read(tokenStorageProvider).readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final req = err.requestOptions;
    final isRefresh = req.path.endsWith(ApiEndpoints.authRefresh);
    final alreadyRetried = req.headers[_retriedHeader] == '1';

    if (response?.statusCode == 401 && !alreadyRetried && !isRefresh) {
      final storage = _ref.read(tokenStorageProvider);
      final refreshToken = await storage.readRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          final refreshDio = Dio(
            BaseOptions(
              baseUrl: kApiBaseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              headers: const {'Content-Type': 'application/json'},
            ),
          );
          final refreshResp = await refreshDio.post<Map<String, dynamic>>(
            ApiEndpoints.authRefresh,
            data: {'refreshToken': refreshToken},
          );
          final data = refreshResp.data;
          if (data == null) {
            throw DioException(requestOptions: req, response: refreshResp);
          }
          final newAccess = data['accessToken'] as String;
          final newRefresh = data['refreshToken'] as String;
          await storage.updateTokens(
            accessToken: newAccess,
            refreshToken: newRefresh,
          );

          final retryOptions = Options(
            method: req.method,
            headers: {
              ...req.headers,
              'Authorization': 'Bearer $newAccess',
              _retriedHeader: '1',
            },
            contentType: req.contentType,
            responseType: req.responseType,
          );
          final retryDio = Dio(
            BaseOptions(
              baseUrl: kApiBaseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );
          final retryResp = await retryDio.request<dynamic>(
            req.path,
            data: req.data,
            queryParameters: req.queryParameters,
            options: retryOptions,
          );
          return handler.resolve(retryResp);
        } catch (_) {
          await _ref.read(authControllerProvider.notifier).forceLogout();
          return handler.reject(_toApiError(err));
        }
      } else {
        await _ref.read(authControllerProvider.notifier).forceLogout();
      }
    }

    handler.reject(_toApiError(err));
  }

  DioException _toApiError(DioException err) {
    final status = err.response?.statusCode ?? 0;
    final body = err.response?.data;
    String message = err.message ?? 'Request failed';
    if (body is Map && body['detail'] is String) {
      message = body['detail'] as String;
    } else if (body is Map && body['message'] is String) {
      message = body['message'] as String;
    } else if (body is Map && body['error'] is String) {
      message = body['error'] as String;
    }
    ApiException apiErr;
    if (status == 0) {
      apiErr = NetworkException(message);
    } else if (status == 429) {
      final rlMsg = (body is Map && body['detail'] is String)
          ? body['detail'] as String
          : 'Too many requests. Please slow down.';
      apiErr = RateLimitedException(rlMsg);
      // Surface a global SnackBar so callers don't all have to do this.
      showAppSnackBarFromRef(_ref, rlMsg);
    } else {
      apiErr = ApiException(status, message, body);
    }
    return DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: apiErr,
      message: message,
    );
  }
}
