import 'package:flutter/foundation.dart';

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
  int _loadedProjectVersion = 0;
  bool _browserMode = false;
  bool _paused = false;
  bool _busy = false;
  String? _preferredTarget;
  Future<void> _io = Future<void>.value();

  ProjectTarget? get target => _target;
  String? get name => _name;
  String? get message => _message;
  bool get paused => _paused;
  bool get busy => _busy;
  bool get browserMode => _browserMode;
  int get loadedProjectVersion => _loadedProjectVersion;
  bool get requiresSelection => !_browserMode && (_target == null || _paused);
  String? get preferredTarget => _preferredTarget;

  Future<void> loadPreference() async {
    _preferredTarget = await settings.readSetting(preferenceKey);
    _browserMode = _preferredTarget == 'browser';
    if (_preferredTarget == 'localFile') {
      _message = 'プロジェクトフォルダ方式へ変更しました。端末のデータを引き継いで保存場所を指定してください。';
    }
  }

  Future<void> tryResumeLocalFolder() async {
    if (_browserMode ||
        !storage.supportsLocalFolder ||
        _preferredTarget != ProjectTarget.localFolder.name) {
      return;
    }
    try {
      final snapshot = await storage.reconnectLocalFolder();
      if (snapshot == null) return;
      validate(snapshot.content ?? '');
      if (snapshot.content != persistence.exportJson()) {
        _requireSelection('前回のフォルダと端末に残る内容が異なります。使用する内容を選んでください。');
        return;
      }
      await storage.loadAssets();
      await _activate(ProjectTarget.localFolder, snapshot);
    } catch (error) {
      _requireSelection('前回のプロジェクトフォルダを読み込めません。保存先を再指定してください: $error');
    }
  }

  // Detach the previous target before changing the platform handle. This also
  // drains queued cache saves so they cannot overwrite the newly selected file.
  Future<ProjectSnapshot?> _choose(
    Future<ProjectSnapshot?> Function() choose,
  ) async {
    if (_busy) return null;
    _busy = true;
    _target = null;
    _browserMode = false;
    notifyListeners();
    try {
      await persistence.flush();
      await _io;
      return await choose();
    } catch (error) {
      _requireSelection('フォルダを指定できませんでした: $error');
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<ProjectSnapshot?> openLocalFolder() =>
      _choose(storage.openLocalFolder);
  Future<ProjectSnapshot?> createLocalFolder() =>
      _choose(() => storage.createLocalFolder(persistence.exportJson()));
  Future<ProjectSnapshot?> reconnectLocalFolder() =>
      _choose(() => storage.reconnectLocalFolder(requestPermission: true));

  void validate(String source) => persistence.validateJson(source);

  Future<void> useProject(
    ProjectTarget target,
    ProjectSnapshot snapshot,
  ) async {
    final content = snapshot.content;
    if (content == null) throw const FormatException('プロジェクトフォルダが空です');
    validate(content);
    _busy = true;
    _target = null;
    _browserMode = false;
    notifyListeners();
    try {
      await persistence.flush();
      await _io;
      await storage.loadAssets();
      final normalized = persistence.normalizeJson(content);
      final written = await storage.write(
        target,
        normalized,
        snapshot.revision,
      );
      persistence.restoreJson(normalized);
      _loadedProjectVersion++;
      await persistence.save();
      await _activate(target, written);
    } catch (error) {
      _requireSelection('プロジェクトを読み込めませんでした: $error');
      rethrow;
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
    _target = null;
    _browserMode = false;
    notifyListeners();
    try {
      await persistence.flush();
      await _io;
      final source = persistence.exportJson();
      final result = await storage.write(target, source, snapshot.revision);
      await persistence.save(replaceInvalidCache: true);
      await _activate(target, result);
    } catch (error) {
      _requireSelection('プロジェクトを保存できませんでした: $error');
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _activate(ProjectTarget target, ProjectSnapshot snapshot) async {
    await settings.writeSetting(preferenceKey, target.name);
    _browserMode = false;
    _target = target;
    _revision = snapshot.revision;
    _name = snapshot.name;
    _paused = false;
    _message = null;
    _preferredTarget = target.name;
    notifyListeners();
  }

  Future<void> _onSaved(String source) {
    _io = _io.then((_) async {
      final target = _target;
      if (target == null || _paused) return;
      try {
        final result = await storage.write(target, source, _revision);
        _revision = result.revision;
        _name = result.name;
        notifyListeners();
      } catch (error) {
        _requireSelection(
          'プロジェクトフォルダに保存できません。保存場所を再指定してください。変更内容は端末に保持しています: $error',
        );
      }
    });
    return _io;
  }

  // Reads are serialized with writes to avoid treating our own save as a conflict.
  Future<void> checkFolder() {
    if (_browserMode || requiresSelection || _busy) return Future<void>.value();
    _io = _io.then((_) async {
      if (_browserMode || requiresSelection || _busy) return;
      try {
        final snapshot = await storage.readLocalFolder();
        if (snapshot.revision != _revision) {
          throw const FormatException('フォルダが他のアプリや端末で変更されました');
        }
      } catch (error) {
        _requireSelection('プロジェクトフォルダを読み込めません。保存場所を再指定してください: $error');
      }
    });
    return _io;
  }

  void reportCacheError(Object error) {
    _browserMode = false;
    _target = null;
    _requireSelection(
      '端末内の保存データを読み込めませんでした。JSONの控えを指定するか、ブラウザ保存モードで新しく開始してください。ブラウザ保存で開始した後も、設定からJSONの控えを読み込めます: $error',
    );
  }

  void _requireSelection(String message) {
    _paused = true;
    _message = message;
    notifyListeners();
  }

  Future<void> useBrowserMode() async {
    _busy = true;
    _target = null;
    notifyListeners();
    try {
      await persistence.flush(replaceInvalidCache: true);
      await _io;
      await settings.writeSetting(preferenceKey, 'browser');
      _browserMode = true;
      _preferredTarget = 'browser';
      _paused = false;
      _message = null;
      _name = null;
      _revision = null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (_busy) return;
    _busy = true;
    _browserMode = false;
    _target = null;
    _paused = false;
    notifyListeners();
    try {
      await persistence.flush();
      await _io;
      if (storage.supportsLocalFolder) {
        await storage.disconnect(ProjectTarget.localFolder);
      }
      _revision = null;
      _name = null;
      _message = null;
      _preferredTarget = null;
      await settings.writeSetting(preferenceKey, '');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
