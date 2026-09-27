import 'package:cosplayers_diary/core/database/app_state_persistence.dart';
import 'package:cosplayers_diary/core/database/settings_store.dart';
import 'package:cosplayers_diary/features/contact_lenses/application/lens_store.dart';
import 'package:cosplayers_diary/features/diary/application/diary_store.dart';
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
