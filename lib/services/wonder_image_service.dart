import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WonderImageService {
  WonderImageService._();
  static final WonderImageService _instance = WonderImageService._();
  factory WonderImageService() => _instance;

  String get _accessKey => dotenv.env['UNSPLASH_ACCESS_KEY'] ?? '';

  final _dio = Dio(BaseOptions(
    baseUrl: 'https://api.unsplash.com',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  bool get _hasKey => _accessKey.isNotEmpty;

  Future<UnsplashResult?> fetchImage(String query) async {
    if (!_hasKey || query.trim().isEmpty) return null;

    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/search/photos',
        queryParameters: {
          'query': query,
          'per_page': 1,
          'orientation': 'landscape',
          'content_filter': 'high',
        },
        options: Options(
          headers: {'Authorization': 'Client-ID $_accessKey'},
        ),
      );

      final data = resp.data;
      if (data == null) return null;

      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return null;

      final photo = results[0] as Map<String, dynamic>;
      final urls = photo['urls'] as Map<String, dynamic>?;
      final user = photo['user'] as Map<String, dynamic>?;

      final imageUrl = (urls?['regular'] as String?) ?? '';
      if (imageUrl.isEmpty) return null;

      final userName = (user?['name'] as String?) ?? 'Unknown';
      final attribution = 'Photo by $userName on Unsplash';

      // Trigger Unsplash download tracking (required by API guidelines)
      final downloadLink = (photo['links'] as Map<String, dynamic>?)?['download_location'] as String?;
      if (downloadLink != null) {
        _triggerDownload(downloadLink);
      }

      return UnsplashResult(url: imageUrl, attribution: attribution);
    } on DioException catch (e) {
      debugPrint('[WonderImageService] Unsplash fetch error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[WonderImageService] Unexpected error: $e');
      return null;
    }
  }

  void _triggerDownload(String downloadLocation) {
    _dio.get(
      downloadLocation,
      options: Options(
        headers: {'Authorization': 'Client-ID $_accessKey'},
      ),
    ).ignore();
  }
}

class UnsplashResult {
  final String url;
  final String attribution;
  const UnsplashResult({required this.url, required this.attribution});
}
