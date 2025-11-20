import 'package:cloud_firestore/cloud_firestore.dart';

class WeatherData {
  final String city;
  final double temperature;
  final String condition;
  final String iconCode;
  final DateTime updatedAt;
  final bool isDay; // whether it's day at the location (from API)

  const WeatherData({
    required this.city,
    required this.temperature,
    required this.condition,
    required this.iconCode,
    required this.updatedAt,
    required this.isDay,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      city: json['city'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      condition: json['condition'] as String,
      iconCode: json['iconCode'] as String,
      updatedAt: json['updatedAt'] is Timestamp 
        ? (json['updatedAt'] as Timestamp).toDate() 
        : DateTime.parse(json['updatedAt'] as String),
      isDay: (json['isDay'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'city': city,
      'temperature': temperature,
      'condition': condition,
      'iconCode': iconCode,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDay': isDay,
    };
  }

  WeatherData copyWith({
    String? city,
    double? temperature,
    String? condition,
    String? iconCode,
    DateTime? updatedAt,
    bool? isDay,
  }) {
    return WeatherData(
      city: city ?? this.city,
      temperature: temperature ?? this.temperature,
      condition: condition ?? this.condition,
      iconCode: iconCode ?? this.iconCode,
      updatedAt: updatedAt ?? this.updatedAt,
      isDay: isDay ?? this.isDay,
    );
  }
}