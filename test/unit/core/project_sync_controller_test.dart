import 'package:cosplayers_diary/core/database/app_state_persistence.dart';
import 'package:cosplayers_diary/core/database/project_storage.dart';
import 'package:cosplayers_diary/core/database/project_sync_controller.dart';
import 'package:cosplayers_diary/features/contact_lenses/application/lens_store.dart';
import 'package:cosplayers_diary/features/diary/application/diary_store.dart';
import 'package:cosplayers_diary/features/master_data/application/master_data_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/project_storage_fake.dart';

void main() {
  late MemorySettingsStore settings;
  late MasterDataStore masters;
  late AppStatePersistence persistence;
  late FakeProjectStorage files;
  late ProjectSyncController sync;

  setUp(() {
    settings = MemorySettingsStore();
    masters = MasterDataStore();
    persistence = AppStatePersistence(
      store: settings,
      masters: masters,
      diary: DiaryStore(),
      lenses: LensStore(),
    );
    files = FakeProjectStorage();
    sync = ProjectSyncController(
      persistence: persistence,
      settings: settings,
      storage: files,
    );
  });

  Future<void> connect() async {
    final snapshot = await sync.createLocalFile();
    await sync.uploadCurrent(ProjectTarget.localFile, snapshot!);
    files.writes = 0;
  }

  test(
    'initial setup and cancellation cannot enable editing without a mode',
    () async {
      expect(sync.requiresSelection, isTrue);
      files.cancel = true;
      expect(await sync.createLocalFile(), isNull);
      expect(sync.requiresSelection, isTrue);
    },
  );

  test('selected project receives every serialized change', () async {
    await connect();
    masters.addGenre('作品');
    final first = persistence.save();
    masters.addGenre('次の作品');
    await Future.wait([first, persistence.save()]);
    expect(files.content, persistence.exportJson());
    expect(files.writes, 2);
    expect(sync.requiresSelection, isFalse);
  });

  test(
    'write failure immediately requires selection and keeps cached changes',
    () async {
      await connect();
      files.available = false;
      masters.addGenre('未保存の変更');
      await persistence.save();
      expect(sync.requiresSelection, isTrue);
      expect(sync.paused, isTrue);
      expect(settings.values[AppStatePersistence.stateKey], contains('未保存の変更'));
      final replacement = await sync.createLocalFile();
      await sync.uploadCurrent(ProjectTarget.localFile, replacement!);
      expect(files.content, contains('未保存の変更'));
      expect(sync.requiresSelection, isFalse);
    },
  );

  test('read failure without an edit requires selection', () async {
    await connect();
    files.available = false;
    await sync.checkFile();
    expect(sync.requiresSelection, isTrue);
    expect(sync.message, contains('再指定'));
  });

  test('external changes are not overwritten', () async {
    await connect();
    files.content = files.revision = 'changed elsewhere';
    await sync.checkFile();
    masters.addGenre('端末側');
    await persistence.save();
    expect(sync.requiresSelection, isTrue);
    expect(files.content, 'changed elsewhere');
    expect(files.writes, 0);
  });

  test('malformed later rows do not partially replace live data', () async {
    masters.addGenre('既存');
    final before = persistence.exportJson();
    final malformed = before.replaceFirst(
      '"characters":[]',
      '"characters":[{"id":"broken"}]',
    );
    await expectLater(
      sync.useProject(
        ProjectTarget.localFile,
        ProjectSnapshot(
          content: malformed,
          revision: malformed,
          name: 'bad.json',
        ),
      ),
      throwsA(anything),
    );
    expect(persistence.exportJson(), before);
  });

  test(
    'startup resumes only an identical file with retained permission',
    () async {
      await settings.writeSetting(
        ProjectSyncController.preferenceKey,
        'localFile',
      );
      files.content = files.revision = persistence.exportJson();
      await sync.loadPreference();
      await sync.tryResumeLocalFile();
      expect(sync.requiresSelection, isFalse);
    },
  );

  test(
    'startup requires selection for a changed file or permission loss',
    () async {
      await settings.writeSetting(
        ProjectSyncController.preferenceKey,
        'localFile',
      );
      masters.addGenre('端末の変更');
      final cached = persistence.exportJson();
      files.content = files.revision = cached.replaceFirst('端末の変更', 'ファイルの変更');
      await sync.loadPreference();
      await sync.tryResumeLocalFile();
      expect(sync.requiresSelection, isTrue);
      expect(persistence.exportJson(), cached);
      files.permission = false;
      await sync.tryResumeLocalFile();
      expect(sync.requiresSelection, isTrue);
    },
  );

  test(
    'browser mode saves locally and persists across restart on Safari',
    () async {
      files.supported = false;
      await sync.useBrowserMode();
      masters.addGenre('Safari');
      await persistence.save();
      await sync.checkFile();
      expect(sync.requiresSelection, isFalse);
      expect(settings.values[AppStatePersistence.stateKey], contains('Safari'));
      expect(files.writes, 0);
      expect(files.reads, 0);
      final restarted = ProjectSyncController(
        persistence: persistence,
        settings: settings,
        storage: files,
      );
      await restarted.loadPreference();
      await restarted.tryResumeLocalFile();
      expect(restarted.browserMode, isTrue);
      expect(restarted.requiresSelection, isFalse);
    },
  );

  test(
    'switching modes retains data and ends file writes in browser mode',
    () async {
      await connect();
      await sync.useBrowserMode();
      masters.addGenre('切替後');
      await persistence.save();
      expect(files.writes, 0);
      await sync.disconnect();
      expect(sync.requiresSelection, isTrue);
      await connect();
      expect(files.content, contains('切替後'));
      expect(sync.browserMode, isFalse);
    },
  );
}
