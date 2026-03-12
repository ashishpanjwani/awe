import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:wanderwell/models/quest_models.dart';
import 'package:wanderwell/services/location_service.dart';
import 'package:wanderwell/services/weather_service.dart';
import 'package:wanderwell/utils/app_utils.dart';

enum QuestEntryType { quest, microAdventure }

// 🎯 NEW: Private class to hold all necessary context, fetched efficiently in parallel
class _DailyContext {
  final String place;
  final double? lat;
  final double? lon;
  final String season;
  final String dayPart;
  final bool isWeekend;
  final String? weather;

  _DailyContext({
    required this.place,
    this.lat,
    this.lon,
    required this.season,
    required this.dayPart,
    required this.isWeekend,
    this.weather,
  });

  // 🎯 LATENCY FIX: Static method to fetch all context I/O in parallel
  static Future<_DailyContext> fetch() async {
    final now = DateTime.now();

    // 1. Start Location fetch immediately
    final locFuture = LocationService().getCurrentLocationWithName(allowIpFallback: false);
    
    // Wait for Location to get coordinates
    final loc = await locFuture;
    
    final place = loc?.name ?? 'your area';
    final lat = loc?.lat;
    final lon = loc?.lon;

    // 2. Start Weather fetch (which must follow location)
    String? weather;
    if (lat != null && lon != null) {
      try {
        final w = await WeatherService().fetchWeatherAt(lat, lon, cityName: place);
        weather = w.condition; 
      } catch (_) {
        // Ignore weather on failure
      }
    }

    // 3. Compute time context synchronously (which is fast)
    final season = QuestService._seasonForStatic(now, lat: lat);
    final dayPart = QuestService._dayPeriodStatic(now);
    final isWeekend = (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday);

    return _DailyContext(
      place: place,
      lat: lat,
      lon: lon,
      season: season,
      dayPart: dayPart,
      isWeekend: isWeekend,
      weather: weather,
    );
  }
}

class QuestService {
  QuestService._();
  static final QuestService _instance = QuestService._();
  factory QuestService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fba.FirebaseAuth _auth = fba.FirebaseAuth.instance;

  // Using the user's requested model, optimized for speed.
  static const String _modelName = 'gemini-2.5-flash-lite'; 

  /// Returns today's quests, generating and persisting if missing or for a new day.
  Future<DailyQuests?> getOrCreateToday() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[QuestService] No user signed in');
      return null;
    }
    final key = AppUtils.todayKey();
    final docRef =
        _db.collection('users').doc(user.uid).collection('daily').doc(key);
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
        // Fetch context once for the generation attempt
        final context = await _DailyContext.fetch(); 
        generated = await _generateDailyAI(context: context); 
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
    final docRef =
        _db.collection('users').doc(user.uid).collection('daily').doc(key);
    try {
      // Read current to avoid repeat
      final existingSnap = await docRef.get();
      String? prevTitle;
      if (existingSnap.exists) {
        final data = existingSnap.data();
        if (data != null && data['quest'] is Map<String, dynamic>) {
          prevTitle = ((data['quest'] as Map<String, dynamic>)['title'] ?? '')
              .toString();
        }
      }

      // 🎯 OPTIMIZATION: Fetch context before AI call
      final context = await _DailyContext.fetch();

      QuestOfTheMoment newQuest;
      try {
        newQuest = await _generateQuestAI(context: context, avoidTitle: prevTitle);
      } catch (e, st) {
        debugPrint('[QuestService] _generateQuestAI failed, falling back. $e');
        debugPrint('$st');
        final titleContext = context.place; // Use fetched context
        newQuest = _generateQuestAvoiding(titleContext, avoidTitle: prevTitle);
      }
      await docRef.set({
        'quest': newQuest.toJson(),
        'dateKey': key,
        'updatedAt': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));
      final snap = await docRef.get();
      return DailyQuests.fromJson(
          snap.data()!..putIfAbsent('microAdventure', () => {}));
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
    final docRef =
        _db.collection('users').doc(user.uid).collection('daily').doc(key);
    try {
      // Read current to avoid repeat
      final existingSnap = await docRef.get();
      String? prevTitle;
      if (existingSnap.exists) {
        final data = existingSnap.data();
        if (data != null && data['microAdventure'] is Map<String, dynamic>) {
          prevTitle =
              ((data['microAdventure'] as Map<String, dynamic>)['title'] ?? '')
                  .toString();
        }
      }

      // 🎯 OPTIMIZATION: Fetch context before AI call
      final context = await _DailyContext.fetch();

      MicroAdventure newMicro;
      try {
        newMicro = await _generateMicroAI(context: context, avoidTitle: prevTitle);
      } catch (e, st) {
        debugPrint('[QuestService] _generateMicroAI failed, falling back. $e');
        debugPrint('$st');
        final titleContext = context.place; // Use fetched context
        newMicro = _generateMicroAdventureAvoiding(titleContext,
            avoidTitle: prevTitle);
      }
      await docRef.set({
        'microAdventure': newMicro.toJson(),
        'dateKey': key,
        'updatedAt': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));
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
          'quest': current.quest
              .copyWith(completed: true, completedAt: now)
              .toJson(),
        }, SetOptions(merge: true));
        await userRef.collection('completedQuests').add({
          'type': 'quest',
          'dateKey': key,
          'createdAt': Timestamp.fromDate(now),
          'payload': current.quest.toJson(),
        });
      } else {
        await dailyRef.set({
          'microAdventure': current.microAdventure
              .copyWith(completed: true, completedAt: now)
              .toJson(),
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
          .where('type',
              isEqualTo:
                  type == QuestEntryType.quest ? 'quest' : 'microAdventure')
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
      final loc = await LocationService()
          .getCurrentLocationWithName(allowIpFallback: false);
      return loc?.name ?? 'your area';
    } catch (_) {
      return 'your area';
    }
  }

  // ----- Gemini (firebase_ai) powered generation -----

  Future<DailyQuests> _generateDailyAI({required _DailyContext context}) async {
    final nowKey = AppUtils.todayKey();
    
    print('Place: ${context.place} ${context.lat} ${context.lon}');

    final model = FirebaseAI.googleAI().generativeModel(model: _modelName);
    
    // Pass the context object to the prompt builder
    final prompt = _buildDailyPrompt(context: context); 
    
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
    final quest = _questFromLLM(questJson, fallbackPlace: context.place);
    final micro = _microFromLLM(microJson, fallbackPlace: context.place);

    return DailyQuests(
      dateKey: nowKey,
      quest: quest,
      microAdventure: micro,
      createdAt: DateTime.now(),
    );
  }

  Future<QuestOfTheMoment> _generateQuestAI({required _DailyContext context, String? avoidTitle}) async {
    print('Place: ${context.place} ${context.lat} ${context.lon}');

    final model = FirebaseAI.googleAI().generativeModel(model: _modelName);
    final prompt = _buildQuestOnlyPrompt(
      context: context,
      avoidTitle: avoidTitle,
    );
    
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
      final candidate = _questFromLLM(decoded, fallbackPlace: context.place);
      if (avoidTitle == null || !_isSimilarTitle(candidate.title, avoidTitle)) {
        return candidate;
      }
      debugPrint(
          '[QuestService] AI quest duplicate detected, retrying (attempt ${attempt + 1})');
    }
    // Last resort: fallback local generator with avoidance
    final titleContext = await _locationLabel();
    return _generateQuestAvoiding(titleContext, avoidTitle: avoidTitle);
  }

  Future<MicroAdventure> _generateMicroAI({required _DailyContext context, String? avoidTitle}) async {
    print('Place: ${context.place} ${context.lat} ${context.lon}');

    final model = FirebaseAI.googleAI().generativeModel(model: _modelName);
    final prompt = _buildMicroOnlyPrompt(
      context: context,
      avoidTitle: avoidTitle,
    );
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
      final candidate = _microFromLLM(decoded, fallbackPlace: context.place);
      if (avoidTitle == null || !_isSimilarTitle(candidate.title, avoidTitle)) {
        return candidate;
      }
      debugPrint(
          '[QuestService] AI micro duplicate detected, retrying (attempt ${attempt + 1})');
    }
    final titleContext = await _locationLabel();
    return _generateMicroAdventureAvoiding(titleContext,
        avoidTitle: avoidTitle);
  }

  // 🎯 REFINED PROMPT: Pushes for concrete experiential activities
  String _buildDailyPrompt({required _DailyContext context}) {
    final locLine = (context.lat != null && context.lon != null) ? 
        '(${context.lat!.toStringAsFixed(2)},${context.lon!.toStringAsFixed(2)})' : '';
    
    final contextLine = 'Context: season=' +
        context.season +
        '; time=' +
        context.dayPart +
        '; ' +
        (context.isWeekend ? 'weekend' : 'weekday') +
        (context.weather != null ? '; weather=' + context.weather! : '') +
        '.';
        
    // 🎯 NEW INSTRUCTION FOR AUTHENTICITY AND EXPERIENCE
    final personalizationInstruction = '''
    Personalization Rule: Use the location and coordinates to imagine a realistic local setting (e.g., typical architecture style, common regional activities, typical terrain like 'hilly neighborhood' or 'coastal trail'). Do NOT invent proper names. The "Experience Quest" MUST suggest a concrete, local activity type (e.g., a specific dish cooking class, a regional hiking trail, a local craft workshop) feasible today.
    ''';

    return '''
System instruction: You are a mindful, safety-conscious local guide. Output ONLY a JSON object with this schema and nothing else.

User request: In "${context.place}" $locLine. $contextLine Create a location-personalized daily quest (observation/reflection) and a distinct 1-hour **Experiential Quest** for today.

$personalizationInstruction

JSON schema to output exactly:
{
  "quest": {
    "title": string,               // one concrete local hook (e.g., riverfront, market street, old town)
    "steps": [string, string, string], // 3 short, actionable steps with subtle specifics (observation/mindfulness)
    "reflectionPrompt": string     // 1 concise reflective question
  },
  "microAdventure": { // NOTE: This field is now used for the Experiential Quest
    "title": string,               // enticing, MUST name a concrete experience type (e.g., 'Learn Tuscan Pasta', 'Forest Birding')
    "description": string          // exactly 2 sentences; describes the experience type and general location (e.g., 'Find a small pottery studio near the central square. Spend 60 minutes observing the craft or asking about beginner workshops.')
  }
}

Rules:
- Personalize with realistic, generic anchors (e.g., riverfront, main square, neighborhood park) based on what the area likely offers.
- **The 'quest' (observation) and 'microAdventure' (experience) must be completely distinct in theme.**
- The 'microAdventure' MUST suggest a tangible **activity type** (e.g., cooking, hiking, crafting, viewing art, watching a regional film, etc.) and NOT just wandering.
- Be practical for ${context.dayPart} and ${context.isWeekend ? 'weekend' : 'weekday'}${context.weather != null ? ' in ' + context.weather!.toLowerCase() : ''}; adapt to ${context.season}.
- Keep language concise, friendly, and in English. No emojis, no markdown.
''';
  }

  // 🎯 REFINED PROMPT: Pushes for concrete experiential activities
  String _buildQuestOnlyPrompt({required _DailyContext context, String? avoidTitle}) {
    final locLine = (context.lat != null && context.lon != null) ? 
        '(${context.lat!.toStringAsFixed(2)},${context.lon!.toStringAsFixed(2)})' : '';
    final avoid = (avoidTitle == null || avoidTitle.trim().isEmpty)
        ? ''
        : '\nAvoid repeating, paraphrasing, or using the same landmark/theme as: "$avoidTitle". Choose a different local hook.';
    final wx = context.weather != null ? '; weather=${context.weather}' : '';
    final personalizationInstruction = 'Use location/coordinates to imagine a realistic local setting (e.g., architecture, terrain).';

    return '''
System instruction: Output ONLY JSON for a single quest object.
User request: "${context.place}" $locLine. Context: season=${context.season}; time=${context.dayPart}$wx. Generate a concise, location-aware quest.
$personalizationInstruction
Schema:
{
  "title": string,
  "steps": [string, string, string],
  "reflectionPrompt": string
}
Rules:
- Title must mention one tangible anchor (e.g., riverwalk, central market, old town lane) without inventing exact names.
- Steps are short, do-able, with tiny specifics (e.g., sit 10 min, notice smells). No more than 14 words each.
- Keep it safety-conscious and friendly; English only; no extra fields.$avoid
''';
  }

  // 🎯 REFINED PROMPT: Pushes for concrete experiential activities
  String _buildMicroOnlyPrompt({required _DailyContext context, String? avoidTitle}) {
    final locLine = (context.lat != null && context.lon != null) ? 
        '(${context.lat!.toStringAsFixed(2)},${context.lon!.toStringAsFixed(2)})' : '';
    final avoid = (avoidTitle == null || avoidTitle.trim().isEmpty)
        ? ''
        : '\nAvoid repeating, paraphrasing, or using the same landmark/theme as: "$avoidTitle". Use a different angle or area.';
    final wx = context.weather != null ? '; weather=${context.weather}' : '';
    final personalizationInstruction = 'Use location/coordinates to imagine a realistic, **EXPERIENCE-DRIVEN** local activity type (e.g., regional cuisine cooking, local artisan workshop, city-specific hiking trail).';

    return '''
System instruction: Output ONLY JSON for a micro adventure object.
User request: "${context.place}" $locLine. Context: season=${context.season}; time=${context.dayPart}$wx. Create a 1-hour **EXPERIENCE-DRIVEN** micro adventure for today.
$personalizationInstruction
Schema:
{
  "title": string,
  "description": string
}
Rules:
- The title MUST name a concrete activity type (e.g., "Find a Local Painting Workshop", "Try Regional Street Food").
- Description: Exactly 2 sentences. Start by identifying the type of experience and a generic-but-real location anchor (e.g., "Search for a beginner ceramics class near the historic district..."). The second sentence should outline the goal (e.g., "Spend the hour observing the craft or inquiring about introductory sessions.").
- Feasible in ~60 minutes, low-cost or free (or inquiry about one), safe, and relevant to the time/weather.
- English only; no extra keys.$avoid
''';
  }

  QuestOfTheMoment _questFromLLM(Map<String, dynamic> json,
      {required String fallbackPlace}) {
    final titleRaw = (json['title'] ?? '').toString().trim();
    final title = _tightTitle(
        titleRaw.isEmpty ? 'Explore a corner of $fallbackPlace' : titleRaw);
    List<String> steps = (json['steps'] as List?)
            ?.map((e) => _tightLine(e.toString().trim()))
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    if (steps.length > 3) {
      steps = steps.take(3).toList();
    }
    if (steps.length < 2) {
      // Ensure UI has at least 2 items; add simple filler if needed
      while (steps.length < 2) {
        steps.add('Sit 10 minutes; notice sounds and smells.');
      }
    }
    final reflection = _tightLine((json['reflectionPrompt'] ??
            'What surprised you today in $fallbackPlace?')
        .toString()
        .trim());
    return QuestOfTheMoment(
        title: title, steps: steps, reflectionPrompt: reflection);
  }

  MicroAdventure _microFromLLM(Map<String, dynamic> json,
      {required String fallbackPlace}) {
    final titleRaw = (json['title'] ?? '').toString().trim();
    final descRaw = (json['description'] ?? '').toString().trim();
    final t = _tightTitle(titleRaw.isEmpty ? 'Golden Hour Walk' : titleRaw);
    final d = _trimToTwoSentences(
      descRaw.isEmpty
          ? 'Start at the main square in $fallbackPlace. Stroll for an hour and notice colors, sounds, and textures.'
          : descRaw,
    );
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
    out = out.replaceAll('“', '"').replaceAll('”', '"').replaceAll('’', "'");
    out = out.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
    out = utf8.decode(utf8.encode(out));
    return out.trim();
  }

  // ---------- Compacting utilities to improve authenticity while staying concise ----------
  String _tightTitle(String s) {
    var t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Drop trailing punctuation in titles
    t = t.replaceAll(RegExp(r'[\.!?]+$'), '');
    // Light de-genericizing of very common openers
    t = t.replaceFirst(
        RegExp(r'^(Explore|Discover|Experience)\b', caseSensitive: false),
        'Stroll');
    return t;
  }

  String _tightLine(String s) {
    var out = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Keep lines short to feel precise
    const max = 120;
    if (out.length > max) {
      out = out.substring(0, max).replaceAll(RegExp(r'[ ,;:]+$'), '').trim();
      out += '…';
    }
    return out;
  }

  String _trimToTwoSentences(String s) {
    final text = s.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final parts = text.split(RegExp(r'(?<=[.!?])\s+'));
    if (parts.length <= 2) return text;
    return parts.take(2).join(' ');
  }

  // 🎯 Renamed to static for use in _DailyContext
  static String _seasonForStatic(DateTime date, {double? lat}) {
    // Northern hemisphere default; flip by 6 months for southern
    var m = date.month;
    if (lat != null && lat < 0) {
      m = ((m + 6 - 1) % 12) + 1; // rotate by 6 months
    }
    if (m >= 3 && m <= 5) return 'Spring';
    if (m >= 6 && m <= 8) return 'Summer';
    if (m >= 9 && m <= 11) return 'Autumn';
    return 'Winter';
  }

  // 🎯 Renamed to static for use in _DailyContext
  static String _dayPeriodStatic(DateTime date) {
    final h = date.hour;
    if (h < 5) return 'pre-dawn';
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    if (h < 21) return 'evening';
    return 'night';
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
    final reflection =
        'What surprised you most today in $contextLabel, and why?';

    return QuestOfTheMoment(
        title: title, steps: steps, reflectionPrompt: reflection);
  }

  QuestOfTheMoment _generateQuestAvoiding(String contextLabel,
      {String? avoidTitle}) {
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

  MicroAdventure _generateMicroAdventureAvoiding(String contextLabel,
      {String? avoidTitle}) {
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

  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}