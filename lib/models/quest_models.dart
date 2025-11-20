import 'package:cloud_firestore/cloud_firestore.dart';

class QuestOfTheMoment {
  final String title;
  final List<String> steps; // 2–3 short steps
  final String reflectionPrompt;
  final bool completed;
  final DateTime? completedAt;

  const QuestOfTheMoment({
    required this.title,
    required this.steps,
    required this.reflectionPrompt,
    this.completed = false,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'steps': steps,
        'reflectionPrompt': reflectionPrompt,
        'completed': completed,
        'completedAt': completedAt == null ? null : Timestamp.fromDate(completedAt!),
      };

  factory QuestOfTheMoment.fromJson(Map<String, dynamic> json) {
    final ts = json['completedAt'];
    return QuestOfTheMoment(
      title: (json['title'] ?? '') as String,
      steps: (json['steps'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[],
      reflectionPrompt: (json['reflectionPrompt'] ?? '') as String,
      completed: (json['completed'] ?? false) as bool,
      completedAt: ts is Timestamp
          ? ts.toDate()
          : (ts is String && ts.isNotEmpty ? DateTime.tryParse(ts) : null),
    );
  }

  QuestOfTheMoment copyWith({
    String? title,
    List<String>? steps,
    String? reflectionPrompt,
    bool? completed,
    DateTime? completedAt,
  }) =>
      QuestOfTheMoment(
        title: title ?? this.title,
        steps: steps ?? this.steps,
        reflectionPrompt: reflectionPrompt ?? this.reflectionPrompt,
        completed: completed ?? this.completed,
        completedAt: completedAt ?? this.completedAt,
      );
}

class MicroAdventure {
  final String title;
  final String description;
  final bool completed;
  final DateTime? completedAt;

  const MicroAdventure({
    required this.title,
    required this.description,
    this.completed = false,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'completed': completed,
        'completedAt': completedAt == null ? null : Timestamp.fromDate(completedAt!),
      };

  factory MicroAdventure.fromJson(Map<String, dynamic> json) {
    final ts = json['completedAt'];
    return MicroAdventure(
      title: (json['title'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      completed: (json['completed'] ?? false) as bool,
      completedAt: ts is Timestamp
          ? ts.toDate()
          : (ts is String && ts.isNotEmpty ? DateTime.tryParse(ts) : null),
    );
  }

  MicroAdventure copyWith({
    String? title,
    String? description,
    bool? completed,
    DateTime? completedAt,
  }) =>
      MicroAdventure(
        title: title ?? this.title,
        description: description ?? this.description,
        completed: completed ?? this.completed,
        completedAt: completedAt ?? this.completedAt,
      );
}

class DailyQuests {
  final String dateKey; // YYYY-MM-DD
  final QuestOfTheMoment quest;
  final MicroAdventure microAdventure;
  final DateTime createdAt;

  const DailyQuests({
    required this.dateKey,
    required this.quest,
    required this.microAdventure,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'quest': quest.toJson(),
        'microAdventure': microAdventure.toJson(),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory DailyQuests.fromJson(Map<String, dynamic> json) => DailyQuests(
        dateKey: (json['dateKey'] ?? '') as String,
        quest: QuestOfTheMoment.fromJson((json['quest'] ?? {}) as Map<String, dynamic>),
        microAdventure:
            MicroAdventure.fromJson((json['microAdventure'] ?? {}) as Map<String, dynamic>),
        createdAt: (json['createdAt'] is Timestamp)
            ? (json['createdAt'] as Timestamp).toDate()
            : DateTime.tryParse((json['createdAt'] ?? '') as String) ?? DateTime.now(),
      );
}
