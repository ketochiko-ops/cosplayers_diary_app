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
    this.genreId,
    String? characterId,
    List<String>? characterIds,
    this.memo = '',
    this.archived = false,
  }) : characterIds = List.unmodifiable(
         characterIds ?? (characterId == null ? const [] : [characterId]),
       ),
       assert(
         isGeneral ||
             characterId != null ||
             (characterIds?.isNotEmpty ?? false),
       );
  final String id;
  final String name;
  final bool isGeneral;

  /// Null only for legacy costumes that were not scoped to a genre.
  final String? genreId;
  final List<String> characterIds;

  /// Legacy single-owner view, used only when reading older integrations.
  String? get characterId => characterIds.firstOrNull;
  final String memo;
  final bool archived;

  Costume copyWith({String? name, String? memo, bool? archived}) => Costume(
    id: id,
    name: name ?? this.name,
    isGeneral: isGeneral,
    genreId: genreId,
    characterIds: characterIds,
    memo: memo ?? this.memo,
    archived: archived ?? this.archived,
  );
}
