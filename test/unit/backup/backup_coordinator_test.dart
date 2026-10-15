import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cosplayers_diary/core/database/app_state_persistence.dart';
import 'package:cosplayers_diary/features/backup/application/backup_coordinator.dart';
import 'package:cosplayers_diary/features/contact_lenses/application/lens_store.dart';
import 'package:cosplayers_diary/features/diary/application/diary_store.dart';
import 'package:cosplayers_diary/features/master_data/application/master_data_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/project_storage_fake.dart';

import 'package:cosplayers_diary/core/services/memory_file_store.dart';
import 'package:cosplayers_diary/features/photos/domain/photo_service.dart';

void main() {
  late AppStatePersistence persistence;
  late MasterDataStore masters;
  late BackupCoordinator backup;
  setUp(() {
    masters = MasterDataStore()..addGenre('既存');
    persistence = AppStatePersistence(
      store: MemorySettingsStore(),
      masters: masters,
      diary: DiaryStore(),
      lenses: LensStore(),
    );
    backup = BackupCoordinator(persistence);
  });

  test('new backup is plain JSON and uses the project file format', () async {
    final bytes = await backup.create();
    expect(utf8.decode(bytes), persistence.exportJson());
    expect(jsonDecode(utf8.decode(bytes)), isA<Map<String, dynamic>>());
  });

  test('malformed JSON never partially replaces existing data', () async {
    final before = persistence.exportJson();
    final invalid = before.replaceFirst(
      '"lensProducts":[]',
      '"lensProducts":[{"id":"bad"}]',
    );
    final result = await backup.restore(
      Uint8List.fromList(utf8.encode(invalid)),
    );
    expect(result.isValid, isFalse);
    expect(persistence.exportJson(), before);
  });

  test('legacy ZIP can be imported and exported again as plain JSON', () async {
    final state = persistence.exportJson().replaceFirst('既存', '移行');
    final archive = Archive()
      ..add(ArchiveFile.string('data/app_state.json', state))
      ..add(
        ArchiveFile.string(
          'manifest.json',
          jsonEncode({
            'formatVersion': 1,
            'createdAt': '2026-01-01T00:00:00Z',
            'dataCounts': <String, int>{},
            'imageCount': 0,
          }),
        ),
      );
    final result = await backup.restore(ZipEncoder().encodeBytes(archive));
    expect(result.isValid, isTrue);
    expect(masters.genres.single.name, '移行');
    expect(utf8.decode(await backup.create()), state);
  });

  test('uncompressed JSON carries image bytes to another browser', () async {
    final files = MemoryFileStore();
    const photo = PhotoRecord(
      id: 'photo-1',
      relativePath: 'images/photo-1.png',
      originalName: 'a.png',
    );
    persistence.photos.add(photo);
    await files.save(photo.relativePath, Uint8List.fromList([1, 2, 3]));
    final bytes = await BackupCoordinator(persistence, files: files).create();
    final json = jsonDecode(utf8.decode(bytes)) as Map;
    expect(json['embeddedImages'][photo.relativePath], base64Encode([1, 2, 3]));
    final secondFiles = MemoryFileStore();
    persistence.photos.clear();
    masters.genres.clear();
    final result = await BackupCoordinator(
      persistence,
      files: secondFiles,
    ).restore(bytes);
    expect(result.isValid, isTrue);
    expect(await secondFiles.read(photo.relativePath), [1, 2, 3]);
    expect(persistence.photos.single.originalName, 'a.png');
    expect(masters.genres.single.name, '既存');
    expect(persistence.exportJson(), isNot(contains('embeddedImages')));
  });

  test(
    'missing or malformed embedded images leave live data untouched',
    () async {
      final before = persistence.exportJson();
      final value = jsonDecode(before) as Map<String, dynamic>;
      value['genres'] = [
        {'id': 'new', 'name': '入れ替え候補'},
      ];
      value['photos'] = [
        {'id': 'p', 'relativePath': 'images/p.png', 'originalName': 'p.png'},
      ];
      value['embeddedImages'] = {'images/p.png': 'invalid base64 !'};
      final result = await BackupCoordinator(
        persistence,
        files: MemoryFileStore(),
      ).restore(Uint8List.fromList(utf8.encode(jsonEncode(value))));
      expect(result.isValid, isFalse);
      expect(persistence.exportJson(), before);
    },
  );

  test('unsafe image paths are rejected before any store is changed', () {
    final before = persistence.exportJson();
    final value = jsonDecode(before) as Map<String, dynamic>;
    value['photos'] = [
      {
        'id': 'p',
        'relativePath': 'images/../outside.png',
        'originalName': 'p.png',
      },
    ];
    expect(
      () => persistence.restoreJson(jsonEncode(value)),
      throwsFormatException,
    );
    expect(persistence.exportJson(), before);
  });
}
