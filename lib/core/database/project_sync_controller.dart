import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../features/contact_lenses/application/lens_store.dart';
import '../../features/diary/application/diary_store.dart';
import '../../features/master_data/application/master_data_store.dart';
import 'app_state_persistence.dart';
import 'project_storage.dart';
import 'settings_store.dart';

class ProjectSyncController extends ChangeNotifier {
  ProjectSyncController({
    required this.persistence,
    required this.settings,
    required this.storage,
  }) {
    persistence.onSaved = _onSaved;
  }

  static const preferenceKey = 'project_target_v1';
  final AppStatePersistence persistence;
  final SettingsStore settings;
  final ProjectStorage storage;

  ProjectTarget? _target;
  String? _revision;
  String? _name;
  String? _message;
  bool _paused = false;
  bool _busy = false;
  String? _preferredTarget;

  ProjectTarget? get target => _target;
  String? get name => _name;
  String? get message => _message;
  bool get paused => _paused;
  bool get busy => _busy;
  String? get preferredTarget => _preferredTarget;

  Future<void> loadPreference() async {
    _preferredTarget = await settings.readSetting(preferenceKey);
    notifyListeners();
  }

  Future<void> tryResumeLocalFile() async {
    if (_preferredTarget != ProjectTarget.localFile.name ||
        !storage.supportsLocalFile) {
      return;
    }
    try {
      final snapshot = await storage.reconnectLocalFile();
      if (snapshot == null || snapshot.content != persistence.exportJson()) {
        _message = 'ファイルの内容を確認するため再接続してください';
        notifyListeners();
        return;
      }
      await _activate(ProjectTarget.localFile, snapshot);
    } catch (_) {
      _message = 'ローカルファイルへの再接続が必要です';
      notifyListeners();
    }
  }

  Future<ProjectSnapshot?> openLocalFile() => storage.openLocalFile();
  Future<ProjectSnapshot?> createLocalFile() =>
      storage.createLocalFile(persistence.exportJson());
  Future<ProjectSnapshot?> reconnectLocalFile() => storage.reconnectLocalFile();
  Future<ProjectSnapshot> connectGoogleDrive(String clientId) =>
      storage.connectGoogleDrive(clientId);

  void validate(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        !const [
          'genres',
          'characters',
          'costumes',
          'diary',
          'lensProducts',
          'lensPurchases',
          'lensInventories',
          'lensUsages',
        ].every((key) => decoded[key] is List)) {
      throw const FormatException('プロジェクトJSONの形式が正しくありません');
    }
    final temporary = AppStatePersistence(
      store: settings,
      masters: MasterDataStore(),
      diary: DiaryStore(),
      lenses: LensStore(),
    );
    temporary.restoreJson(source);
  }

  Future<void> useProject(
    ProjectTarget target,
    ProjectSnapshot snapshot,
  ) async {
    final content = snapshot.content;
    if (content == null) throw const FormatException('プロジェクトファイルが空です');
    validate(content);
    _busy = true;
    notifyListeners();
    try {
      _target = null;
      persistence.restoreJson(content);
      await persistence.save();
      await _activate(target, snapshot);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> uploadCurrent(
    ProjectTarget target,
    ProjectSnapshot snapshot,
  ) async {
    _busy = true;
    notifyListeners();
    try {
      final source = persistence.exportJson();
      final result =
          target == ProjectTarget.googleDrive && snapshot.content == null
          ? await storage.createGoogleDrive(source)
          : snapshot.content == source
          ? snapshot
          : await storage.write(target, source, snapshot.revision);
      await _activate(target, result);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _activate(ProjectTarget target, ProjectSnapshot snapshot) async {
    _target = target;
    _revision = snapshot.revision;
    _name = snapshot.name;
    _paused = false;
    _message = null;
    _preferredTarget = target.name;
    await settings.writeSetting(preferenceKey, target.name);
    notifyListeners();
  }

  Future<void> _onSaved(String source) async {
    final target = _target;
    if (target == null || _paused) return;
    try {
      final result = await storage.write(target, source, _revision);
      _revision = result.revision;
      _name = result.name;
      _message = null;
      notifyListeners();
    } catch (error) {
      _paused = true;
      _message = '自動保存を停止しました: $error';
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    final target = _target;
    if (target != null) await storage.disconnect(target);
    _target = null;
    _revision = null;
    _name = null;
    _message = null;
    _paused = false;
    _preferredTarget = null;
    await settings.writeSetting(preferenceKey, '');
    notifyListeners();
  }
}
