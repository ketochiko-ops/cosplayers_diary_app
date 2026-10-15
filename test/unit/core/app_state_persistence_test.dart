import 'package:cosplayers_diary/core/database/app_state_persistence.dart';
import 'package:cosplayers_diary/core/database/settings_store.dart';
import 'package:cosplayers_diary/features/contact_lenses/application/lens_store.dart';
import 'package:cosplayers_diary/features/diary/application/diary_store.dart';
import 'package:cosplayers_diary/features/diary/domain/diary_models.dart';
import 'package:cosplayers_diary/features/master_data/application/master_data_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'platform-neutral store preserves the native-compatible state JSON',
    () async {
      final store = _MemorySettingsStore();
      final sourceMasters = MasterDataStore()..addGenre('作品');
      final source = AppStatePersistence(
        store: store,
        masters: sourceMasters,
        diary: DiaryStore(),
        lenses: LensStore(),
      );

      await source.save();

      final restoredMasters = MasterDataStore();
      final restored = AppStatePersistence(
        store: store,
        masters: restoredMasters,
        diary: DiaryStore(),
        lenses: LensStore(),
      );
      await restored.load();

      expect(store.values, contains(AppStatePersistence.stateKey));
      expect(restoredMasters.genres.single.name, '作品');
      expect(restored.exportJson(), source.exportJson());
    },
  );

  test('master edits and costume scope survive JSON save and reload', () async {
    final settings = _MemorySettingsStore();
    final masters = MasterDataStore();
    final genre = masters.addGenre('ウマ娘');
    final character = masters.addCharacter(genre.id, 'スペシャルウィーク');
    final costume = masters.addCostume('勝負服', isGeneral: true);
    final diary = DiaryStore()
      ..save(
        DiaryEntry(
          id: 'diary-1',
          activityDate: DateTime(2026, 10, 15),
          activityType: ActivityType.cosplay,
          genreId: genre.id,
          characterId: character.id,
          costumeId: costume.id,
        ),
      );
    masters.updateGenre(genre.id, 'ウマ娘 プリティーダービー');
    masters.updateCharacter(character.id, 'スペシャルウィーク改');
    masters.updateCostume(
      costume.id,
      name: '勝負服',
      isGeneral: false,
      characterId: character.id,
    );
    await AppStatePersistence(
      store: settings,
      masters: masters,
      diary: diary,
      lenses: LensStore(),
    ).save();

    final restoredMasters = MasterDataStore();
    final restoredDiary = DiaryStore();
    await AppStatePersistence(
      store: settings,
      masters: restoredMasters,
      diary: restoredDiary,
      lenses: LensStore(),
    ).load();
    expect(restoredMasters.genres.single.id, genre.id);
    expect(restoredMasters.genres.single.name, 'ウマ娘 プリティーダービー');
    expect(restoredMasters.characters.single.id, character.id);
    expect(restoredMasters.characters.single.name, 'スペシャルウィーク改');
    expect(restoredMasters.costumes.single.id, costume.id);
    expect(restoredMasters.costumes.single.isGeneral, isFalse);
    expect(restoredMasters.costumes.single.characterId, character.id);
    expect(restoredDiary.entries.single.costumeId, costume.id);
  });
}

class _MemorySettingsStore implements SettingsStore {
  final values = <String, String>{};

  @override
  Future<String?> readSetting(String key) async => values[key];

  @override
  Future<void> writeSetting(String key, String value) async {
    values[key] = value;
  }
}
