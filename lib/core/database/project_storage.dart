import 'dart:convert';

import '../services/file_store.dart';

import 'project_storage_stub.dart'
    if (dart.library.js_interop) 'project_storage_web.dart'
    as platform;

enum ProjectTarget { localFolder }

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
  bool get supportsLocalFolder;
  FileStore get assets;
  Future<void> loadAssets();

  Future<ProjectSnapshot?> openLocalFolder();
  Future<ProjectSnapshot?> createLocalFolder(String content);
  Future<ProjectSnapshot?> reconnectLocalFolder({
    bool requestPermission = false,
  });
  Future<ProjectSnapshot> readLocalFolder();
  Future<ProjectSnapshot> write(
    ProjectTarget target,
    String content,
    String? expectedRevision,
  );
  Future<void> disconnect(ProjectTarget target);
}

ProjectStorage createProjectStorage() => platform.createProjectStorage();
