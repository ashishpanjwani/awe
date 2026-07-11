import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:wanderwell/models/wonder.dart';
import 'package:wanderwell/services/wonder_image_service.dart';

class WonderService {
  WonderService._();
  static final WonderService _instance = WonderService._();
  factory WonderService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _memoKey;
  Wonder? _memoWonder;
  final Map<String, List<Wonder>> _relatedCache = {};

  String _localDayKey(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  Future<Wonder> getTodayWonder({bool refresh = false}) async {
    final key = _localDayKey(DateTime.now());
    final docRef = _db.collection('daily_wonders').doc(key);

    try {
      if (!refresh && _memoKey == key && _memoWonder != null) {
        return _memoWonder!;
      }

      if (!refresh) {
        try {
          final cached = await docRef.get(const GetOptions(source: Source.cache));
          if (cached.exists) {
            final w = _parseDoc(cached, key);
            if (w != null) {
              _memoKey = key;
              _memoWonder = w;
              return w;
            }
          }
        } catch (_) {}

        final snap = await docRef.get();
        if (snap.exists) {
          final w = _parseDoc(snap, key);
          if (w != null) {
            _memoKey = key;
            _memoWonder = w;
            return w;
          }
        }
      }

      // Not found locally — delegate to Cloud Function which runs the full
      // RAG + semantic dedup + fact-check pipeline and stores the result.
      final wonder = await _generateViaCloudFunction(key);
      _memoKey = key;
      _memoWonder = wonder;
      return wonder;
    } on FirebaseException catch (e, st) {
      debugPrint('[WonderService] Firestore error: ${e.code} ${e.message}');
      debugPrint('$st');
      try {
        final snap = await docRef.get(const GetOptions(source: Source.cache));
        if (snap.exists) {
          final w = _parseDoc(snap, key);
          if (w != null) return w;
        }
      } catch (_) {}
      return _getLatestWonder();
    } catch (e, st) {
      debugPrint('[WonderService] Unexpected error: $e');
      debugPrint('$st');
      return _getLatestWonder();
    }
  }

  Future<Wonder> _generateViaCloudFunction(String dateKey) async {
    try {
      final fn = FirebaseFunctions.instance.httpsCallable(
        'generateDailyWonderOnDemand',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 300)),
      );
      await fn.call({'dateKey': dateKey});
      // CF stored the wonder in Firestore — read it back
      final snap = await _db.collection('daily_wonders').doc(dateKey).get();
      final wonder = _parseDoc(snap, dateKey);
      if (wonder != null) {
        debugPrint('[WonderService] CF generated wonder: ${wonder.title}');
        return wonder;
      }
      throw Exception('CF completed but wonder not found in Firestore');
    } catch (e, st) {
      debugPrint('[WonderService] CF generation failed: $e\n$st');
      return _getLatestWonder();
    }
  }

  Future<Wonder> enrichWithImage(Wonder wonder) async {
    if (wonder.imageUrl.isNotEmpty) return wonder;

    try {
      final query = '${wonder.place.name} ${wonder.place.country} ${wonder.category}';
      final result = await WonderImageService().fetchImage(query);
      if (result == null) return wonder;

      final enriched = wonder.copyWith(
        imageUrl: result.url,
        imageAttribution: result.attribution,
      );

      try {
        await _db.collection('daily_wonders').doc(wonder.id).update({
          'imageUrl': result.url,
          'imageAttribution': result.attribution,
        });
      } catch (_) {}

      if (_memoKey == wonder.id) _memoWonder = enriched;
      debugPrint('[WonderService] Enriched "${wonder.title}" with image');
      return enriched;
    } catch (e) {
      debugPrint('[WonderService] Image enrichment failed: $e');
      return wonder;
    }
  }

  Wonder? _parseDoc(DocumentSnapshot snap, String key) {
    if (!snap.exists) return null;
    final data = snap.data() as Map<String, dynamic>?;
    if (data == null) return null;
    if (data['status'] != 'ready') return null;
    final title = (data['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return null;
    data['id'] = key;
    if (data['createdAt'] is Timestamp) {
      data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
    }
    if (data['updatedAt'] is Timestamp) {
      data.remove('updatedAt');
    }
    return Wonder.fromJson(data);
  }

  Future<Wonder> _getLatestWonder() async {
    try {
      final snap = await _db
          .collection('daily_wonders')
          .where('status', isEqualTo: 'ready')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        final w = _parseDoc(doc, doc.id);
        if (w != null) {
          _memoKey = w.id;
          _memoWonder = w;
          debugPrint('[WonderService] Falling back to latest wonder: ${w.title}');
          return w;
        }
      }
    } catch (e) {
      debugPrint('[WonderService] _getLatestWonder failed: $e');
    }
    throw Exception('No wonders available');
  }

  Future<List<Wonder>> getRelatedWonders(Wonder wonder) async {
    if (_relatedCache.containsKey(wonder.id)) {
      return _relatedCache[wonder.id]!;
    }

    List<Wonder> results = [];

    if (wonder.relatedWonderIds.isNotEmpty) {
      for (final id in wonder.relatedWonderIds) {
        try {
          final doc = await _db.collection('daily_wonders').doc(id).get();
          if (doc.exists) {
            final w = _parseDoc(doc, id);
            if (w != null) results.add(w);
          }
        } catch (_) {}
      }
    } else {
      try {
        final snap = await _db
            .collection('daily_wonders')
            .where('status', isEqualTo: 'ready')
            .where('category', isEqualTo: wonder.category)
            .orderBy(FieldPath.documentId, descending: true)
            .limit(6)
            .get();
        for (final doc in snap.docs) {
          if (doc.id == wonder.id) continue;
          final w = _parseDoc(doc, doc.id);
          if (w != null) results.add(w);
        }
        results = results.take(5).toList();
      } catch (e) {
        debugPrint('[WonderService] Related fallback query failed: $e');
      }
    }

    _relatedCache[wonder.id] = results;
    return results;
  }
}
