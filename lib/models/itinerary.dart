import 'package:cloud_firestore/cloud_firestore.dart';

class Itinerary {
  final String id;
  final String name;
  final String userId;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final Map<String, dynamic> data; // raw itinerary payload as generated

  Itinerary({
    required this.id,
    required this.name,
    required this.userId,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.data,
  });

  factory Itinerary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final ts = d['createdAt'];
    DateTime created;
    if (ts is Timestamp) {
      created = ts.toDate();
    } else if (ts is DateTime) {
      created = ts;
    } else if (ts is String) {
      created = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }
    final sd = DateTime.tryParse(d['startDate']?.toString() ?? '');
    final ed = DateTime.tryParse(d['endDate']?.toString() ?? '');
    return Itinerary(
      id: doc.id,
      name: (d['name'] ?? '').toString(),
      userId: (d['userId'] ?? '').toString(),
      destination: (d['destination'] ?? '').toString(),
      startDate: sd ?? DateTime.now(),
      endDate: ed ?? DateTime.now(),
      createdAt: created,
      data: (d['data'] as Map<String, dynamic>? ?? <String, dynamic>{}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'userId': userId,
      'destination': destination,
      'startDate': _iso(startDate),
      'endDate': _iso(endDate),
      'createdAt': FieldValue.serverTimestamp(),
      'data': data,
    };
  }

  static String _iso(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
