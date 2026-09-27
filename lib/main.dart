import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/database/default_settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsStore = await openDefaultSettingsStore();
  runApp(CosplayDiaryApp(settingsStore: settingsStore));
}
