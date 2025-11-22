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
    String?
        travelParty, // Solo | Couple | Friends | Family (hints tone/constraints)
    String pace = 'moderate',
    List<String>? mustSee,
    String? dietaryPreference,
    String diversityPreference = 'balanced', // deep_dive | balanced | wide
    void Function(String step)? onProgress,
    int maxParallel = 4,
  }) async {
    final days = endDate.difference(startDate).inDays + 1;
    final archModel = FirebaseAI.googleAI().generativeModel(model: _modelName);

    final builderModel =
        FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash-lite');

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

      final archResp = await archModel.generateContent(
        [Content.text(archPrompt)],
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.1,
        ),
      );

      final archText = _safeAggregateText(archResp);
      final archJson = _decodeTolerantJson(archText);
      final segments =
          (archJson['segments'] as List?)?.cast<Map<String, dynamic>>() ??
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
          name: (seg['name'] as String?) ??
              (seg['focus'] as String? ?? 'Segment'),
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
        final isFirstSegment = i == 0;
        final isLastSegment = i == segRanges.length - 1;
        futures.add(semaphore.withPermit(() async {
          return _buildSegment(
            model: builderModel,
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
            isFirstSegment: isFirstSegment,
            isLastSegment: isLastSegment,
            tripStartDate: startDate,
            tripEndDate: endDate,
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

      _harmonizeDays(destination, allDays, segRanges);
      _injectArrivalDepartureIfMissing(destination, allDays, segRanges);
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
    // 1. DYNAMIC INPUT PREPARATION (Dart logic > AI Token usage)
    final styles = travelStyles.isEmpty ? 'General' : travelStyles.join(', ');
    final must =
        (mustSee == null || mustSee.isEmpty) ? 'None' : mustSee.join(', ');

    // Only add dietary/party constraints if they actually exist.
    // Sending "Diet: None" is wasted tokens.
    String constraints =
        "- Budget: $affordability; Pace: $pace; Travelers: $travelers";
    if (travelParty != null && travelParty.isNotEmpty) {
      constraints += "; Party: $travelParty";
    }
    if (dietaryPreference != null && dietaryPreference.trim().isNotEmpty) {
      constraints += "; Diet: $dietaryPreference";
    }

    // Keep your existing logic for diversity hints (It is good logic)
    final diversityHint = () {
      switch (diversityPreference) {
        case 'deep_dive':
          return 'Prefer 1–2 bases with day trips (deep-dive).';
        case 'wide':
          return 'Prefer 3–5 distinct regions (wide coverage).';
        default:
          return 'Prefer 2–3 bases across distinct regions (balanced).';
      }
    }();

    // Keep your existing segment math (Strict logic is better than AI guessing)
    int minSeg;
    int maxSeg;
    switch (diversityPreference) {
      case 'deep_dive':
        minSeg = 1;
        maxSeg = totalDays <= 3 ? 1 : 2;
        break;
      case 'wide':
        if (totalDays <= 4) {
          minSeg = 2;
          maxSeg = 3;
        } else if (totalDays <= 6) {
          minSeg = 3;
          maxSeg = 4;
        } else if (totalDays <= 10) {
          minSeg = 3;
          maxSeg = 5;
        } else {
          minSeg = 4;
          maxSeg = 6;
        }
        break;
      default: // balanced
        if (totalDays <= 3) {
          minSeg = 1;
          maxSeg = 2;
        } else if (totalDays <= 6) {
          minSeg = 2;
          maxSeg = 3;
        } else {
          minSeg = 2;
          maxSeg = 4;
        }
        break;
    }

    final gatewayRule = _gatewayRuleFor(destination);

    // 2. THE OPTIMIZED PROMPT
    // Reduced prose, strict bullet points, clearer hierarchy.
    return '''
System: Strategic Travel Architect. Output JSON.
Task: Partition a $totalDays-day trip to "$destination" into $minSeg-$maxSeg logical segments.

Context:
$constraints
- Styles: $styles
- Flexibility: $flexibility
- Must-See: $must
- Diversity: $diversityPreference ($diversityHint)
- Season: ${seasonNote ?? 'Align with dates'}

Rules:
1. Total "dayCount" sum MUST equal $totalDays.
2. Geographic Logic: Order segments to minimize backtracking.
3. Bases: Must be real, logical hubs. Prefer UNIQUE bases (unless forced by flight departure).
4. Gateway Logic: $gatewayRule
5. Feasibility: "Must-sees" are preferences. Prune them if they force a bad route or illogical backtracking.
6. Short Trip Handling: If days <= 4, limit to Gateway + max 1 nearby base.

JSON Schema:
{
  "segments": [
    {
      "name": string, // e.g. "Kyoto & Temples"
      "base": string, // e.g. "Kyoto"
      "focus": string, // Main theme/vibe
      "dayCount": number
    }
  ],
  "meta": {
    "pruned": [ // Rename 'includePlaceDecisions' to 'pruned' to save tokens
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
    required bool isFirstSegment,
    required bool isLastSegment,
    required DateTime tripStartDate,
    required DateTime tripEndDate,
  }) async {
    // 1. TOKEN DIET: PREPARE DATES IN DART
    final dates = <String>[];
    for (int i = 0; i < segment.dayCount; i++) {
      dates.add(_isoDate(segment.start.add(Duration(days: i))));
    }

    // 2. TOKEN DIET: CONDITIONAL RULES
    // Instead of sending "If styles include Adventure..." to everyone,
    // we check the style in Dart and ONLY send the rule if true.
    String specificRules = "";

    if (travelStyles.contains("Adventure")) {
      specificRules +=
          "\n- Adventure: Bias toward active experiences (hikes/kayak). For peaks, respect seasons/safety.";
    }
    if (travelStyles.contains("Nightlife") || travelStyles.contains("Social")) {
      specificRules +=
          "\n- Nightlife: Include 1-2 safe evening social spots (bars/music).";
    }
    if (travelStyles.contains("Culture")) {
      specificRules +=
          "\n- Culture: Include local interactions (market/walk/workshop).";
    }

    // Only inject holiday note if it is non-null and meaningful
    final holidayNote =
        _holidayNoteFor(destination, segment.start, segment.end);
    if (holidayNote != null && holidayNote.isNotEmpty) {
      specificRules +=
          "\n- Holiday: Integrate '$holidayNote' into the day's narrative.";
    }

    // Japan/Korea specific checks (Kept, but condensed)
    final destLower = destination.toLowerCase();
    if (destLower.contains('japan')) {
      specificRules +=
          "\n- Region: Japan. Mt Fuji summit only in season. Prioritize early starts.";
    }

    // 3. TOKEN DIET: COMPACT CONSTRAINTS
    final partyStr =
        travelParty?.isNotEmpty == true ? travelParty : "Unspecified";
    final dietStr =
        dietaryPreference?.isNotEmpty == true ? dietaryPreference : "None";
    final mustStr = mustSee?.isNotEmpty == true ? mustSee!.join(", ") : "None";

    final prompt = '''
System: Expert Travel Curator. Output JSON only.
Task: Create a rich, personalized plan for ${dates.first} to ${dates.last} in "${segment.base}".

Context:
- Base: ${segment.base} (Focus: ${segment.focus})
- Budget: $affordability; Pace: $pace; Travelers: $travelers
- Party: $partyStr; Styles: ${travelStyles.join(', ')}
- Must-See: $mustStr
- Diet: $dietStr
- Season: ${seasonNote ?? 'Align with dates'}
$specificRules

Strict Rules:
1. Stay in/near ${segment.base}.
2. Real, specific places only. No "options".
3. Transit: If coming from ${previousBase ?? 'elsewhere'} on Day 1, include travel leg (morn/aft).
4. Boundary: ${isFirstSegment ? "Day 1 is Arrival (Airport->Hotel)." : ""} ${isLastSegment ? "Last Day is Departure." : ""}
4. WRITING STYLE: 
   - Do NOT be generic. 
   - In "notes", describe the *atmosphere* or *signature dish*. 
   - Explain WHY this fits a "${travelStyles.first}" traveler. 

JSON Schema (Compact Keys):
{
  "days": [
    {
      "d": "YYYY-MM-DD", 
      "t": "Thematic Title", 
      "s": "Engaging Summary (1 sentence)",
      "a": [ 
        { 
          "m": "morn|lunch|aft|din|eve", 
          "t": "Title", 
          "l": "Location (No city name)", 
          "n": "Vivid Note (Max 12-15 words)", 
          "c": "$_paidBadge|Free" 
        }
      ]
    }
  ]
}
''';

    // 4. CALL AI (Using the Fast Model passed in)
    final resp = await model.generateContent(
      [Content.text(prompt)],
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.3, // Low temp for strict adherence
      ),
    );

    final text = _safeAggregateText(resp);
    final json = _decodeTolerantJson(text);
    final rawDays = (json['days'] as List?) ?? [];

    // 5. REMAP COMPACT KEYS BACK TO FULL MODEL
    // This step enables the "Compact Keys" optimization which saves ~20% generation time.
    final mappedDays = <Map<String, dynamic>>[];

    String expandTime(String? m) {
      switch (m) {
        case 'morn':
          return 'morning';
        case 'aft':
          return 'afternoon';
        case 'din':
          return 'dinner';
        case 'eve':
          return 'evening';
        case 'lunch':
          return 'lunch'; // explicit match
        default:
          return 'morning';
      }
    }

    for (var rd in rawDays) {
      mappedDays.add({
        'date': rd['d'],
        'title': rd['t'],
        'summary': rd['s'],
        'activities': (rd['a'] as List? ?? [])
            .map((act) => {
                  'timeOfDay': expandTime(act['m']),
                  'title': act['t'],
                  'location': act['l'],
                  'notes': act['n'],
                  'cost': act['c'] == 'Free'
                      ? 'Free'
                      : _paidBadge, // Normalize cost
                })
            .toList(),
      });
    }

    // 6. NORMALIZE & FILL GAPS
    final byDate = {
      for (final d in mappedDays) (d['date'] ?? '').toString(): d
    };
    final normalized = <Map<String, dynamic>>[];
    for (final d in dates) {
      normalized.add(byDate[d] ??
          {
            'date': d,
            'title': segment.name,
            'summary': 'Exploration',
            'activities': [],
          });
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

  List<String> _collectTips(
      List<Map<String, dynamic>> days, String destination) {
    final tips = <String>{};
    for (final d in days) {
      final activities =
          (d['activities'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
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

  void _harmonizeDays(String destination, List<Map<String, dynamic>> allDays,
      List<_Segment> segs) {
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
      if (low.contains('free') ||
          low.contains('no fee') ||
          low.contains('complimentary')) {
        return 'Free';
      }
      if (RegExp(r'\$+').hasMatch(s) ||
          low.contains('fee') ||
          low.contains('ticket') ||
          low.contains('fare') ||
          low.contains('paid')) {
        return _paidBadge;
      }
      return _paidBadge;
    }

    String stripCity(String location, String base) {
      if (location.isEmpty || base.isEmpty) return location;
      var out = location.trim();
      final baseEsc = RegExp.escape(base);
      out = out
          .replaceAll(
              RegExp(',\\s*' + baseEsc + r'$', caseSensitive: false), '')
          .trim();
      out = out
          .replaceAll(
              RegExp(r'[-–—]\s*' + baseEsc + r'$', caseSensitive: false), '')
          .trim();
      out = out
          .replaceAll(
              RegExp(r'\(' + baseEsc + r'\)$', caseSensitive: false), '')
          .trim();
      return out;
    }

    bool _hasTransit(List<Map<String, dynamic>> acts) {
      for (final a in acts) {
        final t = (a['title'] ?? '').toString().toLowerCase();
        if (t.contains('travel') ||
            t.contains('transit') ||
            t.contains('train to') ||
            t.contains('bus to') ||
            t.contains('flight to')) {
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
      } else if (!cleanTitle
          .toLowerCase()
          .startsWith((base + ':').toLowerCase())) {
        day['title'] = pref + cleanTitle;
      } else {
        day['title'] = cleanTitle;
      }

      final acts = (day['activities'] as List?)?.cast<Map<String, dynamic>>() ??
          <Map<String, dynamic>>[];
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
            final note = _transitNoteFor(destination, prevBase, seg.base);
            acts.insert(0, {
              'timeOfDay': 'morning',
              'title': 'Travel to ' + seg.base,
              'location': 'From ' + prevBase,
              'notes': note,
              'cost': _paidBadge,
            });
            day['activities'] = acts;
          }
        }
      }
    }
  }

  // Ensure explicit arrival on day 1 and departure on the last day if the model omitted them.
  void _injectArrivalDepartureIfMissing(
    String destination,
    List<Map<String, dynamic>> allDays,
    List<_Segment> segs,
  ) {
    if (allDays.isEmpty) return;

    bool _containsKeyword(List<Map<String, dynamic>> acts, List<String> keys) {
      for (final a in acts) {
        final t = (a['title'] ?? '').toString().toLowerCase();
        final n = (a['notes'] ?? '').toString().toLowerCase();
        for (final k in keys) {
          if (t.contains(k) || n.contains(k)) return true;
        }
      }
      return false;
    }

    // Arrival on first day
    final first = allDays.first;
    final firstActs =
        (first['activities'] as List?)?.cast<Map<String, dynamic>>() ??
            <Map<String, dynamic>>[];
    final firstDate = (first['date'] ?? '').toString();
    final firstSeg = segs.firstWhere(
      (s) => _isoDate(s.start) == firstDate,
      orElse: () => segs.first,
    );
    if (!_containsKeyword(
        firstActs, ['arrival', 'arrive', 'airport', 'check-in', 'check in'])) {
      firstActs.insert(0, {
        'timeOfDay': 'morning',
        'title': 'Arrival and hotel transfer',
        'location': 'Airport ↔ Hotel',
        'notes': 'Arrive in ' +
            firstSeg.base +
            '; transfer to accommodation, check-in or bag drop, short orientation stroll.',
        'cost': _paidBadge,
      });
      first['activities'] = firstActs;
    }

    // Departure on last day
    final last = allDays.last;
    final lastActs =
        (last['activities'] as List?)?.cast<Map<String, dynamic>>() ??
            <Map<String, dynamic>>[];
    if (!_containsKeyword(lastActs, [
      'depart',
      'departure',
      'airport',
      'flight',
      'train',
      'check-out',
      'checkout'
    ])) {
      lastActs.add({
        'timeOfDay': 'evening',
        'title': 'Departure flight/train',
        'location': 'Hotel → Airport/Station',
        'notes':
            'Head to the gateway for your departure; allow buffer for transit and security.',
        'cost': _paidBadge,
      });
      last['activities'] = lastActs;
    }
  }

  // Infer a sensible transit note between two bases, place-agnostic heuristics.
  String _transitNoteFor(String destination, String from, String to) {
    final d = destination.toLowerCase();
    final f = from.toLowerCase();
    final t = to.toLowerCase();

    bool mentions(String s, List<String> keys) =>
        keys.any((k) => s.contains(k));

    // If an obvious island appears, bias to flight/ferry
    const islandKeys = [
      'island',
      'islands',
      'archipelago',
      'jeju',
      'okinawa',
      'bali',
      'sardinia',
      'sicily',
      'corsica',
      'hvar',
      'crete',
      'santorini',
      'naxos',
      'mykonos',
      'mallorca',
      'ibiza',
      'tenerife',
      'gran canaria',
      'zanzibar',
      'hainan',
      'luzon',
      'cebu',
      'palawan'
    ];
    final islandPair = mentions(f, islandKeys) || mentions(t, islandKeys);

    if (islandPair) {
      return 'Recommended: flight (fast and frequent). Ferries exist on some routes. Aim for a morning departure around 08:30–10:30 to unlock the afternoon at your destination.';
    }

    // Country-specific rail hints
    if (d.contains('japan')) {
      return 'Recommended: Shinkansen/limited-express rail (e.g., Tokyo Station ⇄ Kyoto Station ~2h15). Aim for morning 08:30–10:30 to free your afternoon.';
    }
    if (d.contains('korea') || d.contains('south korea')) {
      final seoul = f.contains('seoul') || t.contains('seoul');
      final busan = f.contains('busan') || t.contains('busan');
      final jeju = f.contains('jeju') || t.contains('jeju');
      if ((f.contains('seoul') && t.contains('busan')) ||
          (f.contains('busan') && t.contains('seoul'))) {
        return 'KTX high-speed rail: Seoul Station ⇄ Busan Station ~2h15. Recommended morning 08:30–10:30 with seat reservation to maximize time on arrival.';
      }
      if (jeju && seoul) {
        return 'Flight: Seoul Gimpo (GMP) ⇄ Jeju (CJU) ~1h10. Recommended morning 08:00–10:00; frequent departures.';
      }
      if (jeju && busan) {
        return 'Flight: Busan Gimhae (PUS) ⇄ Jeju (CJU) ~1h. Recommended midday 11:00–13:00 or morning if you prefer more time on Jeju.';
      }
      return 'Typical route: KTX high-speed rail between major cities; aim for a morning 08:30–10:30 departure to free the afternoon.';
    }
    if (d.contains('france')) {
      return 'Recommended: TGV/TER rail; target a morning 08:30–10:30 departure for longer legs.';
    }
    if (d.contains('italy')) {
      return 'Recommended: Frecciarossa/Italo or regional rail; morning 08:30–10:30 is ideal for intercity moves.';
    }
    if (d.contains('spain')) {
      return 'Recommended: AVE/ALVIA rail or coach; morning 08:30–10:30 for long legs, otherwise early afternoon.';
    }
    if (d.contains('germany')) {
      return 'Recommended: ICE/IC rail; aim for morning 08:30–10:30 to keep the afternoon mostly free.';
    }
    if (d.contains('china')) {
      return 'Recommended: high-speed G/D train; morning 08:30–10:30 works best for intercity transfers.';
    }

    // Fallback
    return 'Recommended: intercity train/coach. For long transfers, depart in the morning around 08:30–10:00; for short hops, consider early afternoon; keep evenings for short transfers after a full day.';
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
    final must =
        (mustSee == null || mustSee.isEmpty) ? 'None' : mustSee.join(', ');
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
  - Flexibility: $flexibility (Structured < Balanced < Relaxed)
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
    
    // 1. CRITICAL: Remove all newlines, tabs, and carriage returns.
    // This often fixes structural errors caused by poor formatting in arrays/objects.
    out = out.replaceAll(RegExp(r'[\n\r\t]'), ''); 

    // 2. Remove comments and smart quotes
    out = out.replaceAll(RegExp(r"//.*"), '');
    out = out.replaceAll('“', '"').replaceAll('”', '"').replaceAll('’', "'");
    
    // 3. Remove trailing commas (critical for model output)
    out = out.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
    
    // 4. Normalize spacing around colons (keeps structure readable for humans/debug)
    out = out.replaceAll(RegExp(r'\s*:\s*'), ': ');
    
    // 5. Clean up encoding issues
    out = utf8.decode(utf8.encode(out));
    
    // The final trim is crucial for leading/trailing non-JSON content.
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
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return months[(m - 1).clamp(0, 11)];
    }

    final s = '${monName(start.month)} ${start.year}';
    final e = '${monName(end.month)} ${end.year}';
    final window = s == e ? s : ('$s – $e');
    final m = start.month; // assume same seasonal window across the trip
    String generic;
    if (m >= 3 && m <= 5) {
      generic =
          'Spring window ($window): highlight blossoms/wildflowers, outdoor strolls, garden/park time, and seasonal sweets/produce.';
    } else if (m >= 6 && m <= 8) {
      generic =
          'Summer window ($window): schedule early/late outdoor slots to avoid mid-day heat, add waterfronts/beaches, and include cool indoor breaks.';
    } else if (m >= 9 && m <= 11) {
      generic =
          'Autumn window ($window): feature foliage viewpoints, harvest markets, cozy neighborhoods, and seasonal comfort foods.';
    } else {
      generic =
          'Winter window ($window): bias toward winter lights/markets, warming cuisine, museums/cafés; include snow sports/onsen-style soaks where climates allow.';
    }
    return generic;
  }

  // Enforce reasonable first/last bases for common destinations.
  String _gatewayRuleFor(String destination) {
    final name = destination.toLowerCase();
    if (name.contains('japan')) {
      return 'Start the first segment in a major gateway (Tokyo or Osaka/Kyoto area). End the final segment in a major exit gateway (prefer Tokyo or Osaka/Kyoto) so the last night is in/near that hub. Keep segment order geographically progressive to reduce backtracking.';
    }
    if (name.contains('korea')) {
      return 'Begin in a primary gateway (Seoul – Incheon/Gimpo). Prefer a forward sequence such as Seoul -> Busan (KTX) -> Jeju (flight) and then depart from a viable gateway (Seoul or Busan/Gimhae) without unnecessary returns. Avoid sequences like Seoul -> Jeju -> Seoul -> Busan; instead, end in Busan if international flights are available, or fly Jeju -> Seoul only as a same-day departure buffer with minimal sightseeing.';
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

    final notes = <String>[];
    // Global-ish festive hooks
    if (inRange(12, 24)) {
      notes.add(
          'If Dec 24 falls within these dates, include an evening dedicated to Christmas Eve ambience (illumination walks, festive dinners, seasonal markets), adjusted to local customs.');
    }
    if (inRange(12, 25)) {
      notes.add(
          'If Dec 25 is included, include a daytime/early evening Christmas activity in line with local culture (e.g., illuminations, special menus, or winter attractions).');
    }
    if (inRange(12, 31)) {
      notes.add(
          'If Dec 31 is included, include a New Year’s Eve plan (countdown spot or local tradition).');
    }
    if (inRange(1, 1)) {
      notes.add(
          'If Jan 1 is included, reflect local New Year practices and opening hours; expect slower mornings or closures.');
    }
    // Lunar New Year varies (late Jan to mid Feb). When the window overlaps, nudge to include it if locally observed.
    if (start.month <= 2 || end.month <= 2) {
      notes.add(
          'If Lunar New Year falls within these dates at this destination, include an appropriate celebration or neighborhood walk, accounting for closures and crowds.');
    }
    // Generic nudge for any major local festival overlapping dates
    notes.add(
        'If any major local festival coincides with these dates, include a short, safe, authentic visit aligned with the day’s base.');

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
