import 'package:dio/dio.dart';
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
    final dio = Dio(BaseOptions(baseUrl: kBaseUrl));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        assert(() {
          // ignore: avoid_print
          print('[API] ${options.method} ${options.path}');
          return true;
        }());
        handler.next(options);
      },
      onError: (error, handler) {
        final status = error.response?.statusCode;
        final msg = error.response?.data?['detail'] as String? ?? error.message ?? 'Unknown error';
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
