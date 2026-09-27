abstract interface class SettingsStore {
  Future<String?> readSetting(String key);

  Future<void> writeSetting(String key, String value);
}
