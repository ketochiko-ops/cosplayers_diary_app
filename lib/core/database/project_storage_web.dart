import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:convert';

import '../services/file_store.dart';

import 'project_storage.dart';

@JS('cosplayProjectStorage.supportsLocalFolder')
external bool get _supportsLocalFolder;

@JS('cosplayProjectStorage.openLocalFolder')
external JSPromise<JSString?> _openLocalFolder();

@JS('cosplayProjectStorage.createLocalFolder')
external JSPromise<JSString?> _createLocalFolder(JSString content);

@JS('cosplayProjectStorage.reconnectLocalFolder')
external JSPromise<JSString?> _reconnectLocalFolder(
  JSBoolean requestPermission,
);

@JS('cosplayProjectStorage.readLocalFolder')
external JSPromise<JSString> _readLocalFolder();

@JS('cosplayProjectStorage.writeLocalFolder')
external JSPromise<JSString> _writeLocalFolder(
  JSString content,
  JSString expectedRevision,
);

@JS('cosplayProjectStorage.disconnectLocalFolder')
external JSPromise<JSAny?> _disconnectLocalFolder();

@JS('cosplayProjectStorage.loadAssets')
external JSPromise<JSAny?> _loadAssets();
@JS('cosplayProjectStorage.saveAsset')
external JSPromise<JSAny?> _saveAsset(JSString path, JSUint8Array bytes);
@JS('cosplayProjectStorage.readAsset')
external JSPromise<JSUint8Array> _readAsset(JSString path);
@JS('cosplayProjectStorage.deleteAsset')
external JSPromise<JSAny?> _deleteAsset(JSString path);
@JS('cosplayProjectStorage.existsAsset')
external JSPromise<JSBoolean> _existsAsset(JSString path);
@JS('cosplayProjectStorage.listAssets')
external JSPromise<JSString> _listAssets();

ProjectStorage createProjectStorage() => _WebProjectStorage();

class _WebProjectStorage implements ProjectStorage {
  @override
  final FileStore assets = _WebAssets();
  @override
  Future<void> loadAssets() async {
    await _loadAssets().toDart;
  }

  @override
  bool get supportsLocalFolder => _supportsLocalFolder;

  @override
  Future<ProjectSnapshot?> openLocalFolder() async =>
      _optional(await _openLocalFolder().toDart);

  @override
  Future<ProjectSnapshot?> createLocalFolder(String content) async =>
      _optional(await _createLocalFolder(content.toJS).toDart);

  @override
  Future<ProjectSnapshot?> reconnectLocalFolder({
    bool requestPermission = false,
  }) async =>
      _optional(await _reconnectLocalFolder(requestPermission.toJS).toDart);

  @override
  Future<ProjectSnapshot> readLocalFolder() async =>
      ProjectSnapshot.fromJson((await _readLocalFolder().toDart).toDart);

  @override
  Future<ProjectSnapshot> write(
    ProjectTarget target,
    String content,
    String? expectedRevision,
  ) async {
    final result = await _writeLocalFolder(
      content.toJS,
      (expectedRevision ?? '').toJS,
    ).toDart;
    return ProjectSnapshot.fromJson(result.toDart);
  }

  @override
  Future<void> disconnect(ProjectTarget target) async {
    await _disconnectLocalFolder().toDart;
  }

  ProjectSnapshot? _optional(JSString? source) =>
      source == null ? null : ProjectSnapshot.fromJson(source.toDart);
}

class _WebAssets implements FileStore {
  @override
  Future<String> save(String relativePath, Uint8List bytes) async {
    await _saveAsset(relativePath.toJS, bytes.toJS).toDart;
    return relativePath;
  }

  @override
  Future<Uint8List> read(String relativePath) async =>
      (await _readAsset(relativePath.toJS).toDart).toDart;
  @override
  Future<void> delete(String relativePath) async {
    await _deleteAsset(relativePath.toJS).toDart;
  }

  @override
  Future<bool> exists(String relativePath) async =>
      (await _existsAsset(relativePath.toJS).toDart).toDart;
  @override
  Future<List<String>> list(String directory) async =>
      (jsonDecode((await _listAssets().toDart).toDart) as List)
          .cast<String>()
          .where((path) => path.startsWith('$directory/'))
          .toList();
}
