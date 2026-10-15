import 'dart:convert';

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
    final otherGenre = masters.addGenre('別作品');
    final character = masters.addCharacter(genre.id, 'スペシャルウィーク');
    final other = masters.addCharacter(otherGenre.id, '別作品のキャラ');
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
      genreIds: [genre.id, otherGenre.id],
      characterIds: [character.id, other.id],
      tags: ['レース用', '赤'],
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
    expect(restoredMasters.genres.first.id, genre.id);
    expect(restoredMasters.genres.first.name, 'ウマ娘 プリティーダービー');
    expect(restoredMasters.characters.first.id, character.id);
    expect(restoredMasters.characters.first.name, 'スペシャルウィーク改');
    expect(restoredMasters.costumes.single.id, costume.id);
    expect(restoredMasters.costumes.single.isGeneral, isFalse);
    expect(restoredMasters.costumes.single.genreIds, [genre.id, otherGenre.id]);
    expect(restoredMasters.costumes.single.characterIds, [
      character.id,
      other.id,
    ]);
    expect(restoredMasters.costumes.single.tags, ['レース用', '赤']);
    expect(restoredDiary.entries.single.costumeId, costume.id);
  });

  test('old single-character costume JSON acquires its character genre', () {
    final masters = MasterDataStore();
    final genre = masters.addGenre('作品');
    final character = masters.addCharacter(genre.id, 'キャラ');
    final costume = masters.addCostume(
      '衣装',
      isGeneral: false,
      characterId: character.id,
    );
    final persistence = AppStatePersistence(
      store: _MemorySettingsStore(),
      masters: masters,
      diary: DiaryStore(),
      lenses: LensStore(),
    );
    final old = jsonDecode(persistence.exportJson()) as Map<String, dynamic>;
    final row = old['costumes'][0] as Map<String, dynamic>;
    row.remove('genreId');
    row.remove('genreIds');
    row.remove('characterIds');
    row.remove('tags');
    persistence.restoreJson(jsonEncode(old));
    expect(masters.costumes.single.id, costume.id);
    expect(masters.costumes.single.genreId, genre.id);
    expect(masters.costumes.single.genreIds, [genre.id]);
    expect(masters.costumes.single.characterIds, [character.id]);
    expect(masters.costumes.single.tags, isEmpty);
  });

  test(
    'deleted archived master stays absent while diary ID survives reload',
    () async {
      final settings = _MemorySettingsStore();
      final masters = MasterDataStore();
      final genre = masters.addGenre('作品');
      final character = masters.addCharacter(genre.id, 'キャラ');
      final costume = masters.addCostume('衣装', isGeneral: true);
      final diary = DiaryStore()
        ..save(
          DiaryEntry(
            id: 'diary',
            activityDate: DateTime(2026, 10, 15),
            activityType: ActivityType.cosplay,
            genreId: genre.id,
            characterId: character.id,
            costumeId: costume.id,
          ),
        );
      masters.archiveCostume(costume.id);
      masters.deleteArchivedCostume(costume.id);
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
      expect(restoredMasters.costumes, isEmpty);
      expect(restoredDiary.entries.single.costumeId, costume.id);
    },
  );

  test(
    'event master and diary link roundtrip with old JSON compatibility',
    () async {
      final settings = _MemorySettingsStore();
      final masters = MasterDataStore();
      final event = masters.addEvent('アコスタ池袋');
      final diary = DiaryStore()
        ..save(
          DiaryEntry(
            id: 'visit',
            activityDate: DateTime(2026, 10, 15),
            activityType: ActivityType.other,
            eventId: event.id,
          ),
        );
      final source = AppStatePersistence(
        store: settings,
        masters: masters,
        diary: diary,
        lenses: LensStore(),
      );
      await source.save();
      final restoredMasters = MasterDataStore();
      final restoredDiary = DiaryStore();
      final restored = AppStatePersistence(
        store: settings,
        masters: restoredMasters,
        diary: restoredDiary,
        lenses: LensStore(),
      );
      await restored.load();
      expect(restoredMasters.events.single.name, 'アコスタ池袋');
      expect(restoredDiary.entries.single.eventId, event.id);

      final old = jsonDecode(source.exportJson()) as Map<String, dynamic>;
      old.remove('events');
      (old['diary'] as List).single.remove('eventId');
      restored.restoreJson(jsonEncode(old));
      expect(restoredMasters.events, isEmpty);
      expect(restoredDiary.entries.single.eventId, isNull);
    },
  );
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
