import 'dart:js_interop';

import 'project_storage.dart';

@JS('cosplayProjectStorage.supportsLocalFile')
external bool get _supportsLocalFile;

@JS('cosplayProjectStorage.openLocalFile')
external JSPromise<JSString?> _openLocalFile();

@JS('cosplayProjectStorage.createLocalFile')
external JSPromise<JSString?> _createLocalFile(JSString content);

@JS('cosplayProjectStorage.reconnectLocalFile')
external JSPromise<JSString?> _reconnectLocalFile();

@JS('cosplayProjectStorage.connectGoogleDrive')
external JSPromise<JSString> _connectGoogleDrive(JSString clientId);

@JS('cosplayProjectStorage.createGoogleDrive')
external JSPromise<JSString> _createGoogleDrive(JSString content);

@JS('cosplayProjectStorage.writeLocalFile')
external JSPromise<JSString> _writeLocalFile(
  JSString content,
  JSString expectedRevision,
);

@JS('cosplayProjectStorage.writeGoogleDrive')
external JSPromise<JSString> _writeGoogleDrive(
  JSString content,
  JSString expectedRevision,
);

@JS('cosplayProjectStorage.disconnectLocalFile')
external JSPromise<JSAny?> _disconnectLocalFile();

@JS('cosplayProjectStorage.disconnectGoogleDrive')
external JSPromise<JSAny?> _disconnectGoogleDrive();

ProjectStorage createProjectStorage() => _WebProjectStorage();

class _WebProjectStorage implements ProjectStorage {
  @override
  bool get supportsLocalFile => _supportsLocalFile;
  @override
  bool get supportsGoogleDrive => true;

  @override
  Future<ProjectSnapshot?> openLocalFile() async =>
      _optional(await _openLocalFile().toDart);

  @override
  Future<ProjectSnapshot?> createLocalFile(String content) async =>
      _optional(await _createLocalFile(content.toJS).toDart);

  @override
  Future<ProjectSnapshot?> reconnectLocalFile() async =>
      _optional(await _reconnectLocalFile().toDart);

  @override
  Future<ProjectSnapshot> connectGoogleDrive(String clientId) async =>
      ProjectSnapshot.fromJson(
        (await _connectGoogleDrive(clientId.toJS).toDart).toDart,
      );

  @override
  Future<ProjectSnapshot> createGoogleDrive(String content) async =>
      ProjectSnapshot.fromJson(
        (await _createGoogleDrive(content.toJS).toDart).toDart,
      );

  @override
  Future<ProjectSnapshot> write(
    ProjectTarget target,
    String content,
    String? expectedRevision,
  ) async {
    final result = target == ProjectTarget.localFile
        ? await _writeLocalFile(
            content.toJS,
            (expectedRevision ?? '').toJS,
          ).toDart
        : await _writeGoogleDrive(
            content.toJS,
            (expectedRevision ?? '').toJS,
          ).toDart;
    return ProjectSnapshot.fromJson(result.toDart);
  }

  @override
  Future<void> disconnect(ProjectTarget target) async {
    if (target == ProjectTarget.localFile) {
      await _disconnectLocalFile().toDart;
    } else {
      await _disconnectGoogleDrive().toDart;
    }
  }

  ProjectSnapshot? _optional(JSString? source) =>
      source == null ? null : ProjectSnapshot.fromJson(source.toDart);
}
