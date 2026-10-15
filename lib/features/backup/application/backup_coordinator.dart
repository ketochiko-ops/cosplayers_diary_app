import 'dart:convert';

import '../../../core/database/app_state_persistence.dart';
import '../../../core/services/file_store.dart';

import 'package:flutter/foundation.dart';

import '../domain/backup_service.dart';

class BackupCoordinator {
  const BackupCoordinator(this.persistence, {this.files});
  final AppStatePersistence persistence;
  final FileStore? files;
  static const _legacyBackup = BackupService();

  /// Portable backups embed images; the autosaved project JSON keeps paths only.
  Future<Uint8List> create() async {
    final value = jsonDecode(persistence.exportJson()) as Map<String, dynamic>;
    if (persistence.photos.isNotEmpty) {
      if (files == null) throw StateError('画像の保存先が接続されていません');
      value['embeddedImages'] = <String, String>{
        for (final photo in persistence.photos)
          photo.relativePath: base64Encode(
            await files!.read(photo.relativePath),
          ),
      };
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(value)));
  }

  Future<BackupInspection> restore(Uint8List bytes) async {
    String source;
    BackupInspection result;
    try {
      if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4b) {
        result = _legacyBackup.inspect(bytes);
        if (!result.isValid) return result;
        final state = result.files['data/app_state.json'];
        if (state == null) throw const FormatException('旧ZIPにアプリ状態がありません');
        source = utf8.decode(state);
      } else {
        source = utf8.decode(bytes);
        if (source.startsWith('\uFEFF')) source = source.substring(1);
        result = BackupInspection(
          errors: const [],
          files: {'app_state.json': bytes},
        );
      }
      persistence.validateJson(source);
      final value = jsonDecode(source) as Map<String, dynamic>;
      final embedded = Map<String, dynamic>.from(value['embeddedImages'] ?? {});
      final images = <String, Uint8List>{};
      final rows = value['photos'] as List? ?? [];
      final paths = rows
          .map((photo) => photo['relativePath'] as String)
          .toSet();
      if (embedded.keys.any((path) => !paths.contains(path))) {
        throw const FormatException('画像一覧にないデータが含まれています');
      }
      for (final path in paths) {
        if (files == null) throw const FormatException('画像の保存先が利用できません');
        final bytes = embedded.containsKey(path)
            ? base64Decode(embedded[path] as String)
            : await files!.read(path);
        if (bytes.isEmpty) throw const FormatException('画像が空です');
        if (await files!.exists(path) &&
            !listEquals(await files!.read(path), bytes)) {
          throw const FormatException('同じ画像IDで内容が異なります。別の画像として登録してください');
        }
        images[path] = bytes;
      }
      // New immutable paths may remain as orphans on an I/O failure; live
      // references and existing images are never replaced before validation.
      for (final image in images.entries) {
        if (!await files!.exists(image.key)) {
          await files!.save(image.key, image.value);
        }
      }
    } catch (error) {
      return BackupInspection(
        errors: ['プロジェクトを読み込めません: $error'],
        files: const {},
      );
    }
    await persistence.flush();
    persistence.restoreJson(source);
    await persistence.save();
    return result;
  }
}
