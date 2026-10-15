import '../../../core/services/file_store.dart';
import 'default_photo_files_native.dart'
    if (dart.library.js_interop) 'default_photo_files_web.dart'
    as platform;

Future<FileStore> openPhotoFiles() => platform.openPhotoFiles();
