import 'project_storage.dart';
import '../services/memory_file_store.dart';

ProjectStorage createProjectStorage() => _UnsupportedProjectStorage();

class _UnsupportedProjectStorage implements ProjectStorage {
  @override
  final assets = MemoryFileStore();
  @override
  Future<void> loadAssets() async {}
  @override
  bool get supportsLocalFolder => false;

  Future<Never> _unsupported() =>
      Future.error(UnsupportedError('この環境ではプロジェクト連携を利用できません'));

  @override
  Future<ProjectSnapshot?> openLocalFolder() => _unsupported();
  @override
  Future<ProjectSnapshot?> createLocalFolder(String content) => _unsupported();
  @override
  Future<ProjectSnapshot?> reconnectLocalFolder({
    bool requestPermission = false,
  }) => _unsupported();
  @override
  Future<ProjectSnapshot> readLocalFolder() => _unsupported();
  @override
  Future<ProjectSnapshot> write(
    ProjectTarget target,
    String content,
    String? expectedRevision,
  ) => _unsupported();
  @override
  Future<void> disconnect(ProjectTarget target) => _unsupported();
}
