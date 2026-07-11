import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderwell/models/quest_card.dart';
import 'package:wanderwell/services/foursquare_service.dart';
import 'package:wanderwell/services/google_cse_service.dart';
import 'package:wanderwell/services/local_context_service.dart';

class QuestRagService {
  QuestRagService._();
  static final QuestRagService _instance = QuestRagService._();
  factory QuestRagService() => _instance;

  static const _cacheTtlMs = 6 * 60 * 60 * 1000;

  Future<List<QuestCard>> getQuestsForLocation(String city) async {
    final cacheKey = 'rag_quests_v2_${_normalize(city)}';

    final cached = await _readCache(cacheKey);
    if (cached != null) {
      debugPrint('[QuestRag] Cache hit for "$city" (${cached.length} cards)');
      return cached;
    }

    // Step 1: RETRIEVE from real APIs in parallel
    debugPrint('[QuestRag] Fetching real data for "$city"...');
    final results = await Future.wait([
      FoursquareService().fetchAllForCity(city),
      LocalContextService().fetchLocalBuzz(city: city),
      GoogleCseService().searchInstagram(city),
    ]);

    final foursquare = results[0] as FoursquareQuestData;
    final reddit = results[1] as List<LocalBuzzItem>;
    final instagram = results[2] as List<CseResult>;

    debugPrint('[QuestRag] Data: ${foursquare.totalCount} foursquare, '
        '${reddit.length} reddit, ${instagram.length} instagram');

    // Step 2: Build cards from real data
    final cards = <QuestCard>[];

    // Trending — from Foursquare trending + Instagram
    for (final v in foursquare.trending.take(2)) {
      cards.add(_venueToCard(v, 'trending', 'Popular right now'));
    }
    for (final post in instagram.take(2)) {
      cards.add(QuestCard(
        type: 'trending',
        title: _cleanTitle(post.title),
        description: post.snippet,
        source: 'Instagram',
        actionUrl: post.url,
      ));
    }

    // Food — from Foursquare
    for (final v in foursquare.food) {
      cards.add(_venueToCard(v, 'food', _foodSource(v)));
    }

    // Places — from Foursquare
    for (final v in foursquare.attractions) {
      cards.add(_venueToCard(v, 'place', 'Popular landmark'));
    }

    // Experiences — from Foursquare
    for (final v in foursquare.experiences.take(3)) {
      cards.add(_venueToCard(v, 'experience', 'Recommended'));
    }

    // Reddit buzz items (if not already covered)
    final existingTitles = cards.map((c) => c.title.toLowerCase()).toSet();
    for (final buzz in reddit.take(3)) {
      if (existingTitles.contains(buzz.title.toLowerCase())) continue;
      cards.add(QuestCard(
        type: 'trending',
        title: buzz.title,
        description: buzz.snippet ?? '',
        source: 'Reddit',
        actionUrl: 'https://www.google.com/search?q=${Uri.encodeComponent('${buzz.title} $city')}',
      ));
    }

    // Deduplicate by name similarity
    final deduped = _deduplicate(cards);

    // Interleave types for nice ordering
    final ordered = _interleave(deduped);

    // Step 3: Use Gemini ONLY to polish descriptions (optional, graceful skip)
    final polished = await _polishDescriptions(ordered, city);

    debugPrint('[QuestRag] Final: ${polished.length} cards for "$city"');
    await _writeCache(cacheKey, polished);
    return polished;
  }

  QuestCard _venueToCard(FoursquareVenue v, String type, String source) {
    final ratingStr = v.rating != null ? ' (${v.rating}/10)' : '';
    return QuestCard(
      type: type,
      title: v.name,
      description: '${v.category}${v.neighborhood != null ? ' in ${v.neighborhood}' : ''}$ratingStr',
      location: v.neighborhood,
      source: source,
      actionUrl: v.mapsUrl,
    );
  }

  String _foodSource(FoursquareVenue v) {
    if (v.rating != null && v.rating! >= 8.0) return 'Top-rated (${v.rating}/10)';
    if (v.rating != null) return 'Rated ${v.rating}/10';
    return 'Well-reviewed';
  }

  String _cleanTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'\s*[-|]\s*Instagram.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(@\w+\)'), '')
        .replaceAll(RegExp(r'on Instagram:.*'), '')
        .trim();
  }

  List<QuestCard> _deduplicate(List<QuestCard> cards) {
    final seen = <String>{};
    final result = <QuestCard>[];
    for (final card in cards) {
      final key = card.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (key.length < 3 || seen.contains(key)) continue;
      seen.add(key);
      result.add(card);
    }
    return result;
  }

  List<QuestCard> _interleave(List<QuestCard> cards) {
    final trending = cards.where((c) => c.type == 'trending').toList();
    final food = cards.where((c) => c.type == 'food').toList();
    final places = cards.where((c) => c.type == 'place').toList();
    final experiences = cards.where((c) => c.type == 'experience').toList();

    final result = <QuestCard>[];
    final queues = [trending, food, places, experiences];
    final indices = [0, 0, 0, 0];

    // Trending first
    if (trending.isNotEmpty) {
      result.add(trending[0]);
      indices[0] = 1;
    }

    // Then round-robin through remaining
    var added = true;
    while (added) {
      added = false;
      for (int q = 0; q < queues.length; q++) {
        if (indices[q] < queues[q].length) {
          final card = queues[q][indices[q]];
          if (!result.contains(card)) result.add(card);
          indices[q]++;
          added = true;
        }
      }
    }

    return result;
  }

  /// Gemini ONLY polishes descriptions — never invents places
  Future<List<QuestCard>> _polishDescriptions(List<QuestCard> cards, String city) async {
    if (cards.isEmpty) return cards;

    try {
      final model = FirebaseAI.googleAI().generativeModel(model: 'gemini-3.1-flash-lite');

      final rawData = cards.map((c) => '- ${c.title} (${c.type}, source: ${c.source})').join('\n');

      final prompt = '''
Here are real verified places in "$city". Write a catchy 2-sentence description for each one.
Sentence 1: One specific detail that makes it worth visiting.
Sentence 2: A practical tip (best time to go, what to order, how to get there).

Do NOT add new places. Do NOT change names. Only write descriptions.

Places:
$rawData

Output ONLY this JSON array (same order, same count):
[
  "description for first place",
  "description for second place",
  ...
]
''';

      final resp = await model.generateContent(
        [Content.text(prompt)],
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.5,
        ),
      );

      final text = resp.text;
      if (text == null || text.trim().isEmpty) return cards;

      final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final descriptions = (jsonDecode(cleaned) as List).cast<String>();

      if (descriptions.length != cards.length) {
        debugPrint('[QuestRag] Description count mismatch: ${descriptions.length} vs ${cards.length}');
        return cards;
      }

      return List.generate(cards.length, (i) => QuestCard(
        type: cards[i].type,
        title: cards[i].title,
        description: descriptions[i],
        location: cards[i].location,
        source: cards[i].source,
        actionUrl: cards[i].actionUrl,
      ));
    } catch (e) {
      debugPrint('[QuestRag] Polish failed (using raw descriptions): $e');
      return cards;
    }
  }

  String _normalize(String city) =>
      city.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '_');

  Future<List<QuestCard>?> _readCache(String key) async {
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
          .map((e) => QuestCard.fromJson(e))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String key, List<QuestCard> cards) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode({
          'ts': DateTime.now().millisecondsSinceEpoch,
          'items': cards.map((c) => c.toJson()).toList(),
        }),
      );
    } catch (_) {}
  }
}
