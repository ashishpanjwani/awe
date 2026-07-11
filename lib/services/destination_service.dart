import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:wanderwell/models/destination.dart';
import 'package:wanderwell/services/destination_ai_service.dart';

class DestinationService {
  static final DestinationService _instance = DestinationService._internal();
  factory DestinationService() => _instance;
  DestinationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initialize() async {
    final snapshot = await _firestore.collection('destinations').limit(1).get();
    if (snapshot.docs.isEmpty) {
      await _generateSampleDestinations();
    }
  }

  Future<List<Destination>> getPopularDestinations() async {
    try {
      // Try server first
      final snapshot = await _firestore
          .collection('destinations')
          .orderBy('rating', descending: true)
          .limit(20)
          .get();

      if (snapshot.docs.isEmpty) {
        // Auto-seed on first run, then re-read
        try {
          await _generateSampleDestinations();
          final seeded = await _firestore
              .collection('destinations')
              .orderBy('rating', descending: true)
              .limit(20)
              .get();
          return seeded.docs
              .map((doc) => Destination.fromJson({...doc.data(), 'id': doc.id}))
              .toList();
        } catch (seedErr) {
          // If seeding fails (e.g., offline), we'll fall back to cache below
          // but still log this for visibility
          // ignore: avoid_print
          print('DestinationService seed failed: $seedErr');
        }
      }

      return snapshot.docs
          .map((doc) => Destination.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } on FirebaseException catch (e) {
      // ignore: avoid_print
      print('Error fetching destinations: ${e.code} ${e.message}');
      if (e.code == 'unavailable') {
        try {
          final cacheSnap = await _firestore
              .collection('destinations')
              .orderBy('rating', descending: true)
              .limit(20)
              .get(const GetOptions(source: Source.cache));
          return cacheSnap.docs
              .map((doc) => Destination.fromJson({...doc.data(), 'id': doc.id}))
              .toList();
        } catch (cacheErr) {
          // ignore: avoid_print
          print('DestinationService cache fetch failed: $cacheErr');
        }
      }
      return [];
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching destinations (unknown): $e');
      return [];
    }
  }

  Future<Destination?> getDestinationById(String id) async {
    try {
      final doc = await _firestore.collection('destinations').doc(id).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return Destination.fromJson({...data, 'id': doc.id});
    } catch (e, st) {
      debugPrint('DestinationService getDestinationById($id) error: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Prefix search by destination name or country.
  /// Returns up to [limit] items that start with the provided [query]
  /// (case-insensitive). Falls back to cache when offline.
  Future<List<Destination>> searchDestinations(String query, {int limit = 8}) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim();
    final start = q;
    final end = '$q\uf8ff';

    try {
      // Search by name
      final byName = await _firestore
          .collection('destinations')
          .orderBy('name')
          .startAt([start])
          .endAt([end])
          .limit(limit)
          .get();

      // Search by country (merge distinct results)
      final byCountry = await _firestore
          .collection('destinations')
          .orderBy('country')
          .startAt([start])
          .endAt([end])
          .limit(limit)
          .get();

      final Map<String, Destination> merged = {};
      for (final doc in byName.docs) {
        merged[doc.id] = Destination.fromJson({...doc.data(), 'id': doc.id});
      }
      for (final doc in byCountry.docs) {
        merged[doc.id] = Destination.fromJson({...doc.data(), 'id': doc.id});
      }

      return merged.values.take(limit).toList();
    } on FirebaseException catch (e) {
      // Try cache when offline
      // ignore: avoid_print
      print('DestinationService search error: ${e.code} ${e.message}');
      try {
        final byName = await _firestore
            .collection('destinations')
            .orderBy('name')
            .startAt([start])
            .endAt([end])
            .limit(limit)
            .get(const GetOptions(source: Source.cache));
        final byCountry = await _firestore
            .collection('destinations')
            .orderBy('country')
            .startAt([start])
            .endAt([end])
            .limit(limit)
            .get(const GetOptions(source: Source.cache));
        final Map<String, Destination> merged = {};
        for (final doc in byName.docs) {
          merged[doc.id] = Destination.fromJson({...doc.data(), 'id': doc.id});
        }
        for (final doc in byCountry.docs) {
          merged[doc.id] = Destination.fromJson({...doc.data(), 'id': doc.id});
        }
        return merged.values.take(limit).toList();
      } catch (_) {
        return [];
      }
    } catch (_) {
      return [];
    }
  }

  Stream<List<Destination>> getPopularDestinationsStream() {
    return _firestore
        .collection('destinations')
        .orderBy('rating', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Destination.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<void> _generateSampleDestinations() async {
    final now = DateTime.now();
    final destinations = [
      Destination(
        id: 'santorini',
        name: 'Santorini',
        country: 'Greece',
        imageUrl: 'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?w=800&q=80',
        rating: 4.8,
        description: 'Beautiful island with white buildings and blue domes',
        idealDays: 4,
        createdAt: now,
        updatedAt: now,
      ),
      Destination(
        id: 'bali',
        name: 'Bali',
        country: 'Indonesia',
        imageUrl: 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800&q=80',
        rating: 4.7,
        description: 'Tropical paradise with temples and beaches',
        idealDays: 5,
        createdAt: now,
        updatedAt: now,
      ),
      Destination(
        id: 'kyoto',
        name: 'Kyoto',
        country: 'Japan',
        imageUrl: 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=800&q=80',
        rating: 4.9,
        description: 'Ancient temples and traditional culture',
        idealDays: 3,
        createdAt: now,
        updatedAt: now,
      ),
      Destination(
        id: 'machu-picchu',
        name: 'Machu Picchu',
        country: 'Peru',
        imageUrl: 'https://images.unsplash.com/photo-1526392060635-9d6019884377?w=800&q=80',
        rating: 4.8,
        description: 'Ancient Incan ruins in the mountains',
        idealDays: 3,
        createdAt: now,
        updatedAt: now,
      ),
      Destination(
        id: 'iceland',
        name: 'Iceland',
        country: 'Iceland',
        imageUrl: 'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800&q=80',
        rating: 4.6,
        description: 'Land of fire and ice with stunning landscapes',
        idealDays: 6,
        createdAt: now,
        updatedAt: now,
      ),
      Destination(
        id: 'swiss-alps',
        name: 'Swiss Alps',
        country: 'Switzerland',
        imageUrl: 'https://images.unsplash.com/photo-1531366936337-7c912a4589a7?w=800&q=80',
        rating: 4.8,
        description: 'Majestic mountains and pristine lakes',
        idealDays: 4,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final batch = _firestore.batch();
    for (final destination in destinations) {
      final docRef = _firestore.collection('destinations').doc(destination.id);
      batch.set(docRef, destination.toJson());
    }
    await batch.commit();
  }

  Future<void> addDestination(Destination destination) async {
    try {
      await _firestore.collection('destinations').doc(destination.id).set(destination.toJson());
    } catch (e) {
      print('Error adding destination: $e');
    }
  }

  Future<void> removeDestination(String id) async {
    try {
      await _firestore.collection('destinations').doc(id).delete();
    } catch (e) {
      print('Error removing destination: $e');
    }
  }

  /// Uses Gemini (firebase_ai) to produce a richer description for the given destination,
  /// persists it to Firestore if it improves on the current one, and returns the text.
  Future<String?> enrichDescriptionWithAI(Destination destination) async {
    try {
      final ai = DestinationAIService();
      debugPrint('[DestinationService] Enriching description for ${destination.name} (${destination.country})');
      final generated = await ai.generateRichDescription(
        name: destination.name,
        country: destination.country,
        typicalDays: destination.idealDays,
      );

      final current = destination.description.trim();
      // Only persist if it's meaningfully longer (or current is empty)
      final shouldPersist = current.isEmpty || generated.length >= (current.length + 60);

      if (shouldPersist) {
        debugPrint('[DestinationService] Persisting enriched description for ${destination.id}; newLen=${generated.length}, oldLen=${current.length}');
        await _firestore.collection('destinations').doc(destination.id).set({
          'description': generated,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true));
      } else {
        debugPrint('[DestinationService] Skipped persist; improvement not significant (new=${generated.length}, old=${current.length})');
      }
      return generated;
    } catch (e, st) {
      debugPrint('DestinationService enrichDescriptionWithAI error: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Streams a richer description via Gemini and emits incremental chunks.
  /// The accumulated final text will be persisted to Firestore if it
  /// meaningfully improves upon the current description.
  Stream<String> streamEnrichedDescription(Destination destination) async* {
    final ai = DestinationAIService();
    final buffer = StringBuffer();
    try {
      debugPrint('[DestinationService] Streaming enrichment for ${destination.name} (${destination.country})');
      await for (final chunk in ai.generateRichDescriptionStream(
        name: destination.name,
        country: destination.country,
        typicalDays: destination.idealDays,
      )) {
        buffer.write(chunk);
        yield chunk; // pass incremental updates to UI
      }
    } catch (e, st) {
      debugPrint('DestinationService streamEnrichedDescription error: $e');
      debugPrint('$st');
      rethrow;
    } finally {
      // Persist at the end if improved
      try {
        final generated = buffer.toString().trim();
        final current = destination.description.trim();
        final shouldPersist = generated.isNotEmpty && (current.isEmpty || generated.length >= (current.length + 60));
        if (shouldPersist) {
          debugPrint('[DestinationService] Persisting streamed description for ${destination.id}; newLen=${generated.length}, oldLen=${current.length}');
          await _firestore.collection('destinations').doc(destination.id).set({
            'description': generated,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          }, SetOptions(merge: true));
        }
      } catch (e, st) {
        debugPrint('DestinationService persist (stream) failed: $e');
        debugPrint('$st');
      }
    }
  }

  /// Emits a realistic, readable stream from a final text by chunking words.
  /// This is used on web where SDK streaming can be unreliable; it creates
  /// the same progressive experience without risking empty streams.
  Stream<String> pseudoStreamFromFullText(
    String fullText, {
    int wordsPerChunk = 22,
    int jitterMs = 30,
    int baseDelayMs = 40,
  }) async* {
    final words = fullText.split(RegExp(r'\s+'));
    final rand = math.Random();
    int i = 0;
    while (i < words.length) {
      final end = (i + wordsPerChunk).clamp(0, words.length);
      final chunk = words.sublist(i, end).join(' ');
      if (chunk.isNotEmpty) {
        yield (i == 0 ? '' : ' ') + chunk;
      }
      i = end;
      // short, slightly jittered delay to feel live
      final d = baseDelayMs + rand.nextInt(jitterMs);
      await Future.delayed(Duration(milliseconds: d));
    }
  }
}
