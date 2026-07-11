import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:wanderwell/models/wonder.dart';
import 'package:wanderwell/models/wonder_collection.dart';

class CollectionService {
  CollectionService._();
  static final CollectionService _instance = CollectionService._();
  factory CollectionService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<WonderCollection>? _cachedCollections;

  // ── Collections ─────────────────────────────────────────────────────────

  Future<List<WonderCollection>> getCollections() async {
    if (_cachedCollections != null) return _cachedCollections!;

    try {
      final snap = await _db.collection('collections').get();

      final collections = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return WonderCollection.fromJson(data);
      }).toList().reversed.toList();

      _cachedCollections = collections;
      debugPrint('[CollectionService] Loaded ${collections.length} collections');
      return collections;
    } catch (e) {
      debugPrint('[CollectionService] Firestore error: $e');
      return [];
    }
  }

  Future<WonderCollection?> getCollectionById(String id) async {
    final collections = await getCollections();
    try {
      return collections.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Wonders (from wonders/ collection ONLY) ─────────────────────────────

  Future<List<Wonder>> getWondersForCollection(WonderCollection collection) async {
    final wonderMap = <String, Wonder>{};

    if (collection.wonderIds.isNotEmpty) {
      final batches = _chunk(collection.wonderIds, 10);
      for (final batch in batches) {
        try {
          final snap = await _db
              .collection('wonders')
              .where(FieldPath.documentId, whereIn: batch)
              .get();
          for (final doc in snap.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            if (data['createdAt'] is Timestamp) {
              data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
            }
            data.remove('updatedAt');
            wonderMap[doc.id] = Wonder.fromJson(data);
          }
        } catch (e) {
          debugPrint('[CollectionService] Wonder fetch error: $e');
        }
      }
    }

    return collection.wonderIds
        .where((id) => wonderMap.containsKey(id))
        .map((id) => wonderMap[id]!)
        .toList();
  }

  Future<Wonder?> getWonderById(String id) async {
    try {
      final doc = await _db.collection('wonders').doc(id).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        data.remove('updatedAt');
        return Wonder.fromJson(data);
      }
    } catch (e) {
      debugPrint('[CollectionService] getWonderById error: $e');
    }
    return null;
  }

  // ── Wonder Trail (daily wonders timeline) ───────────────────────────────

  Future<List<Wonder>> getWonderTrail({int limit = 30}) async {
    try {
      final snap = await _db
          .collection('daily_wonders')
          .where('status', isEqualTo: 'ready')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(limit)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        data.remove('updatedAt');
        return Wonder.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('[CollectionService] Wonder trail error: $e');
      return [];
    }
  }

  /// Returns all wonder titles from the wonders/ collection (used to exclude
  /// collection topics from daily wonder generation).
  Future<List<String>> getCollectionWonderTitles() async {
    try {
      final snap = await _db.collection('wonders').get();
      return snap.docs
          .map((doc) => (doc.data()['title'] as String?)?.trim() ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[CollectionService] getCollectionWonderTitles error: $e');
      return [];
    }
  }

  void invalidateCache() => _cachedCollections = null;

  List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }
}
