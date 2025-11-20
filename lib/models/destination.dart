import 'package:cloud_firestore/cloud_firestore.dart';

class Destination {
  final String id;
  final String name;
  final String country;
  final String imageUrl;
  final double rating;
  final String description;
  // Suggested ideal trip length for this destination
  final int idealDays;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Destination({
    required this.id,
    required this.name,
    required this.country,
    required this.imageUrl,
    required this.rating,
    required this.description,
    this.idealDays = 3,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      id: json['id'] as String,
      name: json['name'] as String,
      country: json['country'] as String,
      imageUrl: json['imageUrl'] as String,
      rating: (json['rating'] as num).toDouble(),
      description: json['description'] as String,
      idealDays: (json['idealDays'] is int)
          ? (json['idealDays'] as int)
          : (json['idealDays'] is num)
              ? (json['idealDays'] as num).toInt()
              : 3,
      createdAt: json['createdAt'] is Timestamp 
        ? (json['createdAt'] as Timestamp).toDate() 
        : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] is Timestamp 
        ? (json['updatedAt'] as Timestamp).toDate() 
        : DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'country': country,
      'imageUrl': imageUrl,
      'rating': rating,
      'description': description,
      'idealDays': idealDays,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Destination copyWith({
    String? id,
    String? name,
    String? country,
    String? imageUrl,
    double? rating,
    String? description,
    int? idealDays,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Destination(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      description: description ?? this.description,
      idealDays: idealDays ?? this.idealDays,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}