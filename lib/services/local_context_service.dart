import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderwell/core/network/dio_client.dart';
import 'package:wanderwell/models/quest_card.dart';

class LocalBuzzItem {
  final String title;
  final String? snippet;
  final String source; // 'reddit' | 'brave'

  const LocalBuzzItem({
    required this.title,
    this.snippet,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'snippet': snippet,
        'source': source,
      };

  factory LocalBuzzItem.fromJson(Map<String, dynamic> json) => LocalBuzzItem(
        title: json['title'] as String,
        snippet: json['snippet'] as String?,
        source: json['source'] as String,
      );
}

class LocalContextService {
  LocalContextService._();
  static final LocalContextService _instance = LocalContextService._();
  factory LocalContextService() => _instance;

  static const _cacheKeyPrefix = 'local_buzz_';
  static const _cacheTtlMs = 6 * 60 * 60 * 1000; // 6 hours
  static const _maxTotalItems = 10;

  // Cities where the obvious "lowercased city name" subreddit mapping is wrong.
  static const Map<String, String> _knownSubreddits = {
    'new york city': 'nyc',
    'new york': 'nyc',
    'nyc': 'nyc',
    'los angeles': 'losangeles',
    'san francisco': 'sanfrancisco',
    'sf': 'sanfrancisco',
    'washington dc': 'washingtondc',
    'washington d.c.': 'washingtondc',
    'bengaluru': 'bangalore',
    'bombay': 'mumbai',
    'calcutta': 'kolkata',
    'madras': 'chennai',
  };

  /// Fetches local buzz from Reddit + Brave Search, with a 6-hour SharedPreferences cache.
  /// Always returns a list — empty on total failure, never throws.
  Future<List<LocalBuzzItem>> fetchLocalBuzz({required String city}) async {
    final cacheKey = '$_cacheKeyPrefix${_normalizeCity(city)}';

    final cached = await _readCache(cacheKey);
    if (cached != null) {
      debugPrint('[LocalContext] Cache hit for "$city" (${cached.length} items)');
      return cached;
    }

    final results = await Future.wait([
      _fetchReddit(city).catchError((_) => <LocalBuzzItem>[]),
      _fetchSearx(city).catchError((_) => <LocalBuzzItem>[]),
    ]);

    final merged = <LocalBuzzItem>[...results[0], ...results[1]].take(_maxTotalItems).toList();
    debugPrint(
        '[LocalContext] Fetched ${merged.length} items for "$city" '
        '(${results[0].length} reddit, ${results[1].length} searx)');

    await _writeCache(cacheKey, merged);
    return merged;
  }

  // ── Reddit ────────────────────────────────────────────────────────────────

  Future<List<LocalBuzzItem>> _fetchReddit(String city) async {
    final subreddit = _cityToSubreddit(city);
    try {
      final resp = await DioClient.instance.get<Map<String, dynamic>>(
        'https://www.reddit.com/r/$subreddit/hot.json',
        queryParameters: {'limit': 15, 'raw_json': 1},
        options: Options(headers: {'User-Agent': 'wanderwell-app/1.0'}),
      );

      if (resp.statusCode != 200) return [];

      final posts =
          (resp.data?['data']?['children'] as List?) ?? [];

      final items = <LocalBuzzItem>[];
      for (final p in posts) {
        final d = p['data'] as Map<String, dynamic>?;
        if (d == null || d['stickied'] == true) continue;
        final title = (d['title'] as String?)?.trim() ?? '';
        if (title.isEmpty) continue;
        final body = (d['selftext'] as String?)?.trim() ?? '';
        final snippet = body.isNotEmpty
            ? body.substring(0, body.length.clamp(0, 150))
            : null;
        items.add(LocalBuzzItem(title: title, snippet: snippet, source: 'reddit'));
        if (items.length >= 5) break;
      }
      return items;
    } on DioException catch (e) {
      debugPrint('[LocalContext] Reddit failed (r/$subreddit): ${e.message}');
      return [];
    } catch (e) {
      debugPrint('[LocalContext] Reddit unexpected error: $e');
      return [];
    }
  }

  // ── SearXNG Search ─────────────────────────────────────────────────────────

  static const _searxInstances = [
    'https://searx.be',
    'https://search.ononoki.org',
    'https://searx.tiekoetter.com',
  ];

  Future<List<LocalBuzzItem>> _fetchSearx(String city) async {
    try {
      final searches = await Future.wait([
        _searxSearch('site:instagram.com "$city"'),
        _searxSearch('$city things to do this week'),
      ]);
      return [...searches[0], ...searches[1]].take(6).toList();
    } catch (e) {
      debugPrint('[LocalContext] SearXNG fetch error: $e');
      return [];
    }
  }

  Future<List<LocalBuzzItem>> _searxSearch(String query) async {
    for (final instance in _searxInstances) {
      try {
        final resp = await DioClient.instance.get<Map<String, dynamic>>(
          '$instance/search',
          queryParameters: {
            'q': query,
            'format': 'json',
            'language': 'en',
          },
        );

        if (resp.statusCode != 200) continue;

        final results = (resp.data?['results'] as List?) ?? [];
        final items = <LocalBuzzItem>[];
        for (final r in results) {
          final title = (r['title'] as String?)?.trim() ?? '';
          if (title.isEmpty) continue;
          final desc = (r['content'] as String?)?.trim() ?? '';
          final snippet = desc.isNotEmpty
              ? desc.substring(0, desc.length.clamp(0, 150))
              : null;
          items.add(LocalBuzzItem(title: title, snippet: snippet, source: 'web'));
          if (items.length >= 3) break;
        }
        return items;
      } on DioException catch (e) {
        debugPrint('[LocalContext] SearXNG $instance failed: ${e.message}');
        continue;
      }
    }
    return [];
  }

  // ── Quest Data (expanded retrieval for RAG) ──────────────────────────────

  Future<List<RawQuestItem>> fetchQuestData({required String city}) async {
    final cacheKey = 'quests_${_normalizeCity(city)}';

    final cached = await _readQuestCache(cacheKey);
    if (cached != null) {
      debugPrint('[LocalContext] Quest cache hit for "$city" (${cached.length} items)');
      return cached;
    }

    final results = await Future.wait([
      _searxQuestSearch('"$city" must visit places', 'place').catchError((_) => <RawQuestItem>[]),
      _searxQuestSearch('"$city" best food restaurants', 'food').catchError((_) => <RawQuestItem>[]),
      _searxQuestSearch('site:instagram.com "$city" trending', 'trending').catchError((_) => <RawQuestItem>[]),
      _searxQuestSearch('"$city" things to do this week', 'experience').catchError((_) => <RawQuestItem>[]),
      _fetchRedditQuests(city).catchError((_) => <RawQuestItem>[]),
    ]);

    final merged = <RawQuestItem>[];
    for (final list in results) {
      merged.addAll(list);
    }
    debugPrint('[LocalContext] Fetched ${merged.length} quest items for "$city"');

    await _writeQuestCache(cacheKey, merged);
    return merged;
  }

  Future<List<RawQuestItem>> _searxQuestSearch(String query, String categoryHint) async {
    for (final instance in _searxInstances) {
      try {
        final resp = await DioClient.instance.get<Map<String, dynamic>>(
          '$instance/search',
          queryParameters: {'q': query, 'format': 'json', 'language': 'en'},
        );

        if (resp.statusCode != 200) continue;

        final results = (resp.data?['results'] as List?) ?? [];
        final items = <RawQuestItem>[];
        for (final r in results) {
          final title = (r['title'] as String?)?.trim() ?? '';
          if (title.isEmpty) continue;
          final desc = (r['content'] as String?)?.trim() ?? '';
          final url = (r['url'] as String?)?.trim();
          final snippet = desc.isNotEmpty ? desc.substring(0, desc.length.clamp(0, 200)) : null;
          final source = url != null && url.contains('instagram.com') ? 'instagram' : 'web';
          items.add(RawQuestItem(
            title: title,
            snippet: snippet,
            url: url,
            source: source,
            categoryHint: categoryHint,
          ));
          if (items.length >= 4) break;
        }
        return items;
      } on DioException catch (e) {
        debugPrint('[LocalContext] SearXNG quest search $instance failed: ${e.message}');
        continue;
      }
    }
    return [];
  }

  Future<List<RawQuestItem>> _fetchRedditQuests(String city) async {
    final subreddit = _cityToSubreddit(city);
    try {
      final resp = await DioClient.instance.get<Map<String, dynamic>>(
        'https://www.reddit.com/r/$subreddit/hot.json',
        queryParameters: {'limit': 10, 'raw_json': 1},
        options: Options(headers: {'User-Agent': 'wanderwell-app/1.0'}),
      );

      if (resp.statusCode != 200) return [];
      final posts = (resp.data?['data']?['children'] as List?) ?? [];
      final items = <RawQuestItem>[];
      for (final p in posts) {
        final d = p['data'] as Map<String, dynamic>?;
        if (d == null || d['stickied'] == true) continue;
        final title = (d['title'] as String?)?.trim() ?? '';
        if (title.isEmpty) continue;
        final body = (d['selftext'] as String?)?.trim() ?? '';
        final snippet = body.isNotEmpty ? body.substring(0, body.length.clamp(0, 200)) : null;
        final permalink = d['permalink'] as String?;
        final url = permalink != null ? 'https://www.reddit.com$permalink' : null;
        items.add(RawQuestItem(
          title: title,
          snippet: snippet,
          url: url,
          source: 'reddit',
          categoryHint: 'experience',
        ));
        if (items.length >= 5) break;
      }
      return items;
    } catch (e) {
      debugPrint('[LocalContext] Reddit quest fetch failed: $e');
      return [];
    }
  }

  Future<List<RawQuestItem>?> _readQuestCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final ts = map['ts'] as int;
      if (DateTime.now().millisecondsSinceEpoch - ts > _cacheTtlMs) {
        await prefs.remove(key);
        return null;
      }
      return (map['items'] as List)
          .cast<Map<String, dynamic>>()
          .map((e) => RawQuestItem(
                title: (e['title'] as String?) ?? '',
                snippet: e['snippet'] as String?,
                url: e['url'] as String?,
                source: (e['source'] as String?) ?? 'brave',
                categoryHint: e['categoryHint'] as String?,
              ))
          .toList();
    } catch (e) {
      debugPrint('[LocalContext] Quest cache read error: $e');
      return null;
    }
  }

  Future<void> _writeQuestCache(String key, List<RawQuestItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode({
          'ts': DateTime.now().millisecondsSinceEpoch,
          'items': items.map((e) => {
                'title': e.title,
                'snippet': e.snippet,
                'url': e.url,
                'source': e.source,
                'categoryHint': e.categoryHint,
              }).toList(),
        }),
      );
    } catch (e) {
      debugPrint('[LocalContext] Quest cache write error: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _cityToSubreddit(String city) {
    final normalized = city.toLowerCase().trim();
    for (final entry in _knownSubreddits.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    // Default: strip everything except letters and digits
    return normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _normalizeCity(String city) =>
      city.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '_');

  // ── Cache ─────────────────────────────────────────────────────────────────

  Future<List<LocalBuzzItem>?> _readCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      final ts = map['ts'] as int;
      if (DateTime.now().millisecondsSinceEpoch - ts > _cacheTtlMs) {
        await prefs.remove(key);
        return null;
      }

      return (map['items'] as List)
          .map((e) => LocalBuzzItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[LocalContext] Cache read error: $e');
      return null;
    }
  }

  Future<void> _writeCache(String key, List<LocalBuzzItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode({
          'ts': DateTime.now().millisecondsSinceEpoch,
          'items': items.map((e) => e.toJson()).toList(),
        }),
      );
    } catch (e) {
      debugPrint('[LocalContext] Cache write error: $e');
    }
  }
}
