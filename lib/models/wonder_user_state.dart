class WonderUserState {
  final List<String> viewedDates;
  final List<String> savedWonderIds;
  final Set<String> engagedWonderIds;
  final int currentStreak;
  final int longestStreak;
  final String lastViewedDate;
  final Set<String> countriesDiscovered;
  final Map<String, int> categoryCounts;
  final Map<String, int> emotionCounts;
  final int totalWondersViewed;
  final String notificationTime;

  const WonderUserState({
    this.viewedDates = const [],
    this.savedWonderIds = const [],
    this.engagedWonderIds = const {},
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastViewedDate = '',
    this.countriesDiscovered = const {},
    this.categoryCounts = const {},
    this.emotionCounts = const {},
    this.totalWondersViewed = 0,
    this.notificationTime = '08:30',
  });

  factory WonderUserState.fromJson(Map<String, dynamic> json) {
    final savedIds = (json['savedWonderIds'] as List?)?.cast<String>() ?? const <String>[];
    // If engagedWonderIds key is absent (old document), fall back to savedWonderIds
    // so existing users still see their atlas. The service layer writes the real field on first markEngaged.
    final engagedRaw = json['engagedWonderIds'] as List?;
    final engagedIds = (engagedRaw ?? savedIds).cast<String>().toSet();

    return WonderUserState(
      viewedDates: (json['viewedDates'] as List?)?.cast<String>() ?? const [],
      savedWonderIds: savedIds,
      engagedWonderIds: engagedIds,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      lastViewedDate: (json['lastViewedDate'] as String?) ?? '',
      countriesDiscovered:
          ((json['countriesDiscovered'] as List?) ?? const []).cast<String>().toSet(),
      categoryCounts:
          (json['categoryCounts'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
          const {},
      emotionCounts:
          (json['emotionCounts'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
          const {},
      totalWondersViewed: (json['totalWondersViewed'] as num?)?.toInt() ?? 0,
      notificationTime: (json['notificationTime'] as String?) ?? '08:30',
    );
  }

  Map<String, dynamic> toJson() => {
        'viewedDates': viewedDates,
        'savedWonderIds': savedWonderIds,
        'engagedWonderIds': engagedWonderIds.toList(),
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastViewedDate': lastViewedDate,
        'countriesDiscovered': countriesDiscovered.toList(),
        'categoryCounts': categoryCounts,
        'emotionCounts': emotionCounts,
        'totalWondersViewed': totalWondersViewed,
        'notificationTime': notificationTime,
      };

  WonderUserState copyWith({
    List<String>? viewedDates,
    List<String>? savedWonderIds,
    Set<String>? engagedWonderIds,
    int? currentStreak,
    int? longestStreak,
    String? lastViewedDate,
    Set<String>? countriesDiscovered,
    Map<String, int>? categoryCounts,
    Map<String, int>? emotionCounts,
    int? totalWondersViewed,
    String? notificationTime,
  }) {
    return WonderUserState(
      viewedDates: viewedDates ?? this.viewedDates,
      savedWonderIds: savedWonderIds ?? this.savedWonderIds,
      engagedWonderIds: engagedWonderIds ?? this.engagedWonderIds,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastViewedDate: lastViewedDate ?? this.lastViewedDate,
      countriesDiscovered: countriesDiscovered ?? this.countriesDiscovered,
      categoryCounts: categoryCounts ?? this.categoryCounts,
      emotionCounts: emotionCounts ?? this.emotionCounts,
      totalWondersViewed: totalWondersViewed ?? this.totalWondersViewed,
      notificationTime: notificationTime ?? this.notificationTime,
    );
  }

  bool isWonderSaved(String wonderId) => savedWonderIds.contains(wonderId);
}
