import 'master_models.dart';

class MasterDataService {
  const MasterDataService();

  List<Genre> activeGenres(Iterable<Genre> values) =>
      values.where((e) => !e.archived).toList(growable: false);

  List<CosplayCharacter> charactersForGenre(
    Iterable<CosplayCharacter> values,
    Genre genre,
  ) => values
      .where((e) => !e.archived && e.genreId == genre.id)
      .toList(growable: false);

  List<Costume> costumesForCharacter(
    Iterable<Costume> values,
    CosplayCharacter character,
  ) => values
      .where(
        (e) =>
            !e.archived &&
            (e.genreIds.isEmpty || e.genreIds.contains(character.genreId)) &&
            (e.isGeneral || e.characterIds.contains(character.id)),
      )
      .toList(growable: false);

  CosplayCharacter? findCharacter(
    Iterable<CosplayCharacter> values,
    String id,
  ) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }
}
