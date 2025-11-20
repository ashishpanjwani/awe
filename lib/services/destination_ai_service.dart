import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

class DestinationAIService {
  DestinationAIService._();
  static final DestinationAIService _instance = DestinationAIService._();
  factory DestinationAIService() => _instance;

  static const String _modelName = 'gemini-2.5-flash';
  // Use only current models; Gemini 1.5 models are retired (Sep 24, 2025)
  static const List<String> _fallbackModels = <String>[
    'gemini-2.0-flash',
    'gemini-2.0-pro',
  ];

  /// Generates a friendly, readable "About" description for a destination.
  /// Output: 2–3 short paragraphs of plain text (no headings, no bullets).
  Future<String> generateRichDescription({
    required String name,
    required String country,
    int? typicalDays,
  }) async {
    final prompt = _buildPrompt(
      name: name,
      country: country,
      typicalDays: typicalDays,
    );
    try {
      debugPrint('[DestinationAIService] Requesting description for $name, $country using $_modelName');
      // Attempt 1: primary model, textual mime, moderate creativity
      String? out = await _tryGenerateText(
        modelName: _modelName,
        prompt: prompt,
        temperature: 0.6,
        maxTokens: 512,
      );

      // Attempt 2: lower temperature if empty
      out ??= await _tryGenerateText(
        modelName: _modelName,
        prompt: prompt,
        temperature: 0.2,
        maxTokens: 480,
      );

      // Attempt 3+: try a ladder of supported fallback models
      if (out == null) {
        for (final m in _fallbackModels) {
          debugPrint('[DestinationAIService] Trying fallback model: ' + m);
          out = await _tryGenerateText(
            modelName: m,
            prompt: prompt,
            temperature: 0.2,
            maxTokens: 480,
          );
          if (out != null && out.trim().isNotEmpty) break;
        }
      }

      if (out == null || out.trim().isEmpty) {
        throw Exception('Empty description response');
      }

      final cleaned = _stripFences(out).trim();
      debugPrint('[DestinationAIService] Received ${cleaned.length} chars for $name');
      return cleaned;
    } catch (e, st) {
      debugPrint('[DestinationAIService] generateRichDescription error: $e');
      debugPrint('[DestinationAIService] stack: $st');
      rethrow;
    }
  }

  Future<String?> _tryGenerateText({
    required String modelName,
    required String prompt,
    double temperature = 0.6,
    int maxTokens = 512,
  }) async {
    try {
      final model = FirebaseAI.googleAI().generativeModel(model: modelName);
      final resp = await model.generateContent(
        [Content.text(prompt)],
        generationConfig: GenerationConfig(
          // Encourage the SDK to surface plain text in resp.text
          responseMimeType: 'text/plain',
          temperature: temperature,
          maxOutputTokens: maxTokens,
        ),
      );

      // Preferred path
      final t = resp.text;
      if (t != null && t.trim().isNotEmpty) {
        return t.trim();
      }

      // Best-effort extraction from candidates for SDKs that don't aggregate text
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
          if (s.isNotEmpty) return s;
        }
      } catch (_) {
        // Ignore candidate parsing issues; we'll just return null
      }

      // Optionally log feedback if available to help diagnose safety blocks
      try {
        final dyn = resp as dynamic;
        final feedback = dyn.promptFeedback;
        if (feedback != null) {
          debugPrint('[DestinationAIService] promptFeedback: $feedback');
        }
      } catch (_) {}

      return null;
    } catch (e, st) {
      debugPrint('[DestinationAIService] _tryGenerateText($modelName) error: $e');
      debugPrint('[DestinationAIService] stack: $st');
      return null;
    }
  }

  String _buildPrompt({required String name, required String country, int? typicalDays}) {
    // Intentionally avoid prescribing trip length; the model should focus on place specifics.
    return '''
System instruction: Write a premium, modern travel "About" blurb in English. Third‑person only. Keep it informative and friendly, not hypey. Avoid second‑person (“you”). Plain text only, no headings, no bullets.

Destination: $name, $country

Write 2–3 short paragraphs (90–150 words total) that:
- Explain what the destination is known for and why it stands out.
- Highlight the feel of the place, distinctive experiences, and 2–3 signature sights or flavors.
- Prefer concrete, specific details over generic claims. Keep sentences crisp.
- Optionally close with a concise line about vibe, crowd levels, or seasonality.

Do NOT include generic statements like "X days is enough." Only mention time in context of a specific activity if it is notable (e.g., "a half‑day coastal walk"), otherwise omit duration entirely.

Return plain text only (no markdown, no lists, no titles).
''';
  }

  String _stripFences(String input) {
    var out = input;
    out = out.replaceAll('```', '');
    out = out.replaceAll('**', '');
    return out;
  }
}
