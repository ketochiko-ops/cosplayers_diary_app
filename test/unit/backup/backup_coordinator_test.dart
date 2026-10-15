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

  test('new backup is plain JSON and uses the project file format', () {
    final bytes = backup.create();
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
    expect(utf8.decode(backup.create()), state);
  });
}
