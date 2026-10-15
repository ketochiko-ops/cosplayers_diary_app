import 'dart:typed_data';

import '../../../core/database/app_state_persistence.dart';
import '../../../core/services/file_store.dart';
import '../domain/photo_service.dart';
import '../infrastructure/package_image_processor.dart';

class PhotoController {
  PhotoController({required this.persistence, required this.files});
  final AppStatePersistence persistence;
  final FileStore files;
  late final _service = PhotoService(
    fileStore: files,
    processor: const PackageImageProcessor(),
  );

  PhotoRecord? find(String? id) =>
      persistence.photos.where((p) => p.id == id).firstOrNull;
  void retain(PhotoRecord photo) {
    if (find(photo.id) == null) persistence.photos.add(photo);
  }

  Future<PhotoRecord> add(Uint8List bytes, String name, String diaryId) async {
    if (bytes.isEmpty || bytes.length > 32 * 1024 * 1024) {
      throw const FormatException('画像は空でない32MB以内のファイルを指定してください');
    }
    final mode = await persistence.store.readSetting('photo_save_mode');
    return _service.replace(
      diaryId: diaryId,
      bytes: bytes,
      originalName: name,
      mode: mode == 'original'
          ? PhotoSaveMode.original
          : PhotoSaveMode.spaceSaving,
      oldIsReferenced: true,
    );
  }
}
