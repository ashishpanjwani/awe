import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:wanderwell/models/wonder.dart';
import 'package:wanderwell/models/wonder_user_state.dart';

class WonderLikeCount {
  final int count;
  const WonderLikeCount(this.count);
}

class WonderUserService {
  WonderUserService._();
  static final WonderUserService _instance = WonderUserService._();
  factory WonderUserService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  WonderUserState? _cached;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference? get _stateDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('wonder_state').doc('stats');
  }

  Future<WonderUserState> getState() async {
    if (_cached != null) return _cached!;
    final doc = _stateDoc;
    if (doc == null) return const WonderUserState();

    try {
      final snap = await doc.get();
      if (snap.exists && snap.data() != null) {
        final data = snap.data()! as Map<String, dynamic>;
        _cached = WonderUserState.fromJson(data);

        // One-time migration: if engagedWonderIds key was absent in Firestore,
        // fromJson already fell back to savedWonderIds in memory. Persist that
        // so future reads don't depend on the fallback.
        if (!data.containsKey('engagedWonderIds') && _cached!.engagedWonderIds.isNotEmpty) {
          doc
              .set({'engagedWonderIds': _cached!.engagedWonderIds.toList()}, SetOptions(merge: true))
              .catchError((_) {});
        }

        return _cached!;
      }
    } catch (e) {
      debugPrint('[WonderUserService] getState error: $e');
    }
    return const WonderUserState();
  }

  /// Updates streak only. Called when the daily wonder screen loads.
  Future<void> markStreak() async {
    final doc = _stateDoc;
    if (doc == null) return;

    final today = _utcDayKey(DateTime.now().toUtc());
    var state = await getState();

    if (state.viewedDates.contains(today)) return;

    final newViewed = [...state.viewedDates, today];
    final streak = _computeStreak(state.lastViewedDate, today, state.currentStreak);
    final longest = streak > state.longestStreak ? streak : state.longestStreak;

    state = state.copyWith(
      viewedDates: newViewed,
      lastViewedDate: today,
      currentStreak: streak,
      longestStreak: longest,
    );

    _cached = state;
    try {
      await doc.set(state.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[WonderUserService] markStreak error: $e');
    }
  }

  /// Updates Atlas stats (countries, category/emotion counts, total viewed).
  /// Called on Like tap from any screen. No-ops if this wonder was already engaged.
  Future<void> markEngaged(Wonder wonder) async {
    final doc = _stateDoc;
    if (doc == null) return;

    var state = await getState();

    // Guard: only count each wonder once, even if unliked and re-liked later.
    final alreadyEngaged = state.engagedWonderIds.contains(wonder.id);

    final newEngaged = {...state.engagedWonderIds, wonder.id};

    if (alreadyEngaged) {
      // Still persist engagedWonderIds in case it wasn't in Firestore yet,
      // but don't touch counters.
      state = state.copyWith(engagedWonderIds: newEngaged);
      _cached = state;
      try {
        await doc.set({'engagedWonderIds': newEngaged.toList()}, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[WonderUserService] markEngaged error: $e');
      }
      return;
    }

    final newCountries = {...state.countriesDiscovered};
    if (wonder.place.country.isNotEmpty) {
      newCountries.add(wonder.place.country);
    }

    final newCatCounts = Map<String, int>.from(state.categoryCounts);
    newCatCounts[wonder.category] = (newCatCounts[wonder.category] ?? 0) + 1;

    final newEmoCounts = Map<String, int>.from(state.emotionCounts);
    newEmoCounts[wonder.emotion] = (newEmoCounts[wonder.emotion] ?? 0) + 1;

    state = state.copyWith(
      engagedWonderIds: newEngaged,
      totalWondersViewed: state.totalWondersViewed + 1,
      countriesDiscovered: newCountries,
      categoryCounts: newCatCounts,
      emotionCounts: newEmoCounts,
    );

    _cached = state;
    try {
      await doc.set(state.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[WonderUserService] markEngaged error: $e');
    }
  }

  Future<void> toggleSave(String wonderId) async {
    final doc = _stateDoc;
    if (doc == null) return;

    var state = await getState();
    final saved = List<String>.from(state.savedWonderIds);
    final wasLiked = saved.contains(wonderId);

    if (wasLiked) {
      saved.remove(wonderId);
    } else {
      saved.add(wonderId);
    }

    state = state.copyWith(savedWonderIds: saved);
    _cached = state;

    try {
      await doc.set({'savedWonderIds': saved}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[WonderUserService] toggleSave error: $e');
    }

    // Update global like count on the wonder document
    try {
      final wonderDoc = _db.collection('daily_wonders').doc(wonderId);
      await wonderDoc.update({
        'likeCount': FieldValue.increment(wasLiked ? -1 : 1),
      });
    } catch (e) {
      debugPrint('[WonderUserService] Global like count update error: $e');
    }
  }

  Future<int> getLikeCount(String wonderId) async {
    try {
      final doc = await _db.collection('daily_wonders').doc(wonderId).get();
      return (doc.data()?['likeCount'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  bool isWonderSaved(String wonderId) {
    return _cached?.isWonderSaved(wonderId) ?? false;
  }

  void invalidateCache() {
    _cached = null;
  }

  /// Deletes the stats document entirely, resetting all wonder data to defaults.
  Future<void> resetAllData() async {
    final doc = _stateDoc;
    if (doc == null) return;
    try {
      await doc.delete();
      _cached = null;
    } catch (e) {
      debugPrint('[WonderUserService] resetAllData error: $e');
    }
  }

  int _computeStreak(String lastViewedDate, String today, int currentStreak) {
    if (lastViewedDate.isEmpty) return 1;
    final last = DateTime.tryParse(lastViewedDate);
    final now = DateTime.tryParse(today);
    if (last == null || now == null) return 1;
    final diff = now.difference(last).inDays;
    if (diff == 1) return currentStreak + 1;
    if (diff == 0) return currentStreak;
    return 1;
  }

  String _utcDayKey(DateTime date) {
    final d = date.toUtc();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}
