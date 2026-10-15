import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

class BackupManifest {
  const BackupManifest({
    required this.formatVersion,
    required this.createdAt,
    required this.dataCounts,
    required this.imageCount,
  });
  final int formatVersion;
  final DateTime createdAt;
  final Map<String, int> dataCounts;
  final int imageCount;

  Map<String, Object> toJson() => {
    'formatVersion': formatVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'dataCounts': dataCounts,
    'imageCount': imageCount,
  };

  factory BackupManifest.fromJson(Map<String, Object?> json) => BackupManifest(
    formatVersion: json['formatVersion'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    dataCounts: (json['dataCounts'] as Map<String, Object?>).map(
      (key, value) => MapEntry(key, value as int),
    ),
    imageCount: json['imageCount'] as int,
  );
}

class BackupInspection {
  const BackupInspection({
    required this.errors,
    required this.files,
    this.manifest,
  });
  final List<String> errors;
  final Map<String, Uint8List> files;
  final BackupManifest? manifest;
  bool get isValid => errors.isEmpty;
}

class BackupService {
  const BackupService({this.maxExtractedBytes = 1024 * 1024 * 1024});
  static const currentVersion = 1;
  final int maxExtractedBytes;

  BackupInspection inspect(Uint8List bytes) {
    final errors = <String>[];
    final files = <String, Uint8List>{};
    BackupManifest? manifest;
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      var total = 0;
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final name = entry.name.replaceAll('\\', '/');
        if (!_isSafePath(name)) {
          errors.add('不正なパスです: ${entry.name}');
          continue;
        }
        total += entry.size;
        if (total > maxExtractedBytes) {
          errors.add('展開後サイズが上限を超えています');
          break;
        }
        files[name] = entry.content;
      }
      final manifestBytes = files['manifest.json'];
      if (manifestBytes == null) {
        errors.add('manifest.json がありません');
      } else {
        final decoded =
            jsonDecode(utf8.decode(manifestBytes)) as Map<String, Object?>;
        manifest = BackupManifest.fromJson(decoded);
        if (manifest.formatVersion != currentVersion) {
          errors.add('未対応のバックアップ形式バージョンです: ${manifest.formatVersion}');
        }
        final actualImages = files.keys
            .where((name) => name.startsWith('images/'))
            .length;
        if (actualImages != manifest.imageCount) {
          errors.add('画像件数が manifest と一致しません');
        }
      }
    } catch (error) {
      errors.add('ZIPを読み取れません: $error');
    }
    return BackupInspection(errors: errors, files: files, manifest: manifest);
  }

  bool _isSafePath(String value) {
    if (value.isEmpty ||
        value.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(value)) {
      return false;
    }
    final normalized = path.posix.normalize(value);
    return normalized != '..' &&
        !normalized.startsWith('../') &&
        normalized == value;
  }
}
