import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:wanderwell/data/daily_facts.dart';

/// Service that provides a single travel/place fact per day for the entire app.
///
/// Data model (Firestore):
/// - Collection: daily_facts
///   - Doc ID: yyyy-MM-dd (UTC date)
///   - Fields: { text: string, status: 'ready'|'generating'|'error', createdAt, updatedAt, model }
///
/// Concurrency: We attempt a `create` to claim the day. If another client already created
/// the doc, we read and return the existing value. If generation fails, we fall back to a
/// local fact (not persisted when offline). All errors are logged with debugPrint.
class DailyFactService {
  DailyFactService._();
  static final DailyFactService _instance = DailyFactService._();
  factory DailyFactService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _memoKey;
  String? _memoText;

  /// Returns the UTC date key as yyyy-MM-dd.
  String _utcDayKey(DateTime date) {
    final d = DateTime.utc(date.toUtc().year, date.toUtc().month, date.toUtc().day);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  /// Get today's global fact. If it doesn't exist, first client selects from bundled facts and persists it.
  Future<String> getTodayFact({bool refresh = false}) async {
    final key = _utcDayKey(DateTime.now().toUtc());
    final docRef = _db.collection('daily_facts').doc(key);

    try {
      // Fast path: in-memory memo
      if (!refresh && _memoKey == key && _memoText != null && _memoText!.isNotEmpty) {
        return _memoText!;
      }

      // Next: try Firestore cache to avoid unnecessary server reads/writes
      if (!refresh) {
        try {
          final cached = await docRef.get(const GetOptions(source: Source.cache));
          if (cached.exists) {
            final cdata = cached.data() ?? {};
            final ctext = (cdata['text'] as String?)?.trim();
            if (ctext != null && ctext.isNotEmpty) {
              _memoKey = key;
              _memoText = ctext;
              return ctext;
            }
          }
        } catch (_) {
          // ignore cache miss errors
        }

        // Server read
        final snap = await docRef.get();
        if (snap.exists) {
          final data = snap.data() ?? {};
          final text = (data['text'] as String?)?.trim();
          if (text != null && text.isNotEmpty) {
            _memoKey = key;
            _memoText = text;
            return text;
          }
        }
      }

      // Try to claim the day by creating a placeholder doc via transaction.
      var claimed = false;
      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) {
          tx.set(docRef, {
            'status': 'selecting',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          claimed = true;
        }
      });
      if (!claimed) {
        // Someone else is generating/has generated. Read and return.
        final existing = await docRef.get();
        final data = existing.data() ?? {};
        final text = (data['text'] as String?)?.trim();
        if (text != null && text.isNotEmpty) {
          _memoKey = key;
          _memoText = text;
          return text;
        }
        // Small wait then recheck once in case writer is finishing up.
        await Future.delayed(const Duration(milliseconds: 900));
        final retry = await docRef.get();
        final rdata = retry.data() ?? {};
        final rtext = (rdata['text'] as String?)?.trim();
        if (rtext != null && rtext.isNotEmpty) {
          _memoKey = key;
          _memoText = rtext;
          return rtext;
        }
        // Fall through to local deterministic pick (not persisted)
        debugPrint('[DailyFact] Existing doc empty; falling back temporarily');
        return _selectForDay(DateTime.now().toUtc());
      }

      // We own the claim: select and persist.
      final toWrite = _selectForDay(DateTime.now().toUtc());
      await docRef.set({
        'text': toWrite,
        'status': 'ready',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[DailyFact] Stored fact for $key (${toWrite.length} chars)');
      _memoKey = key;
      _memoText = toWrite;
      return toWrite;
    } on FirebaseException catch (e, st) {
      debugPrint('[DailyFact] Firestore error: ${e.code} ${e.message}');
      debugPrint('$st');
      // When offline/unavailable, try cache
      try {
        final snap = await docRef.get(const GetOptions(source: Source.cache));
        if (snap.exists) {
          final data = snap.data() ?? {};
          final text = (data['text'] as String?)?.trim();
          if (text != null && text.isNotEmpty) return text;
        }
      } catch (_) {}
      return _selectForDay(DateTime.now().toUtc());
    } catch (e, st) {
      debugPrint('[DailyFact] Unexpected error: $e');
      debugPrint('$st');
      return _selectForDay(DateTime.now().toUtc());
    }
  }

  String _selectForDay(DateTime dayUtc) {
    // Deterministic pick for the day based on index shuffle.
    final base = DateTime.utc(2020, 1, 1);
    final days = dayUtc.difference(base).inDays;
    final rnd = Random(days);
    final pool = List<String>.from(kDailyFacts);
    final idx = rnd.nextInt(pool.length);
    return pool[idx];
  }
}
