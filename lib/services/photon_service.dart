import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:wanderwell/models/place_suggestion.dart';
import 'package:wanderwell/core/network/dio_client.dart';

/// Service to fetch place autocomplete suggestions from Photon (Komoot) API.
/// Public endpoint, no API key required.
class PhotonService {
  static final PhotonService _instance = PhotonService._internal();
  factory PhotonService() => _instance;
  PhotonService._internal();

  static const String _baseUrl = 'https://photon.komoot.io/api/';

  // In-memory cache with short TTL to speed up repeated queries and cold-starts
  final Map<String, _CacheEntry> _cache = {};
  static const Duration _ttl = Duration(minutes: 10);
  bool _prewarmed = false;

  /// Warm up DNS/TLS and caches with a tiny request. No-op after first call.
  Future<void> prewarm() async {
    if (_prewarmed) return;
    _prewarmed = true;
    try {
      // Use a very short query that will be fast and commonly cached by the API.
      await autocomplete('a', limit: 3, lang: 'en');
    } catch (_) {
      // Ignore warmup failures
    }
  }

  /// Returns up to [limit] suggestions for the [query].
  /// Filters for common administrative/settlement types.
  Future<List<PlaceSuggestion>> autocomplete(String query, {int limit = 8, String lang = 'en'}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final cacheKey = '$lang::$limit::$q'.toLowerCase();
    final now = DateTime.now();
    final cached = _cache[cacheKey];
    if (cached != null && now.difference(cached.time) < _ttl) {
      return cached.items;
    }

    try {
      final dio = DioClient.instance;
      final Response resp = await dio.get(_baseUrl, queryParameters: {
        'q': q,
        'lang': lang,
        'limit': '$limit',
      });
      if (resp.statusCode != 200) {
        debugPrint('PhotonService: HTTP ${resp.statusCode}');
        return [];
      }
      final Map<String, dynamic> root;
      final body = resp.data;
      if (body is Map<String, dynamic>) {
        root = body;
      } else if (body is String) {
        root = jsonDecode(body) as Map<String, dynamic>;
      } else {
        root = jsonDecode(jsonEncode(body)) as Map<String, dynamic>;
      }
      final features = (root['features'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];

      final allowed = <String>{
        'city', 'town', 'village', 'hamlet', 'suburb',
        'state', 'region', 'province', 'county', 'district',
        'country', 'island',
      };

      final results = features
          .map(PlaceSuggestion.fromPhotonFeature)
          .where((p) => p.osmValue == null || allowed.contains(p.osmValue))
          .toList();

      // Deduplicate by label
      final seen = <String>{};
      final unique = <PlaceSuggestion>[];
      for (final p in results) {
        final k = p.label.toLowerCase();
        if (!seen.contains(k)) {
          seen.add(k);
          unique.add(p);
        }
      }

      final limited = unique.take(limit).toList();
      _cache[cacheKey] = _CacheEntry(time: DateTime.now(), items: limited);
      return limited;
    } catch (e) {
      debugPrint('PhotonService error: $e');
      return [];
    }
  }
}

class _CacheEntry {
  final DateTime time;
  final List<PlaceSuggestion> items;
  _CacheEntry({required this.time, required this.items});
}
