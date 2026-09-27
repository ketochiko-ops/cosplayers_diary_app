import 'app_database.dart';
import 'settings_store.dart';

Future<SettingsStore> openDefaultSettingsStore() => AppDatabase.openDefault();
