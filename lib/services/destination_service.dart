import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
        imageUrl: 'assets/images/Santorini_Greece_white_buildings_blue_domes_null_1763050511861.jpg',
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
        imageUrl: 'assets/images/Bali_Indonesia_tropical_temple_null_1763050512830.jpg',
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
        imageUrl: 'assets/images/Kyoto_Japan_traditional_temple_null_1763050513718.jpg',
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
        imageUrl: 'assets/images/Machu_Picchu_Peru_ancient_ruins_null_1763050514532.jpg',
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
        imageUrl: 'assets/images/Iceland_landscape_northern_lights_null_1763050515394.jpg',
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
        imageUrl: 'assets/images/Swiss_Alps_mountains_snow_null_1763050516475.jpg',
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
}
