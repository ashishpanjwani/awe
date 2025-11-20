import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:wanderwell/data/world_says_hi_data.dart';
import 'package:wanderwell/models/destination.dart';

/// Provides six world entries per day for the "The World Says Hi" section.
/// Persists the selection in Firestore so all users share the same set daily.
///
/// Firestore:
/// - Collection: daily_world_cards
///   - Doc ID: yyyy-MM-dd (UTC)
///   - Fields: { items: [ { id, name, country, imageUrl } ], createdAt, updatedAt }
class DailyWorldService {
  DailyWorldService._();
  static final DailyWorldService _instance = DailyWorldService._();
  factory DailyWorldService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _memoKey;
  List<Destination>? _memoItems;

  String _utcDayKey(DateTime date) {
    final d = DateTime.utc(date.toUtc().year, date.toUtc().month, date.toUtc().day);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  /// Return today's six world entries mapped to Destination model for UI reuse.
  Future<List<Destination>> getTodayWorldDestinations({bool refresh = false}) async {
    final key = _utcDayKey(DateTime.now().toUtc());
    final docRef = _db.collection('daily_world_cards').doc(key);

    try {
      if (!refresh && _memoKey == key && _memoItems != null && _memoItems!.isNotEmpty) {
        return _memoItems!;
      }

      // Cache read
      if (!refresh) {
        try {
          final cached = await docRef.get(const GetOptions(source: Source.cache));
          if (cached.exists) {
            final items = _decodeDestinations(cached.data());
            if (items.isNotEmpty) {
              _memoKey = key;
              _memoItems = items;
              return items;
            }
          }
        } catch (_) {}

        // Server read
        final snap = await docRef.get();
        if (snap.exists) {
          final items = _decodeDestinations(snap.data());
          if (items.isNotEmpty) {
            _memoKey = key;
            _memoItems = items;
            return items;
          }
        }
      }

      // Try to claim the day
      var claimed = false;
      await _db.runTransaction((tx) async {
        final s = await tx.get(docRef);
        if (!s.exists) {
          tx.set(docRef, {
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          claimed = true;
        }
      });
      if (!claimed) {
        // Read existing selection
        final existing = await docRef.get();
        final items = _decodeDestinations(existing.data());
        if (items.isNotEmpty) {
          _memoKey = key;
          _memoItems = items;
          return items;
        }
        // Wait a bit and retry once
        await Future.delayed(const Duration(milliseconds: 800));
        final retry = await docRef.get();
        final again = _decodeDestinations(retry.data());
        if (again.isNotEmpty) {
          _memoKey = key;
          _memoItems = again;
          return again;
        }
      }

      // We own the claim or there is no valid data: select deterministically by date.
      final selected = _pickSixForDay(DateTime.now().toUtc());

      // Persist the static selection directly; URLs come from kWorldEntries.
      final payload = selected
          .map((e) => {
                'id': e.id,
                'name': e.name,
                'country': e.country,
                'imageUrl': e.imageUrl,
              })
          .toList();
      await docRef.set({
        'items': payload,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _memoKey = key;
      _memoItems = _decodeDestinations({'items': payload});
      return _memoItems!;
    } on FirebaseException catch (e, st) {
      debugPrint('[DailyWorld] Firestore error: ${e.code} ${e.message}');
      debugPrint('$st');
      // offline/cache
      try {
        final snap = await docRef.get(const GetOptions(source: Source.cache));
        if (snap.exists) {
          final items = _decodeDestinations(snap.data());
          if (items.isNotEmpty) return items;
        }
      } catch (_) {}
      // As the last resort, compute locally (not persisted)
      final fallback = _mapToDestinations(_pickSixForDay(DateTime.now().toUtc()));
      return fallback;
    } catch (e, st) {
      debugPrint('[DailyWorld] Unexpected error: $e');
      debugPrint('$st');
      return _mapToDestinations(_pickSixForDay(DateTime.now().toUtc()));
    }
  }

  List<Destination> _decodeDestinations(Map<String, dynamic>? data) {
    if (data == null) return [];
    final raw = (data['items'] as List?) ?? const [];
    final now = DateTime.now();
    return raw.map((e) {
      final m = (e as Map).cast<String, dynamic>();
      return Destination(
        id: m['id'] as String? ?? UniqueKey().toString(),
        name: m['name'] as String? ?? 'Unknown',
        country: m['country'] as String? ?? '',
        imageUrl: m['imageUrl'] as String? ?? '',
        rating: 0,
        description: '',
        idealDays: 3,
        createdAt: now,
        updatedAt: now,
      );
    }).toList();
  }

  List<WorldEntry> _pickSixForDay(DateTime dayUtc) {
    // Deterministic shuffle by UTC day to keep selection stable across users
    final base = DateTime.utc(2020, 1, 1);
    final seed = dayUtc.difference(base).inDays;
    final rnd = Random(seed);
    final pool = List<WorldEntry>.from(kWorldEntries);

    // Fisher–Yates shuffle with seeded RNG
    for (int i = pool.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final tmp = pool[i];
      pool[i] = pool[j];
      pool[j] = tmp;
    }

    final seenCountries = <String>{};
    final selected = <WorldEntry>[];

    // First pass: pick only one per country to maximize diversity
    for (final e in pool) {
      final c = e.country.trim().toLowerCase();
      if (seenCountries.add(c)) {
        selected.add(e);
        if (selected.length == 6) break;
      }
    }

    // Fallback: if dataset has < 6 unique countries, fill remaining slots
    if (selected.length < 6) {
      for (final e in pool) {
        if (!selected.contains(e)) {
          selected.add(e);
          if (selected.length == 6) break;
        }
      }
    }

    return selected.take(6).toList();
  }

  List<Destination> _mapToDestinations(List<WorldEntry> items) {
    final now = DateTime.now();
    return items
        .map((e) => Destination(
              id: e.id,
              name: e.name,
              country: e.country,
              imageUrl: e.imageUrl,
              rating: 0,
              description: '',
              idealDays: 3,
              createdAt: now,
              updatedAt: now,
            ))
        .toList();
  }
}
