import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:cosplayers_diary/features/backup/domain/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = BackupService(maxExtractedBytes: 1024);

  test('legacy manifest and relative image are readable', () {
    final files = <String, Uint8List>{
      'data/genres.csv': Uint8List.fromList(utf8.encode('id,name\ng1,A\n')),
      'images/photo-1.jpg': Uint8List.fromList([1, 2, 3]),
    };
    final bytes = _legacyZip(files, createdAt: DateTime.utc(2026, 1, 1));
    final result = service.inspect(bytes);
    expect(result.isValid, isTrue);
    expect(result.manifest!.formatVersion, BackupService.currentVersion);
    expect(result.manifest!.imageCount, 1);
  });

  test('rejects unsupported manifest version', () {
    final bytes = _legacyZip(
      const {},
      createdAt: DateTime.utc(2026),
      formatVersion: 99,
    );
    expect(service.inspect(bytes).errors.join(), contains('バージョン'));
  });

  test('rejects traversal path before extraction', () {
    final bytes = _legacyZip({
      '../escape.txt': Uint8List(1),
    }, createdAt: DateTime.utc(2026));
    expect(service.inspect(bytes).errors.join(), contains('不正なパス'));
  });

  test('rejects excessive extracted size', () {
    final bytes = _legacyZip({
      'images/huge.jpg': Uint8List(2048),
    }, createdAt: DateTime.utc(2026));
    expect(service.inspect(bytes).errors.join(), contains('サイズ'));
  });
}

Uint8List _legacyZip(
  Map<String, Uint8List> files, {
  required DateTime createdAt,
  int formatVersion = 1,
}) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.add(ArchiveFile.bytes(entry.key, entry.value));
  }
  archive.add(
    ArchiveFile.string(
      'manifest.json',
      jsonEncode({
        'formatVersion': formatVersion,
        'createdAt': createdAt.toIso8601String(),
        'dataCounts': <String, int>{},
        'imageCount': files.keys
            .where((name) => name.startsWith('images/'))
            .length,
      }),
    ),
  );
  return ZipEncoder().encodeBytes(archive);
}
