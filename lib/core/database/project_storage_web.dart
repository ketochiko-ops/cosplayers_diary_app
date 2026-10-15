import 'dart:js_interop';

import 'project_storage.dart';

@JS('cosplayProjectStorage.supportsLocalFile')
external bool get _supportsLocalFile;

@JS('cosplayProjectStorage.openLocalFile')
external JSPromise<JSString?> _openLocalFile();

@JS('cosplayProjectStorage.createLocalFile')
external JSPromise<JSString?> _createLocalFile(JSString content);

@JS('cosplayProjectStorage.reconnectLocalFile')
external JSPromise<JSString?> _reconnectLocalFile(JSBoolean requestPermission);

@JS('cosplayProjectStorage.readLocalFile')
external JSPromise<JSString> _readLocalFile();

@JS('cosplayProjectStorage.writeLocalFile')
external JSPromise<JSString> _writeLocalFile(
  JSString content,
  JSString expectedRevision,
);

@JS('cosplayProjectStorage.disconnectLocalFile')
external JSPromise<JSAny?> _disconnectLocalFile();

ProjectStorage createProjectStorage() => _WebProjectStorage();

class _WebProjectStorage implements ProjectStorage {
  @override
  bool get supportsLocalFile => _supportsLocalFile;

  @override
  Future<ProjectSnapshot?> openLocalFile() async =>
      _optional(await _openLocalFile().toDart);

  @override
  Future<ProjectSnapshot?> createLocalFile(String content) async =>
      _optional(await _createLocalFile(content.toJS).toDart);

  @override
  Future<ProjectSnapshot?> reconnectLocalFile({
    bool requestPermission = false,
  }) async =>
      _optional(await _reconnectLocalFile(requestPermission.toJS).toDart);

  @override
  Future<ProjectSnapshot> readLocalFile() async =>
      ProjectSnapshot.fromJson((await _readLocalFile().toDart).toDart);

  @override
  Future<ProjectSnapshot> write(
    ProjectTarget target,
    String content,
    String? expectedRevision,
  ) async {
    final result = await _writeLocalFile(
      content.toJS,
      (expectedRevision ?? '').toJS,
    ).toDart;
    return ProjectSnapshot.fromJson(result.toDart);
  }

  @override
  Future<void> disconnect(ProjectTarget target) async {
    await _disconnectLocalFile().toDart;
  }

  ProjectSnapshot? _optional(JSString? source) =>
      source == null ? null : ProjectSnapshot.fromJson(source.toDart);
}
