class Genre {
  const Genre({
    required this.id,
    required this.name,
    this.memo = '',
    this.archived = false,
  });
  final String id;
  final String name;
  final String memo;
  final bool archived;

  Genre copyWith({String? name, String? memo, bool? archived}) => Genre(
    id: id,
    name: name ?? this.name,
    memo: memo ?? this.memo,
    archived: archived ?? this.archived,
  );
}

class CosplayCharacter {
  const CosplayCharacter({
    required this.id,
    required this.genreId,
    required this.name,
    this.memo = '',
    this.lensProductIds = const [],
    this.defaultLensProductId,
    this.archived = false,
  });
  final String id;
  final String genreId;
  final String name;
  final String memo;
  final List<String> lensProductIds;
  final String? defaultLensProductId;
  final bool archived;

  CosplayCharacter copyWith({String? name, String? memo, bool? archived}) =>
      CosplayCharacter(
        id: id,
        genreId: genreId,
        name: name ?? this.name,
        memo: memo ?? this.memo,
        lensProductIds: lensProductIds,
        defaultLensProductId: defaultLensProductId,
        archived: archived ?? this.archived,
      );
}

class Costume {
  Costume({
    required this.id,
    required this.name,
    required this.isGeneral,
    String? genreId,
    List<String>? genreIds,
    String? characterId,
    List<String>? characterIds,
    List<String> tags = const [],
    this.memo = '',
    this.archived = false,
  }) : genreIds = List.unmodifiable(
         genreIds ?? (genreId == null ? const [] : [genreId]),
       ),
       characterIds = List.unmodifiable(
         characterIds ?? (characterId == null ? const [] : [characterId]),
       ),
       tags = List.unmodifiable(tags),
       assert(
         isGeneral ||
             characterId != null ||
             (characterIds?.isNotEmpty ?? false),
       );
  final String id;
  final String name;
  final bool isGeneral;

  /// An empty list means the costume can be used in any genre.
  final List<String> genreIds;
  final List<String> characterIds;
  final List<String> tags;

  /// Legacy single-value views for older project/calendar data.
  String? get genreId => genreIds.firstOrNull;
  String? get characterId => characterIds.firstOrNull;
  String get displayName => tags.isEmpty ? name : '$name（${tags.join('・')}）';
  final String memo;
  final bool archived;

  Costume copyWith({String? name, String? memo, bool? archived}) => Costume(
    id: id,
    name: name ?? this.name,
    isGeneral: isGeneral,
    genreIds: genreIds,
    characterIds: characterIds,
    tags: tags,
    memo: memo ?? this.memo,
    archived: archived ?? this.archived,
  );
}
