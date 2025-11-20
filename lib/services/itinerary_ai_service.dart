import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

class ItineraryAIService {
  static const String _modelName = 'gemini-2.5-flash';
  static const String _paidBadge = r'$$';

  Future<Map<String, dynamic>> generateItinerary({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required String affordability,
    required List<String> travelStyles,
    required String flexibility,
    int travelers = 2,
    String pace = 'moderate',
    List<String>? mustSee,
    String? dietaryPreference,
  }) async {
    final days = endDate.difference(startDate).inDays + 1;
    final model = FirebaseAI.googleAI().generativeModel(model: _modelName);

    final prompt = _buildPrompt(
      destination: destination,
      startDate: startDate,
      endDate: endDate,
      days: days,
      affordability: affordability,
      travelStyles: travelStyles,
      flexibility: flexibility,
      travelers: travelers,
      pace: pace,
      mustSee: mustSee,
      dietaryPreference: dietaryPreference,
    );

    try {
      final resp = await model.generateContent(
        [Content.text(prompt)],
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0,
        ),
      );
      final text = _safeAggregateText(resp);
      return _decodeTolerantJson(text);
    } catch (e, st) {
      debugPrint('[ItineraryAIService] Generation error: $e');
      debugPrint('[ItineraryAIService] Stack: $st');
      return {
        'destination': destination,
        'startDate': _isoDate(startDate),
        'endDate': _isoDate(endDate),
        'days': <Map<String, dynamic>>[],
        'tips': <String>[],
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> generateItineraryArchitectBuilders({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required String affordability,
    required List<String> travelStyles,
    required String flexibility,
    int travelers = 2,
    String? travelParty, // Solo | Duo | Friends | Family (hints tone/constraints)
    String pace = 'moderate',
    List<String>? mustSee,
    String? dietaryPreference,
    String diversityPreference = 'balanced', // deep_dive | balanced | wide
    void Function(String step)? onProgress,
    int maxParallel = 4,
  }) async {
    final days = endDate.difference(startDate).inDays + 1;
    final model = FirebaseAI.googleAI().generativeModel(model: _modelName);

    void progress(String s) {
      debugPrint('[Architect&Builders] $s');
      onProgress?.call(s);
    }

    try {
      progress('Architect: mapping the route across distinct regions…');
      final archPrompt = _buildArchitectPrompt(
        destination: destination,
        totalDays: days,
        affordability: affordability,
        travelStyles: travelStyles,
        flexibility: flexibility,
        travelers: travelers,
        travelParty: travelParty,
        pace: pace,
        mustSee: mustSee,
        dietaryPreference: dietaryPreference,
        diversityPreference: diversityPreference,
        seasonNote: _seasonNoteFor(destination, startDate, endDate),
      );

      final archResp = await model.generateContent(
        [Content.text(archPrompt)],
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.1,
        ),
      );

      final archText = _safeAggregateText(archResp);
      final archJson = _decodeTolerantJson(archText);
      final segments = (archJson['segments'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          <Map<String, dynamic>>[];
      if (segments.isEmpty) {
        throw Exception('Architect returned no segments');
      }

      final normalized = _normalizeSegmentsDayCounts(segments, days);

      final segRanges = <_Segment>[];
      var cursor = startDate;
      for (final seg in normalized) {
        final count = (seg['dayCount'] as num?)?.toInt() ?? 1;
        final from = cursor;
        final to = DateTime(cursor.year, cursor.month, cursor.day)
            .add(Duration(days: count - 1));
        segRanges.add(_Segment(
          name: (seg['name'] as String?) ?? (seg['focus'] as String? ?? 'Segment'),
          base: (seg['base'] as String?) ?? destination,
          focus: (seg['focus'] as String?) ?? '',
          start: from,
          end: to,
          dayCount: count,
        ));
        cursor = to.add(const Duration(days: 1));
      }

      progress('Builders: planning day blocks in parallel…');

      final semaphore = _AsyncSemaphore(maxParallel);
      final futures = <Future<List<Map<String, dynamic>>>>[];
      for (int i = 0; i < segRanges.length; i++) {
        final seg = segRanges[i];
        final previousBase = i == 0 ? null : segRanges[i - 1].base;
        futures.add(semaphore.withPermit(() async {
            return _buildSegment(
            model: model,
            destination: destination,
            affordability: affordability,
            travelStyles: travelStyles,
            flexibility: flexibility,
              travelers: travelers,
              travelParty: travelParty,
            pace: pace,
            mustSee: mustSee,
            dietaryPreference: dietaryPreference,
            segment: seg,
            previousBase: previousBase,
              seasonNote: _seasonNoteFor(destination, seg.start, seg.end),
          );
        }));
      }

      final built = await Future.wait(futures);

      progress('Composing your itinerary…');
      final allDays = <Map<String, dynamic>>[];
      for (final chunk in built) {
        allDays.addAll(chunk);
      }

      _harmonizeDays(allDays, segRanges);
      final tips = _collectTips(allDays, destination);

      final result = <String, dynamic>{
        'destination': destination,
        'startDate': _isoDate(startDate),
        'endDate': _isoDate(endDate),
        'days': allDays,
        'tips': tips,
        'meta': {
          'strategy': 'architect_builders',
          'segments': segRanges
              .map((e) => {
                    'name': e.name,
                    'base': e.base,
                    'focus': e.focus,
                    'startDate': _isoDate(e.start),
                    'endDate': _isoDate(e.end),
                    'dayCount': e.dayCount,
                  })
              .toList(),
        },
      };

      progress('Done');
      return result;
    } catch (e, st) {
      debugPrint('[ItineraryAIService] Architect+Builders error: $e');
      debugPrint('[ItineraryAIService] Stack: $st');
      return {
        'destination': destination,
        'startDate': _isoDate(startDate),
        'endDate': _isoDate(endDate),
        'days': <Map<String, dynamic>>[],
        'tips': <String>[],
        'error': e.toString(),
      };
    }
  }

  String _buildArchitectPrompt({
    required String destination,
    required int totalDays,
    required String affordability,
    required List<String> travelStyles,
    required String flexibility,
    required int travelers,
    String? travelParty,
    required String pace,
    List<String>? mustSee,
    String? dietaryPreference,
    String diversityPreference = 'balanced',
    String? seasonNote,
  }) {
    final styles = travelStyles.isEmpty ? 'General' : travelStyles.join(', ');
    final must = (mustSee == null || mustSee.isEmpty) ? 'None' : mustSee.join(', ');
    final diet = (dietaryPreference == null || dietaryPreference.trim().isEmpty)
        ? 'None'
        : dietaryPreference.trim();

    final diversityHint = () {
      switch (diversityPreference) {
        case 'deep_dive':
          return 'Prefer 1–2 bases with day trips nearby (deep-dive).';
        case 'wide':
          return 'Prefer 3–5 distinct regions/cities (wide coverage).';
        default:
          return 'Prefer 2–3 bases across distinct regions (balanced).';
      }
    }();

    final party = (travelParty ?? '').trim();
    final gatewayRule = _gatewayRuleFor(destination);
    return '''
System instruction: Act as a veteran travel architect. Output ONLY JSON.

User: Design a high-level plan for a $totalDays-day trip in "$destination".
Constraints:
- Budget: $affordability
- Travel styles: $styles
- Flexibility: $flexibility
- Travelers: $travelers
- Travel party: ${party.isEmpty ? 'Unspecified' : party} (influence suitability)
- Pace: $pace
- Must-see: $must
- Dietary: $diet
- Diversity preference: $diversityPreference. $diversityHint
- Season context: ${seasonNote ?? 'Use the actual trip dates to align with seasonal highlights, local festivals, and weather.'}

 Rules:
- Propose 1 to 5 segments. Each segment has a distinct base city/region and focus theme.
- Total dayCount across segments MUST equal $totalDays.
- Ensure geographic diversity and avoid assigning all days to one city unless totalDays <= 2.
- The base MUST be a real city/region in $destination suitable as a hub for that segment.
- Order segments to minimize backtracking.
 - Entry/Exit sequencing (strict): $gatewayRule
 - Handling of "Must-see" (Include Places): Treat them as preferences, not guarantees. If they are too far apart or infeasible within $totalDays days, you MUST prune to a feasible subset and cluster around the chosen bases. Prefer to keep a sensible gateway and 1–2 nearby bases for short trips. Keep the flow robust rather than forced.
 - For very short trips (<= 4 days): Limit to gateway + at most one outlying base. Convert other must-see items into intra-day highlights or drop them.

JSON schema to output:
{
  "segments": [
    {
      "name": string,
      "base": string,
      "focus": string,
      "dayCount": number
    }
  ],
  "meta": {
    "includePlaceDecisions": [
      { "place": string, "kept": boolean, "reason": string }
    ]
  }
}
''';
  }

  Future<List<Map<String, dynamic>>> _buildSegment({
    required GenerativeModel model,
    required String destination,
    required String affordability,
    required List<String> travelStyles,
    required String flexibility,
    required int travelers,
    String? travelParty,
    required String pace,
    List<String>? mustSee,
    String? dietaryPreference,
    required _Segment segment,
    String? previousBase,
    String? seasonNote,
  }) async {
    final styles = travelStyles.isEmpty ? 'General' : travelStyles.join(', ');
    final must = (mustSee == null || mustSee.isEmpty) ? 'None' : mustSee.join(', ');
    final diet = (dietaryPreference == null || dietaryPreference.trim().isEmpty)
        ? 'None'
        : dietaryPreference.trim();

    final dates = <String>[];
    for (int i = 0; i < segment.dayCount; i++) {
      final d = DateTime(segment.start.year, segment.start.month, segment.start.day)
          .add(Duration(days: i));
      dates.add(_isoDate(d));
    }

    final party = (travelParty ?? '').trim();
    final holidayNote = _holidayNoteFor(destination, segment.start, segment.end);
    final prompt = '''
System: You are a precise travel builder. Output ONLY JSON matching the schema.

User: Build the concrete plan for these dates in $destination.
Segment:
- Title: ${segment.name}
- Base: ${segment.base}
- Focus: ${segment.focus}
- Dates: ${dates.join(', ')} (one object per date in this exact order)

Constraints:
- Budget: $affordability; Pace: $pace; Flexibility: $flexibility; Travelers: $travelers
- Travel party: ${party.isEmpty ? 'Unspecified' : party}. Adjust suitability (e.g., family-friendly picks if Family; social/nightlife options if Friends; romantic if Duo; safe solo-friendly flows if Solo).
- Travel styles: $styles
- Must-see: $must
- Dietary: $diet (align restaurants; focus on specialties rather than repeating diet labels)
- Stay strictly within base/nearby areas appropriate for "${segment.base}" and the focus.
- Pick real, locally appropriate restaurants for breakfast, lunch, dinner.
- Avoid options/alternatives. Provide a single cohesive flow per day.
- Keep text concise and human-friendly.

Title & locations & cost rules (strict):
- For each day.title, prefix with "${segment.base}: " then a short theme, e.g., "${segment.base}: Hidden alleys & hanok tea".
- For each activity.location, DO NOT append the city name "${segment.base}". Use the venue or neighborhood only.
- For each activity.cost, ONLY use a compact badge: Free (no charge) or double-dollar sign for paid.

Transit rule:
- If this is the first date in this segment and the previous segment base was "${previousBase ?? segment.base}", and that differs from "${segment.base}", include a morning activity for travel from "${previousBase ?? segment.base}" to "${segment.base}" with typical mode (e.g., KTX, express bus, short flight) and a concise duration. Breakfast may occur pre-departure, on board, or upon arrival.

 Seasonal & holiday alignment:
 - ${seasonNote ?? 'Align daily choices with the actual months (weather, daylight, seasonal events).'}
 - ${holidayNote ?? 'If any global or local festivals fall on these dates, include them appropriately.'}

 Travel-style specificity (important):
 - If styles include "Adventure": bias toward active experiences (mountain/ridge hikes, ski/snow sports in winter regions, canyoning/kayak, cycling). Ensure season-appropriate picks.
  - For Japan and the Mt. Fuji area: only propose the Fuji summit climb in official season (typically Jul–Sep). Outside that window (e.g., Mar), prefer safe adventure alternatives: Fuji Five Lakes ridge hikes, Arakurayama Sengen Park climb, snowshoeing with a certified guide, lava tubes, or ice caves. Mention guiding requirements only briefly when applicable.

  Authentic, local experiences (safe & tasteful):
  - Tailor 1–2 activities to feel distinctly local per day when possible. Examples include: neighborhood food alleys, izakaya/ramen-yokocho strolls, morning fish markets, tea ceremonies, cooking classes, pottery/craft workshops, language-exchange meetups, community walks, flea markets, indie music gigs, traditional bathhouses (onsen/sento etiquette), themed cafes (e.g., maid, animal, anime) if culturally relevant.
  - Strict safety filter: absolutely avoid adult/sexualized content, escort/host services, fetish or NSFW themes. Themed cafes are acceptable but do NOT sexualize or imply adult content, and avoid them entirely for Family travel parties.
  - Adjust by party: Family -> kid-safe museums/zoos/workshops/interactive exhibits; Solo -> social but safe mixers, walking tours, shared foodie tables; Friends -> nightlife/live music/casual bars (non-explicit); Duo -> scenic/romantic viewpoints, date-friendly dining.
  - If styles include "Culture": include at least one interaction-oriented element (e.g., guided neighborhood walk with a local, short language exchange, community market conversation) kept respectful and brief.

JSON schema to output:
{
  "days": [
    {
      "date": string,
      "title": string,
      "summary": string,
      "activities": [
        {
          "timeOfDay": "breakfast" | "morning" | "lunch" | "afternoon" | "dinner" | "evening",
          "title": string,
          "location": string,
          "notes": string,
          "cost": string
        }
      ]
    }
  ]
}
''';

    final resp = await model.generateContent(
      [Content.text(prompt)],
        generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0,
      ),
    );
    final text = _safeAggregateText(resp);
    final json = _decodeTolerantJson(text);
    final out = (json['days'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];

    final byDate = {for (final d in out) (d['date'] ?? '').toString(): d};
    final normalized = <Map<String, dynamic>>[];
    for (final d in dates) {
      final obj = byDate[d] ?? {
        'date': d,
        'title': segment.name,
        'summary': 'Details on the way',
        'activities': <Map<String, dynamic>>[],
      };
      normalized.add(obj);
    }
    return normalized;
  }

  String _safeAggregateText(GenerateContentResponse resp) {
    String? text = resp.text;
    if (text == null || text.trim().isEmpty) {
      try {
        final dyn = resp as dynamic;
        final cands = dyn.candidates as List?;
        if (cands != null && cands.isNotEmpty) {
          final buffer = StringBuffer();
          for (final c in cands) {
            final content = (c as dynamic).content;
            final parts = (content as dynamic).parts as List?;
            if (parts == null) continue;
            for (final p in parts) {
              final maybeText = (p as dynamic).text as String?;
              if (maybeText != null) buffer.write(maybeText);
            }
          }
          final s = buffer.toString().trim();
          if (s.isNotEmpty) text = s;
        }
      } catch (_) {}
    }
    if (text == null || text.trim().isEmpty) {
      throw Exception('Empty response from model');
    }
    return text;
  }

  Map<String, dynamic> _decodeTolerantJson(String raw) {
    final extracted = _extractBalancedTopLevelJson(raw);
    var cleaned = _sanitizeJson(extracted);
    cleaned = _quoteUnquotedKeys(cleaned);
    cleaned = _singleQuotedValuesToDouble(cleaned);
    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } on FormatException catch (_) {
      final refExtract = _extractFirstJsonObject(raw);
      var refClean = _sanitizeJson(refExtract);
      refClean = _quoteUnquotedKeys(refClean);
      refClean = _singleQuotedValuesToDouble(refClean);
      return jsonDecode(refClean) as Map<String, dynamic>;
    }
  }

  List<Map<String, dynamic>> _normalizeSegmentsDayCounts(
      List<Map<String, dynamic>> segments, int totalDays) {
    if (segments.isEmpty) {
      return [
        {
          'name': 'Core City Highlights',
          'base': '',
          'focus': '',
          'dayCount': totalDays,
        }
      ];
    }
    var counts = segments
        .map((s) => ((s['dayCount'] as num?)?.toInt() ?? 1).clamp(1, totalDays))
        .toList();
    var sum = counts.fold<int>(0, (a, b) => a + b);
    if (sum < totalDays) {
      int i = 0;
      while (sum < totalDays) {
        counts[i % counts.length] += 1;
        sum++;
        i++;
      }
    } else if (sum > totalDays) {
      int i = 0;
      while (sum > totalDays) {
        final idx = i % counts.length;
        if (counts[idx] > 1) {
          counts[idx] -= 1;
          sum--;
        }
        i++;
      }
    }
    final out = <Map<String, dynamic>>[];
    for (int i = 0; i < segments.length; i++) {
      final s = Map<String, dynamic>.from(segments[i]);
      s['dayCount'] = counts[i];
      out.add(s);
    }
    return out;
  }

  List<String> _collectTips(List<Map<String, dynamic>> days, String destination) {
    final tips = <String>{};
    for (final d in days) {
      final activities = (d['activities'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      for (final a in activities) {
        final n = (a['notes'] ?? '').toString();
        if (n.isEmpty) continue;
        if (n.length <= 110) tips.add(n);
        if (tips.length >= 6) break;
      }
      if (tips.length >= 6) break;
    }
    if (tips.isEmpty) {
      return [
        'Carry a contactless card; many places in $destination are cashless.',
        'Book popular restaurants a few days ahead.',
        'Use public transit for speed during peak hours.',
      ];
    }
    return tips.take(5).toList();
  }

  void _harmonizeDays(List<Map<String, dynamic>> allDays, List<_Segment> segs) {
    String baseForDate(String iso) {
      final d = DateTime.tryParse(iso);
      if (d == null) return '';
      for (final s in segs) {
        if (!d.isBefore(s.start) && !d.isAfter(s.end)) return s.base;
      }
      return '';
    }

    String normCost(String raw) {
      final s = (raw).toString().trim();
      if (s.isEmpty) return '';
      final low = s.toLowerCase();
      if (low.contains('free') || low.contains('no fee') || low.contains('complimentary')) {
        return 'Free';
      }
      if (RegExp(r'\$+').hasMatch(s) ||
          low.contains('fee') || low.contains('ticket') || low.contains('fare') || low.contains('paid')) {
        return _paidBadge;
      }
      return _paidBadge;
    }

    String stripCity(String location, String base) {
      if (location.isEmpty || base.isEmpty) return location;
      var out = location.trim();
      final baseEsc = RegExp.escape(base);
      out = out.replaceAll(RegExp(',\\s*' + baseEsc + r'$', caseSensitive: false), '').trim();
      out = out.replaceAll(RegExp(r'[-–—]\s*' + baseEsc + r'$', caseSensitive: false), '').trim();
      out = out.replaceAll(RegExp(r'\(' + baseEsc + r'\)$', caseSensitive: false), '').trim();
      return out;
    }

    bool _hasTransit(List<Map<String, dynamic>> acts) {
      for (final a in acts) {
        final t = (a['title'] ?? '').toString().toLowerCase();
        if (t.contains('travel') || t.contains('transit') || t.contains('train to') || t.contains('bus to') || t.contains('flight to')) {
          return true;
        }
      }
      return false;
    }

    for (int i = 0; i < allDays.length; i++) {
      final day = allDays[i];
      final iso = (day['date'] ?? '').toString();
      final base = baseForDate(iso);

      final rawTitle = (day['title'] ?? '').toString();
      final cleanTitle = rawTitle.trim();
      final pref = base.isEmpty ? '' : (base + ': ');
      if (cleanTitle.isEmpty) {
        day['title'] = pref + 'Day highlights';
      } else if (!cleanTitle.toLowerCase().startsWith((base + ':').toLowerCase())) {
        day['title'] = pref + cleanTitle;
      } else {
        day['title'] = cleanTitle;
      }

      final acts = (day['activities'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
      for (final a in acts) {
        final loc = (a['location'] ?? '').toString();
        a['location'] = stripCity(loc, base);
        a['cost'] = normCost((a['cost'] ?? '').toString());
      }

      final seg = segs.firstWhere(
        (s) {
          final d = DateTime.tryParse(iso);
          if (d == null) return false;
          return !d.isBefore(s.start) && !d.isAfter(s.end);
        },
        orElse: () => segs.first,
      );
      if (iso == _isoDate(seg.start) && seg != segs.first) {
        final prevIndex = segs.indexOf(seg) - 1;
        if (prevIndex >= 0) {
          final prevBase = segs[prevIndex].base;
          if (!_hasTransit(acts)) {
            acts.insert(0, {
              'timeOfDay': 'morning',
              'title': 'Travel to ' + seg.base,
              'location': 'From ' + prevBase,
              'notes': 'Typical route: fast train or coach; start early to maximize time.',
              'cost': _paidBadge,
            });
            day['activities'] = acts;
          }
        }
      }
    }
  }

  String _buildPrompt({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required int days,
    required String affordability,
    required List<String> travelStyles,
    required String flexibility,
    required int travelers,
    required String pace,
    List<String>? mustSee,
    String? dietaryPreference,
  }) {
    final sDate = _isoDate(startDate);
    final eDate = _isoDate(endDate);
    final styles = travelStyles.isEmpty ? 'General' : travelStyles.join(', ');
    final must = (mustSee == null || mustSee.isEmpty) ? 'None' : mustSee.join(', ');
    final diet = (dietaryPreference == null || dietaryPreference.trim().isEmpty)
        ? 'None'
        : dietaryPreference.trim();

    return '''
System instruction: You are a meticulous travel planner. Output ONLY a JSON object that strictly follows the schema below. No extra commentary, no prose, no markdown fences.

User request:
 Create a ${days}-day travel itinerary for "$destination" from $sDate to $eDate.
Constraints and preferences:
- Budget level: $affordability
- Travel styles: $styles
- Flexibility: $flexibility (Structured < Balanced < Spontaneous)
- Travelers: $travelers
- Pace: $pace
- Must-see: $must
  - Dietary preference: $diet (if not None, ensure restaurants align)

JSON schema to output:
{
  "destination": string,
  "startDate": string,
  "endDate": string,
  "days": [
    {
      "date": string,
      "title": string,
      "summary": string,
      "activities": [
        {
          "timeOfDay": "breakfast" | "morning" | "lunch" | "afternoon" | "dinner" | "evening",
          "title": string,
          "location": string,
          "notes": string,
          "cost": string
        }
      ]
    }
  ],
  "tips": [string]
}

 Rules:
- Ensure exactly $days day objects in chronological order.
- Plan a SINGLE concrete sequence per day. DO NOT provide options or alternatives. No "or" phrases.
- Each day MUST include at least 5 items: breakfast, lunch, dinner (named restaurants/cafés in $destination) plus 2–4 non-meal activities matched to $styles.
- Restaurants must be real and location-specific to $destination; prefer well-known places or highly-rated local favorites. Include neighborhood or area in location when possible.
- Match all picks to the $affordability budget and $pace pace.
  - For restaurant entries (breakfast/lunch/dinner), write "notes" that highlight signature dishes, house specialties, ambience, or booking tips. If a dietary preference is provided, ensure the choice aligns BUT do not repeat words like "Halal", "Vegetarian", or "Non-vegetarian" unless essential to understanding the specialty. Focus on what makes the place special rather than restating the diet label.
  - Avoid repeating dietary terms across multiple restaurants; prefer describing the cuisine or standout dishes.
  - Keep each field short and clear. Avoid emojis. Avoid bullet lists.
Respond ONLY with JSON and no code fences. Do not add trailing commas. Use straight double quotes for all strings.
''';
  }

  String _isoDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  String _extractFirstJsonObject(String raw) {
    final s = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      return s;
    }
    return s.substring(start, end + 1);
  }

  String _extractBalancedTopLevelJson(String raw) {
    final s = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    int depth = 0;
    int start = -1;
    for (int i = 0; i < s.length; i++) {
      final ch = s[i];
      if (ch == '{') {
        if (depth == 0) start = i;
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0 && start != -1) {
          return s.substring(start, i + 1);
        }
      }
    }
    return _extractFirstJsonObject(s);
  }

  String _sanitizeJson(String input) {
    var out = input;
    out = out.replaceAll(RegExp(r"//.*"), '');
    out = out.replaceAll('“', '"').replaceAll('”', '"').replaceAll('’', "'");
    out = out.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
    out = out.replaceAll(RegExp(r'\s*:\s*'), ': ');
    out = utf8.decode(utf8.encode(out));
    return out.trim();
  }

  String _quoteUnquotedKeys(String input) {
    return input.replaceAllMapped(
      RegExp(r'(?<=[{,])\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s'),
      (m) => ' "${m[1]}": ',
    );
  }

  // Convert common single-quoted string values to double-quoted JSON strings.
  // Conservative: only convert when it appears right after a colon.
  String _singleQuotedValuesToDouble(String input) {
    return input.replaceAllMapped(
      RegExp(r":\s*'([^']*)'"),
      (m) {
        final val = m.group(1) ?? '';
        final escaped = val.replaceAll('"', '\\"');
        return ': "' + escaped + '"';
      },
    );
  }

  // Human-readable season notes to bias the model.
  String? _seasonNoteFor(String destination, DateTime start, DateTime end) {
    String monName(int m) {
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return months[(m - 1).clamp(0, 11)];
    }
    final s = '${monName(start.month)} ${start.year}';
    final e = '${monName(end.month)} ${end.year}';
    final window = s == e ? s : ('$s – $e');
    final name = destination.toLowerCase();
    // Targeted hints for Japan as requested; otherwise generic seasonal alignment.
    if (name.contains('japan')) {
      final m = start.month; // assume same season window
      if (m >= 3 && m <= 4) {
        return 'Trip window: $window. Prioritize cherry blossoms (sakura) at parks/temples, seasonal wagashi; for adventure, choose safe early-spring hikes (Fuji Five Lakes, Arakurayama Sengen Park) rather than summit attempts.';
      }
      if (m == 12 || m <= 2) {
        return 'Trip window: $window. Emphasize winter experiences: Hokkaido (Sapporo/Otaru/Niseko), Nagano, and Yuzawa for snow; winter illuminations; warming specialties; allocate ski/onsen days if Adventure.';
      }
      if (m >= 7 && m <= 9) {
        return 'Trip window: $window. Hot/humid: schedule indoor breaks, early/late outdoor slots; consider summer festivals and coastal escapes.';
      }
      return 'Trip window: $window. Align with seasonal foods, local festivals, and garden foliage.';
    }
    return 'Trip window: $window. Align picks with seasonal weather and events for the destination.';
  }

  // Enforce reasonable first/last bases for common destinations.
  String _gatewayRuleFor(String destination) {
    final name = destination.toLowerCase();
    if (name.contains('japan')) {
      return 'Start the first segment in a major gateway (Tokyo or Osaka/Kyoto area). End the final segment in a major exit gateway (prefer Tokyo or Osaka/Kyoto) so the last night is in/near that hub. Keep segment order geographically progressive to reduce backtracking.';
    }
    // Generic rule: begin and end in international gateways, with common examples to bias choices.
    return [
      'Start the first segment in a practical international gateway for arrival, and plan the last segment so the final night is in/near an international gateway for departure.',
      'Never start the trip in a remote island or secondary city unless the user explicitly specified arrival there.',
      'If must-see places are scattered and days are few, keep gateway + at most one outlying base and drop the rest.',
      'Examples to bias gateway choice (not exhaustive):',
      '- Thailand -> start/end Bangkok; outlying bases like Chiang Mai, Phuket/Krabi only if time allows.',
      '- Vietnam -> start/end Hanoi or Ho Chi Minh City; add Da Nang/Hoi An as outlying if time allows.',
      '- Indonesia -> start/end Jakarta or Denpasar (Bali) depending on trip focus.',
      '- Italy -> start/end Rome, Milan, or Venice depending on region coverage.',
      'Choose segment order to minimize backtracking.'
    ].join(' ');
  }

  // Minimal holiday guidance injected into builder prompts based on dates & destination.
  String? _holidayNoteFor(String destination, DateTime start, DateTime end) {
    bool inRange(int month, int day) {
      final s = DateTime(start.year, start.month, start.day);
      final e = DateTime(end.year, end.month, end.day);
      final target = DateTime(s.year, month, day);
      if (e.isBefore(s)) return false;
      // Handle potential cross-year ranges (Dec -> Jan)
      final candidates = <DateTime>[
        DateTime(s.year, month, day),
        DateTime(e.year, month, day),
      ];
      return candidates.any((d) => !d.isBefore(s) && !d.isAfter(e));
    }

    final name = destination.toLowerCase();
    final notes = <String>[];
    // Global-ish festive hooks
    if (inRange(12, 24)) {
      notes.add('If Dec 24 falls within these dates, include an evening dedicated to Christmas Eve ambience (illumination walks, festive dinners, seasonal markets), adjusted to local customs.');
    }
    if (inRange(12, 25)) {
      notes.add('If Dec 25 is included, include a daytime/early evening Christmas activity in line with local culture (e.g., illuminations, special menus, or winter attractions).');
    }
    if (inRange(12, 31)) {
      notes.add('If Dec 31 is included, include a New Year’s Eve plan (countdown spot or local tradition).');
    }
    if (inRange(1, 1)) {
      notes.add('If Jan 1 is included, reflect local New Year practices; in Japan consider Hatsumode shrine visits and note that many shops open late or remain closed.');
    }

    if (name.contains('japan')) {
      // Nudge toward Japan-specific winter illuminations and shrine traditions in Dec/Jan
      final m = start.month;
      if (m == 12 || m == 1) {
        notes.add('For Japan in Dec–Jan, include winter illuminations and a brief shrine/temple tradition context.');
      }
    }

    if (notes.isEmpty) return null;
    return notes.join(' ');
  }
}

class _Segment {
  final String name;
  final String base;
  final String focus;
  final DateTime start;
  final DateTime end;
  final int dayCount;
  _Segment({
    required this.name,
    required this.base,
    required this.focus,
    required this.start,
    required this.end,
    required this.dayCount,
  });
}

class _AsyncSemaphore {
  final int _max;
  int _current = 0;
  final Queue<Completer<void>> _waiters = Queue();

  _AsyncSemaphore(this._max) : assert(_max > 0);

  Future<T> withPermit<T>(Future<T> Function() action) async {
    await _acquire();
    try {
      return await action();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_current < _max) {
      _current++;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      final c = _waiters.removeFirst();
      c.complete();
    } else {
      _current = (_current - 1).clamp(0, _max);
    }
  }
}
