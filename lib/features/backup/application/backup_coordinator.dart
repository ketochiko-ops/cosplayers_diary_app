import 'dart:convert';
import 'dart:typed_data';

import '../../../core/database/app_state_persistence.dart';
import '../domain/backup_service.dart';

class BackupCoordinator {
  const BackupCoordinator(this.persistence);
  final AppStatePersistence persistence;
  static const _legacyBackup = BackupService();

  /// New backups and project files use the same uncompressed JSON format.
  Uint8List create() =>
      Uint8List.fromList(utf8.encode(persistence.exportJson()));

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
