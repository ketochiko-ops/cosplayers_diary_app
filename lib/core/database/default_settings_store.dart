import 'settings_store.dart';
import 'default_settings_store_native.dart'
    if (dart.library.js_interop) 'default_settings_store_web.dart'
    as implementation;

Future<SettingsStore> openDefaultSettingsStore() =>
    implementation.openDefaultSettingsStore();
