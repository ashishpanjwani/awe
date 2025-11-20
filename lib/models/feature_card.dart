import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeatureCard {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final String route;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeatureCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.route,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeatureCard.fromJson(Map<String, dynamic> json) {
    return FeatureCard(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      icon: IconData(json['iconCode'] as int, fontFamily: 'MaterialIcons'),
      gradientColors: (json['gradientColors'] as List<dynamic>)
          .map((color) => Color(color as int))
          .toList(),
      route: json['route'] as String,
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
      'title': title,
      'subtitle': subtitle,
      'iconCode': icon.codePoint,
      'gradientColors': gradientColors.map((color) => color.value).toList(),
      'route': route,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  FeatureCard copyWith({
    String? id,
    String? title,
    String? subtitle,
    IconData? icon,
    List<Color>? gradientColors,
    String? route,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeatureCard(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      icon: icon ?? this.icon,
      gradientColors: gradientColors ?? this.gradientColors,
      route: route ?? this.route,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}