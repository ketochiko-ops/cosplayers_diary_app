import 'package:web/web.dart' as web;

import 'settings_store.dart';

class WebSettingsStore implements SettingsStore {
  static const _prefix = 'cosplayers_diary.';

  @override
  Future<String?> readSetting(String key) async =>
      web.window.localStorage.getItem('$_prefix$key');

  @override
  Future<void> writeSetting(String key, String value) async {
    web.window.localStorage.setItem('$_prefix$key', value);
  }
}

Future<SettingsStore> openDefaultSettingsStore() async => WebSettingsStore();
