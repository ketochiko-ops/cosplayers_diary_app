import '../../../core/database/project_storage.dart';
import '../../../core/services/file_store.dart';

Future<FileStore> openPhotoFiles() async => createProjectStorage().assets;
