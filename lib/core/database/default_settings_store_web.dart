import 'package:web/web.dart' as web;

import 'settings_store.dart';

class WebSettingsStore implements SettingsStore {
  // GitHub Pages projects share an origin; keep each base path independent.
  // Preserve the existing root-hosted production keys.
  static String get _prefix {
    final basePath = Uri.parse(web.document.baseURI).path;
    return basePath == '/'
        ? 'cosplayers_diary.'
        : 'cosplayers_diary.$basePath.';
  }

  @override
  Future<String?> readSetting(String key) async =>
      web.window.localStorage.getItem('$_prefix$key');

  @override
  Future<void> writeSetting(String key, String value) async {
    web.window.localStorage.setItem('$_prefix$key', value);
  }
}

Future<SettingsStore> openDefaultSettingsStore() async => WebSettingsStore();
