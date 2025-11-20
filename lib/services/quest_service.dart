import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:wanderwell/models/quest_models.dart';
import 'package:wanderwell/services/location_service.dart';
import 'package:wanderwell/utils/app_utils.dart';

enum QuestEntryType { quest, microAdventure }

class QuestService {
  QuestService._();
  static final QuestService _instance = QuestService._();
  factory QuestService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fba.FirebaseAuth _auth = fba.FirebaseAuth.instance;

  /// Returns today's quests, generating and persisting if missing or for a new day.
  Future<DailyQuests?> getOrCreateToday() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[QuestService] No user signed in');
      return null;
    }
    final key = AppUtils.todayKey();
    final docRef = _db.collection('users').doc(user.uid).collection('daily').doc(key);
    try {
      final snap = await docRef.get();
      if (snap.exists) {
        final data = snap.data()!;
        try {
          return DailyQuests.fromJson(data);
        } catch (e) {
          debugPrint('[QuestService] Corrupted daily data, regenerating: $e');
          // fall through to regenerate
        }
      }

      DailyQuests generated;
      try {
        generated = await _generateDailyAI();
      } catch (e, st) {
        debugPrint('[QuestService] _generateDailyAI failed, falling back. $e');
        debugPrint('$st');
        generated = await _generateDaily();
      }
      await docRef.set(generated.toJson());
      return generated;
    } catch (e, st) {
      debugPrint('[QuestService] getOrCreateToday error: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Resets only the quest portion for today.
  Future<DailyQuests?> resetQuest() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final key = AppUtils.todayKey();
    final docRef = _db.collection('users').doc(user.uid).collection('daily').doc(key);
    try {
      // Read current to avoid repeat
      final existingSnap = await docRef.get();
      String? prevTitle;
      if (existingSnap.exists) {
        final data = existingSnap.data();
        if (data != null && data['quest'] is Map<String, dynamic>) {
          prevTitle = ((data['quest'] as Map<String, dynamic>)['title'] ?? '').toString();
        }
      }

      QuestOfTheMoment newQuest;
      try {
        newQuest = await _generateQuestAI(avoidTitle: prevTitle);
      } catch (e, st) {
        debugPrint('[QuestService] _generateQuestAI failed, falling back. $e');
        debugPrint('$st');
        final titleContext = await _locationLabel();
        newQuest = _generateQuestAvoiding(titleContext, avoidTitle: prevTitle);
      }
      await docRef.set({'quest': newQuest.toJson(), 'dateKey': key, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      final snap = await docRef.get();
      return DailyQuests.fromJson(snap.data()!..putIfAbsent('microAdventure', () => {}));
    } catch (e, st) {
      debugPrint('[QuestService] resetQuest error: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Resets only the micro adventure for today.
  Future<DailyQuests?> resetMicroAdventure() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final key = AppUtils.todayKey();
    final docRef = _db.collection('users').doc(user.uid).collection('daily').doc(key);
    try {
      // Read current to avoid repeat
      final existingSnap = await docRef.get();
      String? prevTitle;
      if (existingSnap.exists) {
        final data = existingSnap.data();
        if (data != null && data['microAdventure'] is Map<String, dynamic>) {
          prevTitle = ((data['microAdventure'] as Map<String, dynamic>)['title'] ?? '').toString();
        }
      }

      MicroAdventure newMicro;
      try {
        newMicro = await _generateMicroAI(avoidTitle: prevTitle);
      } catch (e, st) {
        debugPrint('[QuestService] _generateMicroAI failed, falling back. $e');
        debugPrint('$st');
        final titleContext = await _locationLabel();
        newMicro = _generateMicroAdventureAvoiding(titleContext, avoidTitle: prevTitle);
      }
      await docRef.set({'microAdventure': newMicro.toJson(), 'dateKey': key, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      final snap = await docRef.get();
      return DailyQuests.fromJson(snap.data()!..putIfAbsent('quest', () => {}));
    } catch (e, st) {
      debugPrint('[QuestService] resetMicroAdventure error: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Marks either quest or micro adventure completed and persists a copy to completedQuests.
  Future<void> markCompleted(QuestEntryType type, DailyQuests current) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final key = AppUtils.todayKey();
    final userRef = _db.collection('users').doc(user.uid);
    final dailyRef = userRef.collection('daily').doc(key);
    final now = DateTime.now();
    try {
      if (type == QuestEntryType.quest) {
        await dailyRef.set({
          'quest': current.quest.copyWith(completed: true, completedAt: now).toJson(),
        }, SetOptions(merge: true));
        await userRef.collection('completedQuests').add({
          'type': 'quest',
          'dateKey': key,
          'createdAt': Timestamp.fromDate(now),
          'payload': current.quest.toJson(),
        });
      } else {
        await dailyRef.set({
          'microAdventure': current.microAdventure.copyWith(completed: true, completedAt: now).toJson(),
        }, SetOptions(merge: true));
        await userRef.collection('completedQuests').add({
          'type': 'microAdventure',
          'dateKey': key,
          'createdAt': Timestamp.fromDate(now),
          'payload': current.microAdventure.toJson(),
        });
      }
    } catch (e, st) {
      debugPrint('[QuestService] markCompleted error: $e');
      debugPrint('$st');
    }
  }

  /// Undo completion for today (sets completed=false and clears completedAt).
  Future<void> markUncompleted(QuestEntryType type) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final key = AppUtils.todayKey();
    final userRef = _db.collection('users').doc(user.uid);
    final dailyRef = userRef.collection('daily').doc(key);
    try {
      if (type == QuestEntryType.quest) {
        await dailyRef.set({
          'quest': {
            'completed': false,
            'completedAt': null,
          }
        }, SetOptions(merge: true));
      } else {
        await dailyRef.set({
          'microAdventure': {
            'completed': false,
            'completedAt': null,
          }
        }, SetOptions(merge: true));
      }
    } catch (e, st) {
      debugPrint('[QuestService] markUncompleted error: $e');
      debugPrint('$st');
    }
  }

  /// Count of completed items by type.
  Future<int> completedCount(QuestEntryType type) async {
    final user = _auth.currentUser;
    if (user == null) return 0;
    try {
      final qs = await _db
          .collection('users')
          .doc(user.uid)
          .collection('completedQuests')
          .where('type', isEqualTo: type == QuestEntryType.quest ? 'quest' : 'microAdventure')
          .get();
      return qs.size;
    } catch (e) {
      debugPrint('[QuestService] completedCount error: $e');
      return 0;
    }
  }

  // ----- Generation helpers (non-AI, contextual to location + light randomness) -----
  Future<String> _locationLabel() async {
    try {
      final loc = await LocationService().getCurrentLocationWithName();
      return loc?.name ?? 'your area';
    } catch (_) {
      return 'your area';
    }
  }

  // ----- Gemini (firebase_ai) powered generation -----
  static const String _modelName = 'gemini-2.5-flash';

  Future<DailyQuests> _generateDailyAI() async {
    final nowKey = AppUtils.todayKey();
    final loc = await LocationService().getCurrentLocationWithName();
    final place = loc?.name ?? 'your area';
    final lat = loc?.lat;
    final lon = loc?.lon;

    final model = FirebaseAI.googleAI().generativeModel(model: _modelName);
    final prompt = _buildDailyPrompt(place: place, lat: lat, lon: lon);
    final resp = await model.generateContent(
      [Content.text(prompt)],
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.7,
      ),
    );

    final text = resp.text;
    if (text == null || text.trim().isEmpty) {
      throw Exception('Empty response from model');
    }
    final extracted = _extractFirstJsonObject(text);
    final cleaned = _sanitizeJson(extracted);
    final decoded = jsonDecode(cleaned) as Map<String, dynamic>;

    final questJson = (decoded['quest'] ?? {}) as Map<String, dynamic>;
    final microJson = (decoded['microAdventure'] ?? {}) as Map<String, dynamic>;
    final quest = _questFromLLM(questJson, fallbackPlace: place);
    final micro = _microFromLLM(microJson, fallbackPlace: place);

    return DailyQuests(
      dateKey: nowKey,
      quest: quest,
      microAdventure: micro,
      createdAt: DateTime.now(),
    );
  }

  Future<QuestOfTheMoment> _generateQuestAI({String? avoidTitle}) async {
    final loc = await LocationService().getCurrentLocationWithName();
    final place = loc?.name ?? 'your area';
    final lat = loc?.lat;
    final lon = loc?.lon;
    final model = FirebaseAI.googleAI().generativeModel(model: _modelName);
    final prompt = _buildQuestOnlyPrompt(place: place, lat: lat, lon: lon, avoidTitle: avoidTitle);
    // Up to 3 attempts to avoid repeating titles
    for (int attempt = 0; attempt < 3; attempt++) {
      final resp = await model.generateContent(
        [Content.text(prompt)],
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.8,
        ),
      );
      final text = resp.text;
      if (text == null || text.trim().isEmpty) {
        throw Exception('Empty response');
      }
      final extracted = _extractFirstJsonObject(text);
      final cleaned = _sanitizeJson(extracted);
      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      final candidate = _questFromLLM(decoded, fallbackPlace: place);
      if (avoidTitle == null || !_isSimilarTitle(candidate.title, avoidTitle)) {
        return candidate;
      }
      debugPrint('[QuestService] AI quest duplicate detected, retrying (attempt ${attempt + 1})');
    }
    // Last resort: fallback local generator with avoidance
    final titleContext = await _locationLabel();
    return _generateQuestAvoiding(titleContext, avoidTitle: avoidTitle);
  }

  Future<MicroAdventure> _generateMicroAI({String? avoidTitle}) async {
    final loc = await LocationService().getCurrentLocationWithName();
    final place = loc?.name ?? 'your area';
    final lat = loc?.lat;
    final lon = loc?.lon;
    final model = FirebaseAI.googleAI().generativeModel(model: _modelName);
    final prompt = _buildMicroOnlyPrompt(place: place, lat: lat, lon: lon, avoidTitle: avoidTitle);
    for (int attempt = 0; attempt < 3; attempt++) {
      final resp = await model.generateContent(
        [Content.text(prompt)],
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.9,
        ),
      );
      final text = resp.text;
      if (text == null || text.trim().isEmpty) {
        throw Exception('Empty response');
      }
      final extracted = _extractFirstJsonObject(text);
      final cleaned = _sanitizeJson(extracted);
      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      final candidate = _microFromLLM(decoded, fallbackPlace: place);
      if (avoidTitle == null || !_isSimilarTitle(candidate.title, avoidTitle)) {
        return candidate;
      }
      debugPrint('[QuestService] AI micro duplicate detected, retrying (attempt ${attempt + 1})');
    }
    final titleContext = await _locationLabel();
    return _generateMicroAdventureAvoiding(titleContext, avoidTitle: avoidTitle);
  }

  String _buildDailyPrompt({required String place, double? lat, double? lon}) {
    final locLine = (lat != null && lon != null) ? '($lat,$lon)' : '';
    return '''
System instruction: You are a mindful, safety-conscious local guide. Output ONLY a JSON object with this schema and nothing else.

User request: Create a location-personalized daily quest and a 1-hour micro adventure for today in "$place" $locLine.

JSON schema to output exactly:
{
  "quest": {
    "title": string,               // action + local hook, short
    "steps": [string, string, string], // 3 concise, actionable steps
    "reflectionPrompt": string     // 1 short reflective question
  },
  "microAdventure": {
    "title": string,               // enticing, specific to $place
    "description": string          // 2-3 sentences, safe and doable within 1 hour
  }
}

Rules:
- Personalize to local neighborhoods or landmarks in $place; avoid hallucinating obscure spots.
- Keep all strings concise, friendly, and in English. No emojis, no markdown.
- Avoid imperative chains like "Option 1/2"; provide a single clear plan.
''';
  }

  String _buildQuestOnlyPrompt({required String place, double? lat, double? lon, String? avoidTitle}) {
    final locLine = (lat != null && lon != null) ? '($lat,$lon)' : '';
    final avoid = (avoidTitle == null || avoidTitle.trim().isEmpty) ? '' : '\nAvoid repeating, paraphrasing, or using the same landmark/theme as: "$avoidTitle". Choose a different local hook.';
    return '''
System instruction: Output ONLY JSON for a single quest object.
User request: Generate a concise, location-aware quest in "$place" $locLine.
Schema:
{
  "title": string,
  "steps": [string, string, string],
  "reflectionPrompt": string
}
Rules: personalize to $place; keep steps actionable and short; no extra fields.$avoid
''';
  }

  String _buildMicroOnlyPrompt({required String place, double? lat, double? lon, String? avoidTitle}) {
    final locLine = (lat != null && lon != null) ? '($lat,$lon)' : '';
    final avoid = (avoidTitle == null || avoidTitle.trim().isEmpty) ? '' : '\nAvoid repeating, paraphrasing, or using the same landmark/theme as: "$avoidTitle". Use a different angle or area.';
    return '''
System instruction: Output ONLY JSON for a micro adventure object.
User request: Create a 1-hour micro adventure suitable for today in "$place" $locLine.
Schema:
{
  "title": string,
  "description": string
}
Rules: should be feasible within 60 minutes, low-cost or free, and safe. No extra keys.$avoid
''';
  }

  QuestOfTheMoment _questFromLLM(Map<String, dynamic> json, {required String fallbackPlace}) {
    final title = (json['title'] ?? '').toString().trim();
    List<String> steps = (json['steps'] as List?)?.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList() ?? const <String>[];
    if (steps.length > 3) {
      steps = steps.take(3).toList();
    }
    if (steps.length < 2) {
      // Ensure UI has at least 2 items; add simple filler if needed
      while (steps.length < 2) {
        steps.add('Spend 10 minutes observing your surroundings.');
      }
    }
    final reflection = (json['reflectionPrompt'] ?? 'What surprised you today in $fallbackPlace?').toString().trim();
    final t = title.isEmpty ? 'Explore a corner of $fallbackPlace' : title;
    return QuestOfTheMoment(title: t, steps: steps, reflectionPrompt: reflection);
  }

  MicroAdventure _microFromLLM(Map<String, dynamic> json, {required String fallbackPlace}) {
    final title = (json['title'] ?? '').toString().trim();
    final desc = (json['description'] ?? '').toString().trim();
    final t = title.isEmpty ? 'Golden Hour Walk' : title;
    final d = desc.isEmpty ? 'Walk for 60 minutes in $fallbackPlace during golden hour. Notice colors, sounds, and textures.' : desc;
    return MicroAdventure(title: t, description: d);
  }

  // Shared minimal JSON cleaning similar to ItineraryAIService
  String _extractFirstJsonObject(String raw) {
    final s = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return s;
    return s.substring(start, end + 1);
  }

  String _sanitizeJson(String input) {
    var out = input;
    out = out.replaceAll(RegExp(r"//.*"), '');
    out = out
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('’', "'");
    out = out.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
    out = utf8.decode(utf8.encode(out));
    return out.trim();
  }

  Future<DailyQuests> _generateDaily() async {
    final context = await _locationLabel();
    return DailyQuests(
      dateKey: AppUtils.todayKey(),
      quest: _generateQuest(context),
      microAdventure: _generateMicroAdventure(context),
      createdAt: DateTime.now(),
    );
  }

  QuestOfTheMoment _generateQuest(String contextLabel) {
    final rng = Random();
    final verbs = [
      'Discover',
      'Wander through',
      'Capture',
      'Taste',
      'Learn about',
      'Slow down in',
    ];
    final focuses = [
      'a historic corner of',
      'a hidden street in',
      'a vibrant market of',
      'a quiet park in',
      'a neighborhood café scene of',
      'the riverfront of',
    ];
    final verb = verbs[rng.nextInt(verbs.length)];
    final focus = focuses[rng.nextInt(focuses.length)];
    final title = '$verb $focus $contextLabel';

    final stepsBank = <List<String>>[
      [
        'Walk 15 minutes without a destination — follow what looks inviting.',
        'Take 3 photos that capture textures or patterns you notice.',
        'Ask a local for one recommendation you wouldn’t find online.',
      ],
      [
        'Find a small café; order something you’ve never tried before.',
        'Write 3 sentences about how the place makes you feel.',
        'Leave a kind note or compliment for the staff.',
      ],
      [
        'Pick a building; sketch its outline in 5 minutes.',
        'Find a viewpoint; sit and observe the flow for 10 minutes.',
        'Say hello to someone and learn one fact about the area.',
      ],
    ];
    final steps = stepsBank[rng.nextInt(stepsBank.length)];
    final reflection = 'What surprised you most today in $contextLabel, and why?';

    return QuestOfTheMoment(title: title, steps: steps, reflectionPrompt: reflection);
  }

  QuestOfTheMoment _generateQuestAvoiding(String contextLabel, {String? avoidTitle}) {
    for (int i = 0; i < 5; i++) {
      final q = _generateQuest(contextLabel);
      if (avoidTitle == null || !_isSimilarTitle(q.title, avoidTitle)) return q;
    }
    return _generateQuest(contextLabel);
  }

  MicroAdventure _generateMicroAdventure(String contextLabel) {
    final rng = Random();
    final titles = [
      'Golden Hour Photo Walk',
      'One-Street Food Crawl',
      'Park Bench Mindfulness',
      'Local Artisan Hunt',
      'Rooftop Sunset Finder',
    ];
    final descs = [
      'Spend one hour exploring a single street in $contextLabel. Try one snack, note one smell, and find one colorful doorway.',
      'Pick a small park in $contextLabel. Sit for 20 minutes, journal for 10, then stroll slowly for the rest.',
      'Search for an artisan shop or market in $contextLabel. Talk to a maker and learn how one item is made.',
      'During golden hour, walk toward the warmest light in $contextLabel. Take 5 photos from low and high angles.',
      'Find a viewpoint in $contextLabel. Observe changing light and write a 5-line reflection.',
    ];
    final i = rng.nextInt(titles.length);
    return MicroAdventure(title: titles[i], description: descs[i]);
  }

  MicroAdventure _generateMicroAdventureAvoiding(String contextLabel, {String? avoidTitle}) {
    for (int i = 0; i < 5; i++) {
      final m = _generateMicroAdventure(contextLabel);
      if (avoidTitle == null || !_isSimilarTitle(m.title, avoidTitle)) return m;
    }
    return _generateMicroAdventure(contextLabel);
  }

  bool _isSimilarTitle(String a, String b) {
    final na = _normalize(a);
    final nb = _normalize(b);
    if (na == nb) return true;
    if (na.isEmpty || nb.isEmpty) return false;
    if (na.contains(nb) || nb.contains(na)) return true;
    final ta = na.split(' ').where((e) => e.length > 2).toSet();
    final tb = nb.split(' ').where((e) => e.length > 2).toSet();
    if (ta.isEmpty || tb.isEmpty) return false;
    final inter = ta.intersection(tb).length;
    final denom = (ta.length + tb.length - inter).clamp(1, 999);
    final jaccard = inter / denom;
    return jaccard >= 0.6; // high overlap considered similar
  }

  String _normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}
