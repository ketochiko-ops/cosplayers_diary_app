import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cosplayers_diary/core/database/app_state_persistence.dart';
import 'package:cosplayers_diary/core/services/memory_file_store.dart';
import 'package:cosplayers_diary/features/contact_lenses/application/lens_store.dart';
import 'package:cosplayers_diary/features/diary/application/diary_store.dart';
import 'package:cosplayers_diary/features/diary/domain/diary_models.dart';
import 'package:cosplayers_diary/features/master_data/application/master_data_store.dart';
import 'package:cosplayers_diary/features/photos/application/photo_controller.dart';

import '../../support/project_storage_fake.dart';

void main() {
  test(
    'a picked image remains a draft until the diary commits its reference',
    () async {
      final settings = MemorySettingsStore()
        ..values['photo_save_mode'] = 'original';
      final persistence = AppStatePersistence(
        store: settings,
        masters: MasterDataStore(),
        diary: DiaryStore(),
        lenses: LensStore(),
      );
      final files = MemoryFileStore();
      final controller = PhotoController(
        persistence: persistence,
        files: files,
      );
      final photo = await controller.add(
        Uint8List.fromList([1, 2, 3]),
        'a.png',
        'd',
      );
      expect(persistence.photos, isEmpty);
      expect(await files.read(photo.relativePath), [1, 2, 3]);
      persistence.diary.save(
        DiaryEntry(
          id: 'd',
          activityDate: DateTime(2026, 10, 15),
          activityType: ActivityType.other,
          photoId: photo.id,
        ),
      );
      controller.retain(photo);
      final json = persistence.exportJson();
      persistence.restoreJson(json);
      expect(
        controller.find(persistence.diary.entries.single.photoId)?.relativePath,
        photo.relativePath,
      );
      expect((jsonDecode(json) as Map)['photos'], hasLength(1));
    },
  );

  test('old project JSON without a photo list loads and roundtrips safely', () {
    final persistence = AppStatePersistence(
      store: MemorySettingsStore(),
      masters: MasterDataStore(),
      diary: DiaryStore(),
      lenses: LensStore(),
    );
    final old = jsonDecode(persistence.exportJson()) as Map<String, dynamic>;
    old.remove('photos');
    old.remove('projectFormat');
    persistence.restoreJson(jsonEncode(old));
    expect(persistence.photos, isEmpty);
    expect(jsonDecode(persistence.exportJson())['projectFormat'], 2);
  });
}
