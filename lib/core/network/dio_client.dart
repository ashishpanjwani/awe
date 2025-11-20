import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Centralized Dio client to be reused across services.
///
/// - Applies timeouts and sane defaults
/// - Adds basic logging in debug mode
class DioClient {
  DioClient._internal() {
    final options = BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12),
      responseType: ResponseType.json,
      headers: const {
        'Accept': 'application/json, text/plain, */*',
        'Cache-Control': 'no-cache',
      },
    );
    _dio = Dio(options);

    if (kDebugMode) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            debugPrint('[Dio] → ${options.method} ${options.uri}');
            if (options.queryParameters.isNotEmpty) {
              debugPrint('[Dio]   query: ${options.queryParameters}');
            }
            handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint('[Dio] ← ${response.statusCode} ${response.requestOptions.uri}');
            handler.next(response);
          },
          onError: (error, handler) {
            debugPrint('[Dio] ✖ ${error.response?.statusCode} ${error.requestOptions.uri} :: ${error.message}');
            handler.next(error);
          },
        ),
      );
    }
  }

  static final DioClient _instance = DioClient._internal();
  static Dio get instance => _instance._dio;

  late final Dio _dio;
}
