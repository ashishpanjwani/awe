class Journey {
  final String id;
  final String title;
  final String description;
  final int dayCount;
  final String coverImageUrl;
  final String category;
  final String emotion;
  final bool premium;
  final List<String> wonderIds;

  const Journey({
    required this.id,
    required this.title,
    required this.description,
    required this.dayCount,
    this.coverImageUrl = '',
    required this.category,
    required this.emotion,
    this.premium = false,
    this.wonderIds = const [],
  });

  factory Journey.fromJson(Map<String, dynamic> json) {
    return Journey(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      dayCount: (json['dayCount'] as num?)?.toInt() ?? 0,
      coverImageUrl: (json['coverImageUrl'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'story',
      emotion: (json['emotion'] as String?) ?? 'mystery',
      premium: (json['premium'] as bool?) ?? false,
      wonderIds: (json['wonderIds'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'dayCount': dayCount,
        'coverImageUrl': coverImageUrl,
        'category': category,
        'emotion': emotion,
        'premium': premium,
        'wonderIds': wonderIds,
      };
}
