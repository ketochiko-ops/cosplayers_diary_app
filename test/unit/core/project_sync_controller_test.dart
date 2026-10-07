import 'package:cosplayers_diary/core/database/app_state_persistence.dart';
import 'package:cosplayers_diary/core/database/project_storage.dart';
import 'package:cosplayers_diary/core/database/project_sync_controller.dart';
import 'package:cosplayers_diary/core/database/settings_store.dart';
import 'package:cosplayers_diary/features/contact_lenses/application/lens_store.dart';
import 'package:cosplayers_diary/features/diary/application/diary_store.dart';
import 'package:cosplayers_diary/features/master_data/application/master_data_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _MemorySettingsStore settings;
  late MasterDataStore masters;
  late AppStatePersistence persistence;
  late _FakeProjectStorage remote;
  late ProjectSyncController sync;

  setUp(() {
    settings = _MemorySettingsStore();
    masters = MasterDataStore();
    persistence = AppStatePersistence(
      store: settings,
      masters: masters,
      diary: DiaryStore(),
      lenses: LensStore(),
    );
    remote = _FakeProjectStorage();
    sync = ProjectSyncController(
      persistence: persistence,
      settings: settings,
      storage: remote,
    );
  });

  test('Drive project receives subsequent state changes', () async {
    await sync.uploadCurrent(
      ProjectTarget.googleDrive,
      const ProjectSnapshot(
        content: null,
        revision: null,
        name: 'project.json',
      ),
    );
    masters.addGenre('作品');
    await persistence.save();

    expect(remote.content, persistence.exportJson());
    expect(remote.writes, 1);
    expect(sync.paused, isFalse);
  });

  test('remote change pauses sync but keeps new local state', () async {
    await sync.uploadCurrent(
      ProjectTarget.googleDrive,
      const ProjectSnapshot(
        content: null,
        revision: null,
        name: 'project.json',
      ),
    );
    remote.revision = 'changed-on-another-device';
    masters.addGenre('端末側の変更');
    await persistence.save();

    expect(sync.paused, isTrue);
    expect(remote.writes, 0);
    expect(settings.values[AppStatePersistence.stateKey], contains('端末側の変更'));
  });

  test('invalid project does not replace live data', () async {
    masters.addGenre('既存');
    final before = persistence.exportJson();

    await expectLater(
      sync.useProject(
        ProjectTarget.googleDrive,
        const ProjectSnapshot(
          content: '{}',
          revision: '1',
          name: 'project.json',
        ),
      ),
      throwsFormatException,
    );

    expect(persistence.exportJson(), before);
  });

  test(
    'unchanged local project resumes without replacing cached state',
    () async {
      await settings.writeSetting(
        ProjectSyncController.preferenceKey,
        ProjectTarget.localFile.name,
      );
      remote.localSnapshot = ProjectSnapshot(
        content: persistence.exportJson(),
        revision: persistence.exportJson(),
        name: 'project.json',
      );

      await sync.loadPreference();
      await sync.tryResumeLocalFile();

      expect(sync.target, ProjectTarget.localFile);
      expect(sync.paused, isFalse);
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

class _FakeProjectStorage implements ProjectStorage {
  String? content;
  String? revision;
  ProjectSnapshot? localSnapshot;
  int writes = 0;

  @override
  bool get supportsGoogleDrive => true;
  @override
  bool get supportsLocalFile => true;

  @override
  Future<ProjectSnapshot> createGoogleDrive(String value) async {
    content = value;
    revision = '1';
    return ProjectSnapshot(
      content: content,
      revision: revision,
      name: 'project.json',
    );
  }

  @override
  Future<ProjectSnapshot> write(
    ProjectTarget target,
    String value,
    String? expectedRevision,
  ) async {
    if (revision != expectedRevision) throw StateError('conflict');
    writes++;
    content = value;
    revision = '${writes + 1}';
    return ProjectSnapshot(
      content: content,
      revision: revision,
      name: 'project.json',
    );
  }

  @override
  Future<ProjectSnapshot> connectGoogleDrive(String clientId) async =>
      ProjectSnapshot(
        content: content,
        revision: revision,
        name: 'project.json',
      );
  @override
  Future<ProjectSnapshot?> createLocalFile(String content) async => null;
  @override
  Future<ProjectSnapshot?> openLocalFile() async => null;
  @override
  Future<ProjectSnapshot?> reconnectLocalFile() async => localSnapshot;
  @override
  Future<void> disconnect(ProjectTarget target) async {}
}
