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

class _ApiLogInterceptor extends Interceptor {
  // tag is short so logcat filter `[API` catches all lines
  static const _tag = '[API]';
  // truncate large bodies so logcat isn't flooded
  static const _maxBodyLen = 800;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      final qs = options.queryParameters.isNotEmpty
          ? '  query=${options.queryParameters}'
          : '';
      final body = _fmt(options.data);
      debugPrint('$_tag ▶ ${options.method} ${options.path}$qs${body.isNotEmpty ? '\n$_tag   body=$body' : ''}');
      options.extra['_ts'] = DateTime.now().millisecondsSinceEpoch;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      final ms = _elapsed(response.requestOptions);
      debugPrint(
        '$_tag ✓ ${response.statusCode} ${response.requestOptions.method} '
        '${response.requestOptions.path}  (${ms}ms)\n'
        '$_tag   body=${_fmt(response.data)}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final ms = _elapsed(err.requestOptions);
      final status = err.response?.statusCode ?? '—';
      final body = _fmt(err.response?.data);
      debugPrint(
        '$_tag ✗ $status ${err.requestOptions.method} ${err.requestOptions.path}  '
        '(${ms}ms)  type=${err.type.name}\n'
        '$_tag   message=${err.message}${body.isNotEmpty ? '\n$_tag   body=$body' : ''}',
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
