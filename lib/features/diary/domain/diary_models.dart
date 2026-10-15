enum ActivityType {
  cosplay('コスプレ'),
  photographer('カメラマン'),
  other('その他');

  const ActivityType(this.label);
  final String label;
}

class CosplayLook {
  const CosplayLook({
    required this.genreId,
    required this.characterId,
    required this.costumeId,
  });

  final String? genreId;
  final String? characterId;
  final String? costumeId;
}

class DiaryEntry {
  DiaryEntry({
    required this.id,
    required this.activityDate,
    required this.activityType,
    String? genreId,
    String? characterId,
    String? costumeId,
    List<CosplayLook>? looks,
    this.eventId,
    this.memo = '',
    this.calendarTitle = '',
    this.photoId,
    this.lensInventoryId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : looks = List.unmodifiable(
         looks ??
             (genreId != null || characterId != null || costumeId != null
                 ? [
                     CosplayLook(
                       genreId: genreId,
                       characterId: characterId,
                       costumeId: costumeId,
                     ),
                   ]
                 : const <CosplayLook>[]),
       ),
       genreId = looks == null ? genreId : looks.firstOrNull?.genreId,
       characterId = looks == null
           ? characterId
           : looks.firstOrNull?.characterId,
       costumeId = looks == null ? costumeId : looks.firstOrNull?.costumeId,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final DateTime activityDate;
  final ActivityType activityType;
  final String? genreId;
  final String? characterId;
  final String? costumeId;
  final List<CosplayLook> looks;
  final String? eventId;
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
    List<CosplayLook>? looks,
    String? eventId,
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
    looks:
        looks ??
        (genreId != null || characterId != null || costumeId != null
            ? [
                CosplayLook(
                  genreId: genreId ?? this.genreId,
                  characterId: characterId ?? this.characterId,
                  costumeId: costumeId ?? this.costumeId,
                ),
                ...this.looks.skip(1),
              ]
            : this.looks),
    eventId: eventId ?? this.eventId,
    memo: memo ?? this.memo,
    calendarTitle: calendarTitle ?? this.calendarTitle,
    photoId: photoId ?? this.photoId,
    lensInventoryId: clearLens ? null : lensInventoryId ?? this.lensInventoryId,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
