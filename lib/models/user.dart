import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPremium;
  final String? subscriptionType;
  final DateTime? subscriptionExpiry;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
    this.isPremium = false,
    this.subscriptionType,
    this.subscriptionExpiry,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      photoUrl: json['photoUrl'] as String?,
      createdAt: json['createdAt'] is Timestamp
        ? (json['createdAt'] as Timestamp).toDate()
        : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] is Timestamp
        ? (json['updatedAt'] as Timestamp).toDate()
        : DateTime.parse(json['updatedAt'] as String),
      isPremium: json['isPremium'] as bool? ?? false,
      subscriptionType: json['subscriptionType'] as String?,
      subscriptionExpiry: json['subscriptionExpiry'] is Timestamp
        ? (json['subscriptionExpiry'] as Timestamp).toDate()
        : json['subscriptionExpiry'] is String
          ? DateTime.tryParse(json['subscriptionExpiry'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isPremium': isPremium,
      'subscriptionType': subscriptionType,
      'subscriptionExpiry': subscriptionExpiry != null ? Timestamp.fromDate(subscriptionExpiry!) : null,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPremium,
    String? subscriptionType,
    DateTime? subscriptionExpiry,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPremium: isPremium ?? this.isPremium,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
    );
  }
}