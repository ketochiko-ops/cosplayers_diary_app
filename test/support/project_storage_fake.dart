import 'package:cosplayers_diary/core/database/project_storage.dart';
import 'package:cosplayers_diary/core/database/settings_store.dart';
import 'package:cosplayers_diary/core/services/memory_file_store.dart';

class MemorySettingsStore implements SettingsStore {
  final values = <String, String>{};
  @override
  Future<String?> readSetting(String key) async => values[key];
  @override
  Future<void> writeSetting(String key, String value) async {
    values[key] = value;
  }
}

class FakeProjectStorage implements ProjectStorage {
  @override
  final assets = MemoryFileStore();
  bool failAssets = false;
  int assetLoads = 0;
  @override
  Future<void> loadAssets() async {
    assetLoads++;
    if (failAssets) throw StateError('missing image');
  }

  String? content;
  String? revision;
  int writes = 0;
  int reads = 0;
  bool available = true;
  bool supported = true;
  bool cancel = false;
  bool permission = true;

  ProjectSnapshot get snapshot => ProjectSnapshot(
    content: content,
    revision: revision,
    name: 'project.json',
  );
  @override
  bool get supportsLocalFolder => supported;
  @override
  Future<ProjectSnapshot?> createLocalFolder(String value) async {
    if (cancel) return null;
    content = value;
    revision = value;
    available = true;
    return snapshot;
  }

  @override
  Future<ProjectSnapshot?> openLocalFolder() async => cancel ? null : snapshot;
  @override
  Future<ProjectSnapshot?> reconnectLocalFolder({
    bool requestPermission = false,
  }) async {
    if (!permission && !requestPermission) throw StateError('permission');
    if (!available) throw StateError('missing');
    return content == null ? null : snapshot;
  }

  @override
  Future<ProjectSnapshot> readLocalFolder() async {
    reads++;
    if (!available) throw StateError('missing');
    return snapshot;
  }

  @override
  Future<ProjectSnapshot> write(
    ProjectTarget target,
    String value,
    String? expectedRevision,
  ) async {
    if (!available) throw StateError('missing');
    if (revision != expectedRevision) throw StateError('conflict');
    writes++;
    content = value;
    revision = value;
    return snapshot;
  }

  @override
  Future<void> disconnect(ProjectTarget target) async {}
}
