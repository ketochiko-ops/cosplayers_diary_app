enum ActivityType {
  cosplay('コスプレ'),
  photographer('カメラマン'),
  other('その他');

  const ActivityType(this.label);
  final String label;
}

class DiaryEntry {
  DiaryEntry({
    required this.id,
    required this.activityDate,
    required this.activityType,
    this.genreId,
    this.characterId,
    this.costumeId,
    this.memo = '',
    this.calendarTitle = '',
    this.photoId,
    this.lensInventoryId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final DateTime activityDate;
  final ActivityType activityType;
  final String? genreId;
  final String? characterId;
  final String? costumeId;
  final String memo;
  final String calendarTitle;
  final String? photoId;
  final String? lensInventoryId;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiaryEntry copyWith({
    String? id,
    DateTime? activityDate,
    ActivityType? activityType,
    String? genreId,
    String? characterId,
    String? costumeId,
    String? memo,
    String? calendarTitle,
    String? photoId,
    String? lensInventoryId,
    bool clearLens = false,
    DateTime? updatedAt,
  }) => DiaryEntry(
    id: id ?? this.id,
    activityDate: activityDate ?? this.activityDate,
    activityType: activityType ?? this.activityType,
    genreId: genreId ?? this.genreId,
    characterId: characterId ?? this.characterId,
    costumeId: costumeId ?? this.costumeId,
    memo: memo ?? this.memo,
    calendarTitle: calendarTitle ?? this.calendarTitle,
    photoId: photoId ?? this.photoId,
    lensInventoryId: clearLens ? null : lensInventoryId ?? this.lensInventoryId,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
