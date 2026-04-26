import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'constants.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;

  const ApiException({this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

// ── Request activity notifiers ────────────────────────────────────────────────

// incremented on every request start, decremented on finish — drives the
// thin progress bar in the shell
final ValueNotifier<int> apiInFlight = ValueNotifier(0);

// emits a brief human-readable message after each successful mutation
// (POST / PUT / DELETE); listeners show it as a snackbar
final StreamController<String> apiSuccessEvents =
    StreamController<String>.broadcast();

// ── Client ────────────────────────────────────────────────────────────────────

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  late final Dio _dio = _buildDio();

  Dio _buildDio() {
    final dio = Dio(BaseOptions(
      baseUrl: kBaseUrl,
      // Render free tier cold-starts take 20-30s; 45s gives safe headroom
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 30),
    ));

    dio.interceptors.add(_ApiLogInterceptor());
    dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        final status = error.response?.statusCode;
        final body = error.response?.data;
        final msg = (body is Map ? body['detail'] as String? : null) ??
            error.message ??
            'Unknown error';
        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            error: ApiException(statusCode: status, message: msg),
            type: error.type,
            response: error.response,
          ),
        );
      },
    ));

    return dio;
  }

  Dio get dio => _dio;
}

// ── Interceptor ───────────────────────────────────────────────────────────────

class _ApiLogInterceptor extends Interceptor {
  static const _tag = '[API]';
  static const _maxBodyLen = 800;

  // brief labels for the success toast
  static const _labels = {
    'POST': 'Saved',
    'PUT': 'Updated',
    'DELETE': 'Deleted',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    apiInFlight.value++;
    if (kDebugMode) {
      final qs = options.queryParameters.isNotEmpty
          ? '  query=${options.queryParameters}'
          : '';
      final body = _fmt(options.data);
      debugPrint(
          '$_tag ▶ ${options.method} ${options.path}$qs'
          '${body.isNotEmpty ? '\n$_tag   body=$body' : ''}');
      options.extra['_ts'] = DateTime.now().millisecondsSinceEpoch;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    apiInFlight.value = (apiInFlight.value - 1).clamp(0, 999);
    if (kDebugMode) {
      final ms = _elapsed(response.requestOptions);
      debugPrint(
        '$_tag ✓ ${response.statusCode} ${response.requestOptions.method} '
        '${response.requestOptions.path}  (${ms}ms)\n'
        '$_tag   body=${_fmt(response.data)}',
      );
    }
    final method = response.requestOptions.method;
    final label = _labels[method];
    if (label != null) apiSuccessEvents.add(label);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    apiInFlight.value = (apiInFlight.value - 1).clamp(0, 999);
    if (kDebugMode) {
      final ms = _elapsed(err.requestOptions);
      final status = err.response?.statusCode ?? '—';
      final body = _fmt(err.response?.data);
      debugPrint(
        '$_tag ✗ $status ${err.requestOptions.method} ${err.requestOptions.path}  '
        '(${ms}ms)  type=${err.type.name}\n'
        '$_tag   message=${err.message}'
        '${body.isNotEmpty ? '\n$_tag   body=$body' : ''}',
      );
    }
    handler.next(err);
  }

  String _fmt(dynamic data) {
    if (data == null) return '';
    final s = data.toString();
    return s.length > _maxBodyLen ? '${s.substring(0, _maxBodyLen)}…' : s;
  }

  int _elapsed(RequestOptions options) {
    final ts = options.extra['_ts'] as int?;
    return ts != null ? DateTime.now().millisecondsSinceEpoch - ts : -1;
  }
}
