import 'package:flutter/foundation.dart';

/// Parsed, structured overview for a destination detail body.
class DestinationOverview {
  final String whyVisit;
  final String breakdownGeographyHistory;
  final String breakdownUnique;
  final String breakdownExperience;
  final String idealTripDuration;
  final List<String> keyInsights; // Expect 3
  final List<String> dontMiss; // Expect 5
  final List<String> perfectFor; // Expect 4
  final List<String> beforeYouPlan; // Expect 3

  DestinationOverview({
    required this.whyVisit,
    required this.breakdownGeographyHistory,
    required this.breakdownUnique,
    required this.breakdownExperience,
    required this.idealTripDuration,
    required this.keyInsights,
    required this.dontMiss,
    required this.perfectFor,
    required this.beforeYouPlan,
  });
}

/// Best-effort parser that takes a plain-text AI output and extracts sections
/// according to our strict outline. It’s resilient to minor formatting drift.
DestinationOverview? parseDestinationOverview(String raw) {
  try {
    if (raw.trim().isEmpty) return null;
    final text = _sanitize(raw.replaceAll('\r', '')).trim();
    final lines = text.split('\n');

    // Normalize helpers
    String norm(String s) => s.trim().toLowerCase();
    bool isHeader(String s, String keyword) => norm(s).contains(norm(keyword));

    // Section markers (with & without emoji fallbacks)
    const whyVisitKey = 'why visit';
    const insightsKey = 'key insights';
    const breakdownKey = 'the breakdown';
    const dontMissKey = "don't miss"; // handle: “Don’t Miss These” variants
    const perfectForKey = 'perfect for';
    const durationKey = 'ideal trip duration';
    const beforePlanKey = 'before you plan';

    // Sub-section headers under Breakdown
    final subGeoHist = RegExp(r'^\s*(geography\s*&\s*history)\s*$', caseSensitive: false);
    final subUnique = RegExp(r'^\s*(what\s+makes\s+it\s+unique)\s*$', caseSensitive: false);
    final subExperience = RegExp(r'^\s*(the\s+travel\s+experience)\s*$', caseSensitive: false);

    String whyVisit = '';
    final keyInsights = <String>[];
    String geoHist = '';
    String unique = '';
    String experience = '';
    final dontMiss = <String>[];
    final perfectFor = <String>[];
    String idealDuration = '';
    final beforePlan = <String>[];

    int i = 0;
    String current = '';

    String takeParagraph() {
      final buff = StringBuffer();
      while (i < lines.length) {
        final l = lines[i].trim();
        if (l.isEmpty) {
          i++;
          if (buff.isNotEmpty) break; // paragraph end on blank line
          continue;
        }
        // stop if next line looks like a new header
        final ln = norm(l);
        if (ln.contains(whyVisitKey) || ln.contains(insightsKey) ||
            ln.contains(breakdownKey) || ln.contains("don’t miss") ||
            ln.contains("don't miss") || ln.contains(perfectForKey) ||
            ln.contains(durationKey) || ln.contains(beforePlanKey) ||
            subGeoHist.hasMatch(l) || subUnique.hasMatch(l) || subExperience.hasMatch(l)) {
          break;
        }
        if (buff.isNotEmpty) buff.write(' ');
        buff.write(l);
        i++;
      }
      return buff.toString().trim();
    }

    List<String> takeListUntilNextSection({int maxItems = 10}) {
      final out = <String>[];
      while (i < lines.length && out.length < maxItems) {
        final l = lines[i].trim();
        if (l.isEmpty) {
          i++;
          if (out.isNotEmpty) break;
          continue;
        }
        final ln = norm(l);
        // stop at next known header
        if (ln.contains(whyVisitKey) || ln.contains(insightsKey) ||
            ln.contains(breakdownKey) || ln.contains("don’t miss") ||
            ln.contains("don't miss") || ln.contains(perfectForKey) ||
            ln.contains(durationKey) || ln.contains(beforePlanKey)) {
          break;
        }
        out.add(_sanitize(l.replaceAll(RegExp(r'^[•\-\d\.\)\s]+'), '').trim()));
        i++;
      }
      return out;
    }

    // Capture up to [count] paragraphs until next section header.
    List<String> takeParagraphs(int count) {
      final out = <String>[];
      for (int k = 0; k < count && i < lines.length; k++) {
        final p = takeParagraph();
        if (p.isEmpty) break;
        out.add(_sanitize(p));
      }
      return out;
    }

    while (i < lines.length) {
      final line = lines[i];
      final l = line.trim();
      final ln = norm(l);

      // Move past blank lines
      if (l.isEmpty) {
        i++;
        continue;
      }

      // Identify top-level section headers
      if (ln.contains(whyVisitKey)) {
        current = whyVisitKey;
        i++;
        // Next non-empty line(s) form a short paragraph
        whyVisit = takeParagraph();
        continue;
      }
      if (ln.contains(insightsKey)) {
        current = insightsKey;
        i++;
        final items = takeListUntilNextSection(maxItems: 6);
        // Prefer colon-form pairs like "Where it shines: ..."
        for (final item in items) {
          if (item.isEmpty) continue;
          keyInsights.add(item);
        }
        continue;
      }
      if (ln.contains(breakdownKey)) {
        current = breakdownKey;
        i++;
        // Expect three sub headers; parse each paragraph. If sub-headers are
        // missing, fall back to taking the next 3 paragraphs.
        bool anySubHeader = false;
        if (i < lines.length && subGeoHist.hasMatch(lines[i])) {
          anySubHeader = true;
          i++;
          geoHist = takeParagraph();
        }
        if (i < lines.length && subUnique.hasMatch(lines[i])) {
          anySubHeader = true;
          i++;
          unique = takeParagraph();
        }
        if (i < lines.length && subExperience.hasMatch(lines[i])) {
          anySubHeader = true;
          i++;
          experience = takeParagraph();
        }
        if (!anySubHeader) {
          final paras = takeParagraphs(3);
          if (paras.isNotEmpty) geoHist = paras[0];
          if (paras.length > 1) unique = paras[1];
          if (paras.length > 2) experience = paras[2];
        }
        continue;
      }
      if (ln.contains("don’t miss") || ln.contains("don't miss")) {
        current = dontMissKey;
        i++;
        dontMiss.addAll(takeListUntilNextSection(maxItems: 7));
        continue;
      }
      if (ln.contains(perfectForKey)) {
        current = perfectForKey;
        i++;
        final list = takeListUntilNextSection(maxItems: 8);
        if (list.length == 1 && list.first.contains(',')) {
          perfectFor.addAll(list.first.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
        } else {
          perfectFor.addAll(list);
        }
        continue;
      }
      if (ln.contains(durationKey)) {
        current = durationKey;
        i++;
        idealDuration = takeParagraph();
        continue;
      }
      if (ln.contains(beforePlanKey)) {
        current = beforePlanKey;
        i++;
        beforePlan.addAll(takeListUntilNextSection(maxItems: 6));
        continue;
      }

      // If none matched, advance to avoid infinite loop
      i++;
    }

    // Fallbacks: ensure we never return empty primary sections
    if (whyVisit.isEmpty) {
      whyVisit = 'A distinctive destination that blends regional heritage and modern experiences.';
    }
    if (geoHist.isEmpty && unique.isEmpty && experience.isEmpty) {
      geoHist = 'Set within its broader region, it carries layered history and varied landscapes.';
      unique = 'Known for recognizable sights, local culture, and memorable scenery.';
      experience = 'Travelers typically explore through key landmarks, neighborhoods, and food stops.';
    }
    // Normalize key insights to ensure 3 items
    if (keyInsights.isEmpty) {
      keyInsights.addAll([
        'Where it shines: signature highlights',
        'Explore style: walking and local transit',
        'Known for: culture and scenery',
      ]);
    } else if (keyInsights.length < 3) {
      final needed = 3 - keyInsights.length;
      final seeds = [
        'Where it shines: signature highlights',
        'Explore style: walking and local transit',
        'Known for: culture and scenery',
      ];
      for (int j = 0; j < needed; j++) {
        keyInsights.add(seeds[j]);
      }
    }

    return DestinationOverview(
      whyVisit: _sanitize(whyVisit),
      breakdownGeographyHistory: _sanitize(geoHist),
      breakdownUnique: _sanitize(unique),
      breakdownExperience: _sanitize(experience),
      idealTripDuration: _sanitize(idealDuration),
      keyInsights: keyInsights.map(_sanitize).toList(),
      dontMiss: dontMiss.map(_sanitize).toList(),
      perfectFor: perfectFor.map(_sanitize).toList(),
      beforeYouPlan: beforePlan.map(_sanitize).toList(),
    );
  } catch (e, st) {
    debugPrint('parseDestinationOverview error: $e');
    debugPrint('$st');
    return null;
  }
}

// Remove most emojis and clean up whitespace. Keep text readable and neutral.
String _sanitize(String s) {
  if (s.isEmpty) return s;
  // Common emoji ranges + dingbats etc.
  final emoji = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1F5FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
    unicode: true,
  );
  var out = s.replaceAll(emoji, '');
  // Remove leftover decorative bullets/em-dashes at start
  out = out.replaceAll(RegExp(r'^[•\-–—\s]+'), '');
  // Collapse extra spaces
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
  return out;
}
