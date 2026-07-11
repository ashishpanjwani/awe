import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CseResult {
  final String title;
  final String snippet;
  final String url;

  const CseResult({required this.title, required this.snippet, required this.url});
}

class GoogleCseService {
  GoogleCseService._();
  static final GoogleCseService _instance = GoogleCseService._();
  factory GoogleCseService() => _instance;

  String get _apiKey => dotenv.env['GOOGLE_CSE_API_KEY'] ?? '';
  String get _cseId => dotenv.env['GOOGLE_CSE_ID'] ?? '';
  bool get hasKey => _apiKey.isNotEmpty && _cseId.isNotEmpty;

  final _dio = Dio(BaseOptions(
    baseUrl: 'https://www.googleapis.com/customsearch/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Search Instagram posts for a city
  Future<List<CseResult>> searchInstagram(String city, {int limit = 5}) async {
    if (!hasKey) {
      debugPrint('[GoogleCSE] No API key or CSE ID — skipping Instagram search');
      return [];
    }

    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '',
        queryParameters: {
          'key': _apiKey,
          'cx': _cseId,
          'q': '$city places to visit',
          'num': limit,
        },
      );

      final items = (resp.data?['items'] as List?) ?? [];
      final results = <CseResult>[];

      for (final item in items) {
        final title = (item['title'] as String?)?.trim() ?? '';
        final snippet = (item['snippet'] as String?)?.trim() ?? '';
        final url = (item['link'] as String?)?.trim() ?? '';
        if (title.isEmpty || url.isEmpty) continue;

        results.add(CseResult(title: title, snippet: snippet, url: url));
      }

      debugPrint('[GoogleCSE] Found ${results.length} Instagram results for "$city"');
      return results;
    } on DioException catch (e) {
      debugPrint('[GoogleCSE] Search error: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('[GoogleCSE] Unexpected error: $e');
      return [];
    }
  }
}
