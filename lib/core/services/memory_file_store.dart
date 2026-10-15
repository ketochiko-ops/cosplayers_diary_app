import 'dart:typed_data';

import 'file_store.dart';

class MemoryFileStore implements FileStore {
  final files = <String, Uint8List>{};
  @override
  Future<String> save(String relativePath, Uint8List bytes) async {
    files[relativePath] = Uint8List.fromList(bytes);
    return relativePath;
  }

  @override
  Future<Uint8List> read(String relativePath) async =>
      Uint8List.fromList(files[relativePath] ?? (throw StateError('画像がありません')));
  @override
  Future<bool> exists(String relativePath) async =>
      files.containsKey(relativePath);
  @override
  Future<void> delete(String relativePath) async {
    files.remove(relativePath);
  }

  @override
  Future<List<String>> list(String directory) async =>
      files.keys.where((path) => path.startsWith('$directory/')).toList();
}
