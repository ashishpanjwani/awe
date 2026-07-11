class QuestCard {
  final String type;
  final String title;
  final String description;
  final String? location;
  final String? source;
  final String? actionUrl;

  const QuestCard({
    required this.type,
    required this.title,
    required this.description,
    this.location,
    this.source,
    this.actionUrl,
  });

  factory QuestCard.fromJson(Map<String, dynamic> json) {
    return QuestCard(
      type: (json['type'] as String?) ?? 'experience',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      location: json['location'] as String?,
      source: json['source'] as String?,
      actionUrl: json['actionUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'description': description,
        'location': location,
        'source': source,
        'actionUrl': actionUrl,
      };
}

class RawQuestItem {
  final String title;
  final String? snippet;
  final String? url;
  final String source;
  final String? categoryHint;

  const RawQuestItem({
    required this.title,
    this.snippet,
    this.url,
    required this.source,
    this.categoryHint,
  });
}
