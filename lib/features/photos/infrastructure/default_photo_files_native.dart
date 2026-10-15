import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/services/file_store.dart';
import 'local_file_store.dart';

Future<FileStore> openPhotoFiles() async => LocalFileStore(
  Directory('${(await getApplicationDocumentsDirectory()).path}/CosplayDiary'),
);
