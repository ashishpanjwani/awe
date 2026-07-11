class WonderCollection {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String category;
  final List<String> wonderIds;
  final bool isFree;
  final String coverImageUrl;

  const WonderCollection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.wonderIds,
    this.isFree = false,
    this.coverImageUrl = '',
  });

  int get wonderCount => wonderIds.length;

  factory WonderCollection.fromJson(Map<String, dynamic> json) {
    return WonderCollection(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      subtitle: (json['subtitle'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'place',
      wonderIds: (json['wonderIds'] as List?)?.cast<String>() ?? const [],
      isFree: (json['isFree'] as bool?) ?? false,
      coverImageUrl: (json['coverImageUrl'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'description': description,
        'category': category,
        'wonderIds': wonderIds,
        'isFree': isFree,
        'coverImageUrl': coverImageUrl,
      };
}
