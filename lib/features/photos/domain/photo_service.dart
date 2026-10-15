import 'dart:typed_data';

import '../../../core/services/file_store.dart';
import '../../../core/services/clock.dart';

enum PhotoSaveMode { original, spaceSaving }

class PhotoRecord {
  const PhotoRecord({
    required this.id,
    required this.relativePath,
    required this.originalName,
  });
  final String id;
  final String relativePath;
  final String originalName;
}

abstract interface class ImageProcessor {
  Future<Uint8List> resizeForStorage(
    Uint8List source, {
    required int maxLongEdge,
  });
}

class PassthroughImageProcessor implements ImageProcessor {
  const PassthroughImageProcessor();
  @override
  Future<Uint8List> resizeForStorage(
    Uint8List source, {
    required int maxLongEdge,
  }) async => source;
}

class PhotoService {
  PhotoService({
    required this.fileStore,
    required this.processor,
    this.clock = const SystemClock(),
  });
  final FileStore fileStore;
  final ImageProcessor processor;
  final Clock clock;
  int _sequence = 0;

  Future<PhotoRecord> replace({
    required String diaryId,
    required Uint8List bytes,
    required String originalName,
    required PhotoSaveMode mode,
    String? oldRelativePath,
    required bool oldIsReferenced,
  }) async {
    final id = 'photo-${clock.now().microsecondsSinceEpoch}-${_sequence++}';
    final encoded = mode == PhotoSaveMode.original
        ? bytes
        : await processor.resizeForStorage(bytes, maxLongEdge: 2048);
    final extension =
        encoded.length > 2 && encoded[0] == 0xff && encoded[1] == 0xd8
        ? 'jpg'
        : _safeExtension(originalName);
    final relativePath = 'images/$id.$extension';
    await fileStore.save(relativePath, encoded);
    if (oldRelativePath != null && !oldIsReferenced) {
      try {
        await fileStore.delete(oldRelativePath);
      } catch (_) {
        // A stale orphan is safer than breaking the new database reference.
      }
    }
    return PhotoRecord(
      id: id,
      relativePath: relativePath,
      originalName: originalName,
    );
  }

  String _safeExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return 'jpg';
    final value = name.substring(dot + 1).toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp', 'heic'}.contains(value)
        ? value
        : 'jpg';
  }
}
