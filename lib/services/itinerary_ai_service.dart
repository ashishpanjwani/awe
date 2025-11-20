import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';

class ItineraryAIService {
  // Using Firebase AI Logic SDK (firebase_ai) — no API key needed when the app
  // is connected to your Firebase project. It uses firebase_options.dart config.
  static const String _modelName = 'gemini-2.5-flash';

  Future<Map<String, dynamic>> generateItinerary({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required String affordability,
    required List<String> travelStyles,
    required String flexibility,
    int travelers = 2,
    String pace = 'moderate', // relaxed | moderate | fast
    List<String>? mustSee, // optional user must-see spots
    String? dietaryPreference, // optional dietary preferences
  }) async {
    final days = endDate.difference(startDate).inDays + 1;
    // Initialize the Gemini Developer API backend service via Firebase AI Logic
    final model = FirebaseAI
        .googleAI()
        .generativeModel(model: _modelName);

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
      debugPrint('[ItineraryAIService] Generating itinerary for "$destination" ('
          + _isoDate(startDate) + ' -> ' + _isoDate(endDate) + '), days=' + days.toString());
      final resp = await model.generateContent(
        [Content.text(prompt)],
        // Ask the model to emit strictly JSON to reduce parsing errors.
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0,
        ),
      );

      // Prefer resp.text, but some SDK builds don't aggregate text; fall back to candidates
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

      // Some responses can include code fences or trailing prose. Extract JSON.
      final extracted = _extractBalancedTopLevelJson(text);
      var cleaned = _sanitizeJson(extracted);
      cleaned = _quoteUnquotedKeys(cleaned);

      try {
        final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
        return decoded;
      } on FormatException catch (fe) {
        debugPrint('[ItineraryAIService] jsonDecode failed, retrying with alternate extraction: $fe');
        final refExtract = _extractFirstJsonObject(text);
        var refClean = _sanitizeJson(refExtract);
        refClean = _quoteUnquotedKeys(refClean);
        final decoded = jsonDecode(refClean) as Map<String, dynamic>;
        return decoded;
      }
    } catch (e, st) {
      debugPrint('[ItineraryAIService] Generation error: $e');
      debugPrint('[ItineraryAIService] Stack: $st');
      // As a last resort, return a minimal safe shape to avoid breaking flow
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

    // Ask for a compact but structured JSON for a day-tab timeline UI.
    // We want a single, concrete plan per day (no alternatives), with specific
    // named restaurants for breakfast, lunch, and dinner.
    // Keep strings human-friendly, concise, and localized in English.
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
  "startDate": string,           // ISO 8601 YYYY-MM-DD
  "endDate": string,             // ISO 8601 YYYY-MM-DD
  "days": [
    {
      "date": string,            // ISO 8601 YYYY-MM-DD
      "title": string,           // e.g., "Old Town and Riverfront"
      "summary": string,         // 1-2 lines intro for the day
      "activities": [
        {
          "timeOfDay": "breakfast" | "morning" | "lunch" | "afternoon" | "dinner" | "evening",
          "title": string,       // activity or meal title, e.g., "Breakfast at Indian Coffee House"
          "location": string,    // venue, landmark, or neighborhood (include area if known)
          "notes": string,       // concise tips: signature dish, reservation, highlights
          "cost": string         // e.g., "Free", "\$", "\$\$", "\$\$\$"
        }
      ]
    }
  ],
  "tips": [string]               // 3-5 short helpful tips
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

  // Extract the first top-level JSON object from a string (handles code fences)
  String _extractFirstJsonObject(String raw) {
    final s = raw
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      return s; // fall back to original; will fail and surface error
    }
    return s.substring(start, end + 1);
  }

  // Extract a balanced top-level JSON object by scanning braces
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
    // fallback to first/last brace heuristic
    return _extractFirstJsonObject(s);
  }

  // Best-effort cleanup for common JSON issues from LLMs
  String _sanitizeJson(String input) {
    var out = input;
    // Remove JavaScript-style comments if any
    out = out.replaceAll(RegExp(r"//.*"), '');
    // Replace smart quotes with normal quotes
    out = out
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('’', "'");
    // Remove trailing commas before } or ]
    out = out.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
    // Collapse whitespace around colons
    out = out.replaceAll(RegExp(r'\s*:\s*'), ': ');
    // Ensure valid UTF-8
    out = utf8.decode(utf8.encode(out));
    return out.trim();
  }

  // Quote unquoted JSON object keys: foo: "bar" => "foo": "bar"
  String _quoteUnquotedKeys(String input) {
    // Heuristic regex; avoids touching already quoted keys.
    return input.replaceAllMapped(
      RegExp(r'(?<=[{,])\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s'),
      (m) => ' "${m[1]}": ',
    );
  }
}
