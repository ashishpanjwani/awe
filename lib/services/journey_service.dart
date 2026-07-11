import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:wanderwell/models/journey.dart';

class JourneyService {
  JourneyService._();
  static final JourneyService _instance = JourneyService._();
  factory JourneyService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<Journey>? _cachedJourneys;

  Future<List<Journey>> getJourneys() async {
    if (_cachedJourneys != null) return _cachedJourneys!;

    try {
      final snap = await _db.collection('journeys').get();
      final journeys = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Journey.fromJson(data);
      }).toList();

      if (journeys.isEmpty) {
        await _seedDefaultJourneys();
        return getJourneys();
      }

      _cachedJourneys = journeys;
      return journeys;
    } catch (e) {
      debugPrint('[JourneyService] getJourneys error: $e');
      return _fallbackJourneys;
    }
  }

  Future<Journey?> getJourneyById(String id) async {
    final journeys = await getJourneys();
    try {
      return journeys.firstWhere((j) => j.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _seedDefaultJourneys() async {
    final batch = _db.batch();
    for (final j in _fallbackJourneys) {
      batch.set(_db.collection('journeys').doc(j.id), j.toJson());
    }
    try {
      await batch.commit();
      _cachedJourneys = null;
      debugPrint('[JourneyService] Seeded ${_fallbackJourneys.length} default journeys');
    } catch (e) {
      debugPrint('[JourneyService] Seed error: $e');
    }
  }

  static final _fallbackJourneys = <Journey>[
    const Journey(
      id: 'ancient_wonders_7',
      title: '7 Days of Ancient Wonders',
      description: 'From rock-carved churches to desert libraries, trace humanity\'s most enduring creations.',
      dayCount: 7,
      category: 'place',
      emotion: 'awe',
    ),
    const Journey(
      id: 'silk_road_10',
      title: 'The Silk Road in 10',
      description: 'Follow the ancient trade routes through singing deserts, forbidden cities, and hidden caravanserais.',
      dayCount: 10,
      category: 'story',
      emotion: 'mystery',
    ),
    const Journey(
      id: 'street_food_origins_7',
      title: 'Street Food Origins',
      description: 'The untold stories behind the world\'s most beloved street foods, from Bangkok to Lima.',
      dayCount: 7,
      category: 'taste',
      emotion: 'awe',
    ),
    const Journey(
      id: 'sacred_spaces_5',
      title: 'Sacred Spaces',
      description: 'Five days exploring the world\'s most profound places of worship and spiritual practice.',
      dayCount: 5,
      category: 'tradition',
      emotion: 'sacred',
    ),
    const Journey(
      id: 'sounds_of_earth_7',
      title: 'Sounds of the Earth',
      description: 'Singing sands, throat singers, whispering galleries — the world\'s most extraordinary acoustic phenomena.',
      dayCount: 7,
      category: 'sound',
      emotion: 'mystery',
    ),
  ];
}
