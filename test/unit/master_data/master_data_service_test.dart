import 'package:cosplayers_diary/features/master_data/domain/master_models.dart';
import 'package:cosplayers_diary/features/master_data/domain/master_service.dart';
import 'package:cosplayers_diary/features/master_data/application/master_data_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = MasterDataService();
  final genres = [
    const Genre(id: 'g1', name: '作品A'),
    const Genre(id: 'g2', name: '作品B'),
  ];
  final characters = [
    const CosplayCharacter(id: 'c1', genreId: 'g1', name: '主人公'),
    const CosplayCharacter(id: 'c2', genreId: 'g2', name: 'ライバル'),
    const CosplayCharacter(
      id: 'c3',
      genreId: 'g1',
      name: '旧キャラ',
      archived: true,
    ),
  ];
  final costumes = [
    Costume(id: 's1', name: '制服', isGeneral: true),
    Costume(id: 's2', name: '専用', isGeneral: false, characterId: 'c1'),
    Costume(id: 's3', name: '他キャラ専用', isGeneral: false, characterId: 'c2'),
    Costume(id: 's4', name: '旧衣装', isGeneral: true, archived: true),
  ];

  test('genre filters active characters by stable genre id', () {
    expect(
      service.charactersForGenre(characters, genres.first).map((e) => e.id),
      ['c1'],
    );
  });

  test('character sees general and own costumes only', () {
    expect(
      service.costumesForCharacter(costumes, characters.first).map((e) => e.id),
      ['s1', 's2'],
    );
  });

  test('archived masters remain resolvable for historical diary', () {
    expect(service.findCharacter(characters, 'c3')?.name, '旧キャラ');
    expect(service.activeGenres(genres).length, 2);
  });

  test('genre-scoped general and multi-character costumes use IDs', () {
    final values = [
      Costume(id: 'general', name: '制服', isGeneral: true, genreId: 'g1'),
      Costume(
        id: 'race',
        name: '勝負服',
        isGeneral: false,
        genreId: 'g1',
        characterIds: const ['c1', 'c3'],
      ),
    ];
    expect(
      service.costumesForCharacter(values, characters.first).map((e) => e.id),
      ['general', 'race'],
    );
    expect(
      service.costumesForCharacter(values, characters[1]).map((e) => e.id),
      isEmpty,
    );
  });

  test('store rejects a costume linked to characters across genres', () {
    final store = MasterDataStore();
    final first = store.addGenre('A');
    final second = store.addGenre('B');
    final a = store.addCharacter(first.id, 'Aのキャラ');
    final b = store.addCharacter(second.id, 'Bのキャラ');
    expect(
      () => store.addCostume(
        '衣装',
        isGeneral: false,
        genreId: first.id,
        characterIds: [a.id, b.id],
      ),
      throwsArgumentError,
    );
    expect(store.costumes, isEmpty);
  });
}
