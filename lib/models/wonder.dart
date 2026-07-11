class WonderPlace {
  final String name;
  final String country;
  final String region;
  final double lat;
  final double lon;

  const WonderPlace({
    required this.name,
    required this.country,
    required this.region,
    required this.lat,
    required this.lon,
  });

  factory WonderPlace.fromJson(Map<String, dynamic> json) {
    return WonderPlace(
      name: (json['name'] as String?) ?? '',
      country: (json['country'] as String?) ?? '',
      region: (json['region'] as String?) ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'country': country,
        'region': region,
        'lat': lat,
        'lon': lon,
      };
}

class Wonder {
  final String id;
  final String status;
  final String category;
  final String emotion;
  final String title;
  final String subtitle;
  final String story;
  final String curiositySpark;
  final WonderPlace place;
  final String imageUrl;
  final String imageAttribution;
  final List<String> tags;
  final List<String> relatedWonderIds;
  final DateTime createdAt;

  const Wonder({
    required this.id,
    this.status = 'ready',
    required this.category,
    required this.emotion,
    required this.title,
    required this.subtitle,
    required this.story,
    required this.curiositySpark,
    required this.place,
    this.imageUrl = '',
    this.imageAttribution = '',
    this.tags = const [],
    this.relatedWonderIds = const [],
    required this.createdAt,
  });

  factory Wonder.fromJson(Map<String, dynamic> json) {
    return Wonder(
      id: (json['id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'ready',
      category: (json['category'] as String?) ?? 'place',
      emotion: (json['emotion'] as String?) ?? 'awe',
      title: (json['title'] as String?) ?? '',
      subtitle: (json['subtitle'] as String?) ?? '',
      story: (json['story'] as String?) ?? '',
      curiositySpark: (json['curiositySpark'] as String?) ?? '',
      place: json['place'] is Map<String, dynamic>
          ? WonderPlace.fromJson(json['place'] as Map<String, dynamic>)
          : const WonderPlace(name: '', country: '', region: '', lat: 0, lon: 0),
      imageUrl: (json['imageUrl'] as String?) ?? '',
      imageAttribution: (json['imageAttribution'] as String?) ?? '',
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      relatedWonderIds:
          (json['relatedWonderIds'] as List?)?.cast<String>() ?? const [],
      createdAt: json['createdAt'] is DateTime
          ? json['createdAt'] as DateTime
          : DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        'category': category,
        'emotion': emotion,
        'title': title,
        'subtitle': subtitle,
        'story': story,
        'curiositySpark': curiositySpark,
        'place': place.toJson(),
        'imageUrl': imageUrl,
        'imageAttribution': imageAttribution,
        'tags': tags,
        'relatedWonderIds': relatedWonderIds,
        'createdAt': createdAt.toIso8601String(),
      };

  Wonder copyWith({
    String? id,
    String? status,
    String? category,
    String? emotion,
    String? title,
    String? subtitle,
    String? story,
    String? curiositySpark,
    WonderPlace? place,
    String? imageUrl,
    String? imageAttribution,
    List<String>? tags,
    List<String>? relatedWonderIds,
    DateTime? createdAt,
  }) {
    return Wonder(
      id: id ?? this.id,
      status: status ?? this.status,
      category: category ?? this.category,
      emotion: emotion ?? this.emotion,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      story: story ?? this.story,
      curiositySpark: curiositySpark ?? this.curiositySpark,
      place: place ?? this.place,
      imageUrl: imageUrl ?? this.imageUrl,
      imageAttribution: imageAttribution ?? this.imageAttribution,
      tags: tags ?? this.tags,
      relatedWonderIds: relatedWonderIds ?? this.relatedWonderIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
