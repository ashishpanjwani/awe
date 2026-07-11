import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

class ItineraryAIService {
  static const String _modelName = 'gemini-3.1-flash-lite';
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
    final model = FirebaseAI.googleAI().generativeModel(model: _modelName);
    final builderModel =
        FirebaseAI.googleAI().generativeModel(model: 'gemini-3.1-flash-lite');

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
          temperature: 0.7,
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

      // Enrich meals to ensure real, named venues (keeps previous improvements intact)
      // progress('Ensuring named restaurants/cafés (no generic placeholders)…');
      // await _ensureNamedVenues(
      //   model: model,
      //   destination: destination,
      //   affordability: affordability,
      //   dietaryPreference: dietaryPreference,
      //   allDays: allDays,
      //   segs: segRanges,
      // );

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
    final styles = travelStyles.isEmpty ? 'General' : travelStyles.join(', ');
    final must =
        (mustSee == null || mustSee.isEmpty) ? 'None' : mustSee.join(', ');
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

    // Compute hard segment count bounds based on trip length and diversity
    int minSeg;
    int maxSeg;
    switch (diversityPreference) {
      case 'deep_dive':
        minSeg = 1;
        maxSeg = totalDays <= 3 ? 1 : 2;
        break;
      case 'wide':
        if (totalDays <= 4) {
          minSeg = 2; // gateway + one base only on very short trips
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
  - Propose between $minSeg and $maxSeg segments (inclusive). Each segment has a distinct base city/region and focus theme.
  - Total dayCount across segments MUST equal $totalDays.
  - Ensure geographic diversity and avoid assigning all days to one city unless totalDays <= 2.
  - The base MUST be a real city/region in $destination suitable as a hub for that segment.
  - Order segments to minimize backtracking in a forward, sensible line.
  - Prefer UNIQUE bases. Do NOT create multiple non-contiguous segments for the same base unless it is the final-night departure buffer and no alternate international gateway is viable.
  - If an alternate international gateway near the final segment exists (e.g., secondary hub city), END THERE instead of returning to the first gateway.
  - If a return to the initial gateway is unavoidable, allocate at most 1 day for the final segment and treat it as a light departure day (different neighborhood; no repeat of earlier highlights).
  - Entry/Exit sequencing (strict): $gatewayRule
  - Handling of "Must-see" (Include Places): Treat them as preferences, not guarantees. If they are too far apart or infeasible within $totalDays days, you MUST prune to a feasible subset and cluster around the chosen bases. Prefer to keep a sensible gateway and 1–2 nearby bases for short trips. Keep the flow robust rather than forced.
  - For very short trips (<= 4 days): Limit to gateway + at most one outlying base. Convert other must-see items into intra-day highlights or drop them.
  - Honor the diversity preference strictly: do NOT return fewer than $minSeg segments unless physically impossible; justify in meta.includePlaceDecisions if pruning reduces bases.

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
    required bool isFirstSegment,
    required bool isLastSegment,
    required DateTime tripStartDate,
    required DateTime tripEndDate,
  }) async {
    final styles = travelStyles.isEmpty ? 'General' : travelStyles.join(', ');
    final must =
        (mustSee == null || mustSee.isEmpty) ? 'None' : mustSee.join(', ');
    final diet = (dietaryPreference == null || dietaryPreference.trim().isEmpty)
        ? 'None'
        : dietaryPreference.trim();

    final dates = <String>[];
    for (int i = 0; i < segment.dayCount; i++) {
      final d =
          DateTime(segment.start.year, segment.start.month, segment.start.day)
              .add(Duration(days: i));
      dates.add(_isoDate(d));
    }

    final party = (travelParty ?? '').trim();
    final holidayNote =
        _holidayNoteFor(destination, segment.start, segment.end);
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
  - Travel party: ${party.isEmpty ? 'Unspecified' : party}. Adjust suitability (e.g., family-friendly picks if Family; social/nightlife options if Friends; romantic if Couple; safe solo-friendly flows if Solo).
- Travel styles: $styles
- Must-see: $must
- Dietary: $diet (align restaurants; focus on specialties rather than repeating diet labels)
- Stay strictly within base/nearby areas appropriate for "${segment.base}" and the focus.
 - Pick real, named restaurants/cafés (discoverable on Google Maps) for breakfast, lunch, and dinner.
 - STRICT: No generic placeholders like "local cafe", "street food area", "food court", "ramen shop", "seafood restaurant". Use specific proper names.
 - For each meal, use a DIFFERENT venue name than any other day in this trip (no repeats across the itinerary).
- Avoid options/alternatives. Provide a single cohesive flow per day.
- Keep text concise and human-friendly.

 Title & locations & cost rules (strict):
- For each day.title, prefix with "${segment.base}: " then a short theme, e.g., "${segment.base}: Hidden alleys & hanok tea".
- For each activity.location, DO NOT append the city name "${segment.base}". Use the venue or neighborhood only.
- For each activity.cost, ONLY use a compact badge: Free (no charge) or double-dollar sign for paid.
 - For meals: activity.title MUST be the venue name (proper noun). activity.location should be the neighborhood/district (e.g., "Gangnam"), NOT the city name.
  
  Transit rule (decisive, no vagueness):
  - If this is the first date in this segment and the previous segment base was "${previousBase ?? segment.base}", and that differs from "${segment.base}": include ONE travel activity from "${previousBase ?? segment.base}" to "${segment.base}" with a realistic mode (high-speed rail/rail, coach, flight, or ferry as appropriate).
  - You MUST choose a specific time-of-day slot for that travel activity: "morning", "midday", or "evening".
  - Decision rules: prefer morning for long rail/flight legs to unlock afternoon time; use midday only for short hops when morning has a marquee activity; use evening for short transfers following a full day.
  - Never write phrases like "depending on plans" or present undecided options. Decide the slot and integrate it into the day's flow.
  - Never propose an overland route across open sea. If a sea crossing is required (e.g., islands), use flight or ferry.

 Seasonal & holiday alignment:
 - ${seasonNote ?? 'Align daily choices with the actual months (weather, daylight, seasonal events).'}
  - ${holidayNote ?? 'If any global or local festivals fall on these dates, include them appropriately.'}
  - If seasonally relevant highlights exist for this destination and dates, INCLUDE at least one explicit seasonal highlight within the first 1–2 days of the relevant segment (e.g., spring blossoms/wildflowers; autumn foliage; winter snow activities where applicable; summer waterfronts/early-late outdoor slots).

 Travel-style specificity (important):
  - If styles include "Adventure": bias toward active experiences (mountain/ridge hikes, ski/snow sports in winter regions, canyoning/kayak, cycling). Ensure season-appropriate picks.
   - For prominent peaks anywhere: propose summit climbs only in official open season with proper safety. Outside that window, switch to safe alternatives (ridge viewpoints, guided hikes, caves/lava tubes, snowshoeing) and mention guiding briefly when relevant.

  Authentic, local experiences (safe & tasteful):
  - Tailor 1–2 activities to feel distinctly local per day when possible. Examples include: neighborhood food alleys, izakaya/ramen-yokocho strolls, morning fish markets, tea ceremonies, cooking classes, pottery/craft workshops, language-exchange meetups, community walks, flea markets, indie music gigs, traditional bathhouses (onsen/sento etiquette), themed cafes (e.g., maid, animal, anime) if culturally relevant.
  - Strict safety filter: absolutely avoid adult/sexualized content, escort/host services, fetish or NSFW themes. Themed cafes are acceptable but do NOT sexualize or imply adult content, and avoid them entirely for Family travel parties.
  - Adjust by party: Family -> kid-safe museums/zoos/workshops/interactive exhibits; Solo -> social but safe mixers, walking tours, shared foodie tables; Friends -> nightlife/live music/casual bars (non-explicit); Couple -> scenic/romantic viewpoints, date-friendly dining.
  - If styles include "Culture": include at least one interaction-oriented element (e.g., guided neighborhood walk with a local, short language exchange, community market conversation) kept respectful and brief.
   - If styles include "Nightlife": add an evening slot on 1–3 nights focused on vibrant but tasteful nightlife (e.g., live music bars, craft cocktail bars, club district walks) aligned with the base city. Keep it safe and non-explicit.

  Trip boundary rule (arrival/departure, strict):
  - Is this the first segment of the whole trip? ${isFirstSegment ? 'YES' : 'NO'}
  - Is this the last segment of the whole trip? ${isLastSegment ? 'YES' : 'NO'}
  - If YES and this is the first calendar date (${_isoDate(tripStartDate)}), include ONE concise arrival item (airport/rail arrival + hotel transfer/check-in) at an appropriate slot (usually morning for long-haul). Keep the rest of the day light but meaningful; avoid heavy back-to-back marquee activities immediately after arrival.
  - If YES and this is the final calendar date (${_isoDate(tripEndDate)}), include ONE concise departure item (transfer to airport/rail, buffer) at an appropriate slot (often afternoon/evening). Keep that day lighter and avoid late-night commitments.

  Final-day and revisit logic:
  - If the same base appears earlier in the trip, you MUST NOT repeat previously scheduled highlights, restaurants, or signature venues. Switch to a different neighborhood and new experiences.
  - If returning to a previously visited base solely for departure, keep the day light (last-minute neighborhood stroll, light shopping, lunch) and include a departure buffer.

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
        temperature: 0.5,
      ),
    );
    final text = _safeAggregateText(resp);
    final json = _decodeTolerantJson(text);
    final out = (json['days'] as List?)?.cast<Map<String, dynamic>>() ??
        <Map<String, dynamic>>[];

    final byDate = {for (final d in out) (d['date'] ?? '').toString(): d};
    final normalized = <Map<String, dynamic>>[];
    for (final d in dates) {
      final obj = byDate[d] ??
          {
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

  // Replace generic meal placeholders with real, named venues using a light repair prompt.
  Future<void> _ensureNamedVenues({
    required GenerativeModel model,
    required String destination,
    required String affordability,
    required String? dietaryPreference,
    required List<Map<String, dynamic>> allDays,
    required List<_Segment> segs,
  }) async {
    if (allDays.isEmpty) return;

    String baseForDate(String iso) {
      final d = DateTime.tryParse(iso);
      if (d == null) return '';
      for (final s in segs) {
        if (!d.isBefore(s.start) && !d.isAfter(s.end)) return s.base;
      }
      return '';
    }

    bool isMeal(String tod) {
      final t = tod.toLowerCase();
      return t == 'breakfast' || t == 'lunch' || t == 'dinner';
    }

    bool isGenericTitle(String title) {
      if (title.trim().isEmpty) return true;
      final low = title.toLowerCase();
      // Likely-generic telltales
      const genericTokens = [
        'restaurant',
        'cafe',
        'coffee shop',
        'local',
        'street food',
        'food court',
        'eatery',
        'diner',
        'breakfast',
        'lunch',
        'dinner',
        'market',
        'stall',
        'canteen'
      ];
      if (genericTokens.any((t) => low.contains(t))) return true;
      // If it's too short and a single word, probably not a proper venue (risk false negatives for e.g., "Ichiran", but we prefer repair)
      if (!title.contains(' ') && title.length <= 4) return true;
      return false;
    }

    // Gather already used venue names to avoid repeats across the trip
    final used = <String>{};
    for (final day in allDays) {
      final acts = (day['activities'] as List?)?.cast<Map<String, dynamic>>() ??
          const [];
      for (final a in acts) {
        final tod = (a['timeOfDay'] ?? '').toString();
        if (isMeal(tod)) {
          final title = (a['title'] ?? '').toString().trim();
          if (title.isNotEmpty) used.add(title.toLowerCase());
        }
      }
    }

    Future<void> repairDay(int index) async {
      final day = allDays[index];
      final iso = (day['date'] ?? '').toString();
      final base = baseForDate(iso);
      final activities =
          (day['activities'] as List?)?.cast<Map<String, dynamic>>() ??
              <Map<String, dynamic>>[];
      if (activities.isEmpty) return;

      bool needsRepair = false;
      for (final a in activities) {
        final tod = (a['timeOfDay'] ?? '').toString();
        if (isMeal(tod)) {
          final title = (a['title'] ?? '').toString();
          if (isGenericTitle(title)) {
            needsRepair = true;
            break;
          }
        }
      }
      if (!needsRepair) return;

      final budget = affordability;
      final diet =
          (dietaryPreference == null || dietaryPreference.trim().isEmpty)
              ? 'None'
              : dietaryPreference.trim();

      final inputDay = jsonEncode({
        'date': day['date'],
        'title': day['title'],
        'summary': day['summary'],
        'activities': activities,
      });
      final usedNamesList = used.toList();

      final prompt = '''
System: You are a meticulous fixer. You will receive one day object from an itinerary.
Task: Replace ONLY the meal entries (timeOfDay is "breakfast", "lunch", or "dinner") that are generic with REAL, NAMED restaurants/cafés in "$base" (within $destination). Keep all non-meal activities unchanged.

Strict rules:
- For each meal, set:
  - title: the venue's proper name (discoverable on Google Maps), not a generic description.
  - location: the neighborhood/district (e.g., "Gangnam", "Shibuya"), NOT the city name.
  - notes: 1 short line with a signature dish/ambience/booking tip; avoid repeating diet labels.
  - cost: keep as-is or set to "\$\$"; do not use price ranges.
- Preserve the number of activities and their order. Do not add/remove activities.
- Preserve the exact timeOfDay values and keep all fields for non-meal activities unchanged.
- Avoid any restaurant names already used in the trip: ${usedNamesList.take(18).join(', ')}.
- Match budget: $budget. Dietary: $diet.
- Output ONLY JSON for the updated day object with this schema: {"date": string, "title": string, "summary": string, "activities": [ {"timeOfDay": string, "title": string, "location": string, "notes": string, "cost": string} ]}

Day to fix:
$inputDay
''';

      try {
        final resp = await model.generateContent(
          [Content.text(prompt)],
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0,
          ),
        );
        final text = _safeAggregateText(resp);
        final json = _decodeTolerantJson(text);
        final fixedActs =
            (json['activities'] as List?)?.cast<Map<String, dynamic>>();
        if (fixedActs == null || fixedActs.length != activities.length) {
          debugPrint(
              '[ItineraryAIService] Meal repair rejected: invalid length for $iso');
          return;
        }
        // Final sanitize: mark paid costs and update used names
        for (int i = 0; i < fixedActs.length; i++) {
          final a = fixedActs[i];
          final tod = (a['timeOfDay'] ?? '').toString();
          if (isMeal(tod)) {
            final title = (a['title'] ?? '').toString().trim();
            if (title.isNotEmpty) used.add(title.toLowerCase());
            // normalize cost badge now (restaurants are paid)
            a['cost'] = _paidBadge;
          }
        }
        day['activities'] = fixedActs;
      } catch (e, st) {
        debugPrint('[ItineraryAIService] Meal repair error on $iso: $e');
        debugPrint('[ItineraryAIService] Stack: $st');
      }
    }

    // Iterate and repair days that need it. We keep it sequential to avoid quota spikes.
    for (int i = 0; i < allDays.length; i++) {
      await repairDay(i);
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
