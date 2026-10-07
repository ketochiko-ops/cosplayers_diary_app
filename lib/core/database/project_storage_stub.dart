import 'project_storage.dart';

ProjectStorage createProjectStorage() => _UnsupportedProjectStorage();

class _UnsupportedProjectStorage implements ProjectStorage {
  @override
  bool get supportsLocalFile => false;
  @override
  bool get supportsGoogleDrive => false;

  Future<Never> _unsupported() =>
      Future.error(UnsupportedError('この環境ではプロジェクト連携を利用できません'));

  @override
  Future<ProjectSnapshot?> openLocalFile() => _unsupported();
  @override
  Future<ProjectSnapshot?> createLocalFile(String content) => _unsupported();
  @override
  Future<ProjectSnapshot?> reconnectLocalFile() => _unsupported();
  @override
  Future<ProjectSnapshot> connectGoogleDrive(String clientId) => _unsupported();
  @override
  Future<ProjectSnapshot> createGoogleDrive(String content) => _unsupported();
  @override
  Future<ProjectSnapshot> write(
    ProjectTarget target,
    String content,
    String? expectedRevision,
  ) => _unsupported();
  @override
  Future<void> disconnect(ProjectTarget target) => _unsupported();
}
