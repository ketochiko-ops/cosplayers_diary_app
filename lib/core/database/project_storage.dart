import 'dart:convert';

import 'project_storage_stub.dart'
    if (dart.library.js_interop) 'project_storage_web.dart'
    as platform;

enum ProjectTarget { localFile, googleDrive }

class ProjectSnapshot {
  const ProjectSnapshot({
    required this.content,
    required this.revision,
    required this.name,
  });

  final String? content;
  final String? revision;
  final String name;

  factory ProjectSnapshot.fromJson(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    return ProjectSnapshot(
      content: data['content'] as String?,
      revision: data['revision'] as String?,
      name: data['name'] as String,
    );
  }
}

abstract interface class ProjectStorage {
  bool get supportsLocalFile;
  bool get supportsGoogleDrive;

  Future<ProjectSnapshot?> openLocalFile();
  Future<ProjectSnapshot?> createLocalFile(String content);
  Future<ProjectSnapshot?> reconnectLocalFile();
  Future<ProjectSnapshot> connectGoogleDrive(String clientId);
  Future<ProjectSnapshot> createGoogleDrive(String content);
  Future<ProjectSnapshot> write(
    ProjectTarget target,
    String content,
    String? expectedRevision,
  );
  Future<void> disconnect(ProjectTarget target);
}

ProjectStorage createProjectStorage() => platform.createProjectStorage();
