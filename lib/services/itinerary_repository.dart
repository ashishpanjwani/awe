import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:wanderwell/models/itinerary.dart';

class ItineraryRepository {
  ItineraryRepository._();
  static final ItineraryRepository instance = ItineraryRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _userCol(String uid) =>
      _db.collection('users').doc(uid).collection('itineraries');

  Future<String> save({
    required String uid,
    required String name,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required Map<String, dynamic> data,
  }) async {
    try {
      final doc = await _userCol(uid).add({
        'name': name,
        'userId': uid,
        'destination': destination,
        'startDate': _iso(startDate),
        'endDate': _iso(endDate),
        'createdAt': FieldValue.serverTimestamp(),
        'data': data,
      });
      return doc.id;
    } catch (e) {
      debugPrint('[ItineraryRepository] save error: $e');
      rethrow;
    }
  }

  Stream<List<Itinerary>> streamForUser(String uid) {
    return _userCol(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Itinerary.fromDoc).toList());
  }

  Future<Itinerary?> get({required String uid, required String id}) async {
    try {
      final doc = await _userCol(uid).doc(id).get();
      if (!doc.exists) return null;
      return Itinerary.fromDoc(doc);
    } catch (e) {
      debugPrint('[ItineraryRepository] get error: $e');
      return null;
    }
  }

  Future<void> delete({required String uid, required String id}) async {
    try {
      await _userCol(uid).doc(id).delete();
    } catch (e) {
      debugPrint('[ItineraryRepository] delete error: $e');
      rethrow;
    }
  }

  static String _iso(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
