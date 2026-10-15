import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_state_persistence.dart';
import '../../../core/database/settings_store.dart';
import '../../../core/services/clock.dart';
import '../../contact_lenses/application/lens_store.dart';
import '../../diary/application/diary_store.dart';
import '../../master_data/application/master_data_store.dart';
import '../domain/calendar_codec.dart';
import '../domain/calendar_plan.dart';
import '../infrastructure/calendar_transport.dart';

class CalendarSyncController extends ChangeNotifier {
  CalendarSyncController({
    required this.persistence,
    required this.settings,
    required this.transport,
    this.clock = const SystemClock(),
    this.canSync,
    this.onRemoteChanged,
  }) {
    persistence.addSavedListener(_saved);
  }

  static const settingsKey = 'google_calendar_sync_v1';
  static const dailyLimit = 10;
  static const maxWritesPerRun = 100;
  static const codec = CalendarCodec();
  final AppStatePersistence persistence;
  final SettingsStore settings;
  final CalendarTransport transport;
  final Clock clock;
  final bool Function()? canSync;
  final VoidCallback? onRemoteChanged;
  final _histories = <String, dynamic>{};
  final _usage = <String, dynamic>{};
  CalendarConnection? _connection;
  bool _busy = false;
  bool _auto = true;
  bool _paused = false;
  bool _applying = false;
  bool _disposed = false;
  bool _pendingAuto = false;
  bool _snapshotTaken = false;
  bool _pending = false;
  int _generation = 0;
  Timer? _timer;
  String? _message;
  String? _lastSync;
  String? _lastCalendar;
  String? _projection;
  List<CalendarChange> _conflicts = [];
  Future<void> _settingsWrite = Future<void>.value();

  bool get connected => _connection != null;
  bool get busy => _busy;
  bool get automatic => _auto;
  bool get paused => _paused;
  bool get pending => _pending;
  bool get visible => _connection?.selected ?? false;
  String get calendarName => _connection?.name ?? _lastCalendar ?? 'コスプレ日記';
  String? get message => _message;
  String? get lastSync => _lastSync;
  List<CalendarChange> get conflicts => List.unmodifiable(_conflicts);
  String get today {
    final date = clock.now();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> get _todayUsage {
    final value = _usage['device'];
    return value is Map && value['day'] == today
        ? Map<String, dynamic>.from(value)
        : {'day': today, 'count': 0, 'automatic': false};
  }

  int get usedToday {
    final count = _todayUsage['count'];
    return count is int && count >= 0 && count <= dailyLimit
        ? count
        : dailyLimit;
  }

  int get remainingToday => dailyLimit - usedToday;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final source = await settings.readSetting(settingsKey);
    if (source != null && source.isNotEmpty) {
      try {
        final value = jsonDecode(source) as Map<String, dynamic>;
        _auto = value['automatic'] != false;
        _pending = value['pending'] == true;
        _histories.addAll(Map<String, dynamic>.from(value['histories'] ?? {}));
        _usage.addAll(Map<String, dynamic>.from(value['usage'] ?? {}));
        _lastCalendar = value['calendarName'] as String?;
        _lastSync = value['lastSync'] as String?;
      } catch (_) {
        _message = '同期履歴を読み込めません。再接続時は両方の内容を確認し、履歴不明の日記は自動削除しません。';
      }
    }
    _projection = _signature(persistence.exportJson());
    _notify();
  }

  Future<void> _persist() {
    final source = jsonEncode({
      'automatic': _auto,
      'pending': _pending,
      'histories': _histories,
      'usage': _usage,
      'calendarName': _lastCalendar,
      'lastSync': _lastSync,
    });
    _settingsWrite = _settingsWrite
        .catchError((Object _) {})
        .then((_) => settings.writeSetting(settingsKey, source));
    return _settingsWrite;
  }

  Future<void> connect(String clientId) async {
    if (_busy || _disposed) return;
    _busy = true;
    _message = null;
    _notify();
    final generation = _generation;
    try {
      final connection = await transport.connect(
        clientId,
        knownCalendarIds: _histories.keys.toList(),
      );
      if (generation != _generation || _disposed) {
        await transport.disconnect();
        return;
      }
      _connection = connection;
      _histories.putIfAbsent(connection.id, () => <String, dynamic>{});
      _lastCalendar = connection.name;
      _paused = false;
      _projection = _signature(persistence.exportJson());
      await _persist();
    } catch (error) {
      _connection = null;
      _paused = true;
      _message = '接続できませんでした: $error';
    } finally {
      _busy = false;
      _notify();
    }
    if (connected && generation == _generation) await sync();
  }

  Future<void> setAutomatic(bool enabled) async {
    _auto = enabled;
    if (!enabled) {
      _timer?.cancel();
      _pendingAuto = false;
    }
    await _persist();
    _notify();
  }

  String _signature(String source) {
    final state = jsonDecode(source) as Map<String, dynamic>;
    return CalendarCodec.fingerprint({
      for (final row in state['diary'] as List)
        row['id'] as String: codec.localFingerprint(
          Map<String, dynamic>.from(row),
          state,
        ),
    });
  }

  Future<void> _saved(String source) async {
    if (_disposed || !transport.supported) return;
    final signature = _signature(source);
    if (signature == _projection) return;
    _projection = signature;
    if (_applying) return;
    _pending = true;
    _notify();
    try {
      await _persist();
    } catch (error) {
      _paused = true;
      _message = '同期状態を保存できませんでした: $error';
      _notify();
      return;
    }
    if (!connected ||
        !_auto ||
        _paused ||
        _todayUsage['automatic'] == true ||
        remainingToday <= 0) {
      return;
    }
    final usage = _todayUsage..['automatic'] = true;
    _usage['device'] = usage;
    try {
      await _persist();
    } catch (error) {
      _paused = true;
      _message = '同期回数を保存できませんでした: $error';
      _notify();
      return;
    }
    if (_busy && !_snapshotTaken) return;
    _timer?.cancel();
    _timer = Timer(Duration.zero, () {
      unawaited(sync(automaticRun: true));
    });
  }

  Future<void> sync({
    bool automaticRun = false,
    Map<String, CalendarResolution> resolutions = const {},
  }) async {
    if (_disposed || !connected) return;
    if (_busy) {
      if (automaticRun) _pendingAuto = true;
      return;
    }
    if (canSync?.call() == false) {
      _message = '編集中の画面を閉じ、プロジェクトの保存先を確認してから手動同期してください。';
      _notify();
      return;
    }
    if (remainingToday <= 0) {
      _message = '本日の同期上限（自動・手動の合計10回）に達しました。編集と端末への保存は続けられます。';
      _notify();
      return;
    }
    _busy = true;
    _snapshotTaken = false;
    _message = null;
    _conflicts = [];
    _timer?.cancel();
    final generation = _generation;
    final connection = _connection!;
    _notify();
    try {
      final usage = _todayUsage..['count'] = usedToday + 1;
      _usage['device'] = usage;
      // Failed attempts count too; no unbounded retries or reload reset.
      await _persist();
      await persistence.flush();
      var expectedSource = persistence.exportJson();
      final state = jsonDecode(expectedSource) as Map<String, dynamic>;
      _snapshotTaken = true;
      final events = await transport.listEvents();
      if (generation != _generation || _disposed) return;
      final baseline = Map<String, dynamic>.from(
        _histories[connection.id] ?? {},
      );
      final plan = const CalendarPlanner().plan(
        state: state,
        events: events,
        baseline: baseline,
        calendarId: connection.id,
        resolutions: resolutions,
      );
      // Validate every incoming row and outgoing payload before the first mutation.
      var candidate = state;
      for (final change in plan) {
        if (change.action == CalendarAction.download ||
            change.action == CalendarAction.deleteLocal) {
          candidate = _apply(candidate, change);
        } else if (change.action == CalendarAction.upload) {
          codec.encode(change.local!, state);
        }
      }
      persistence.validateJson(jsonEncode(candidate));
      var changedLocal = false;
      var writes = 0;
      var limited = false;
      final incoming = <CalendarChange>[];
      for (final change in plan) {
        if (generation != _generation || _disposed) return;
        if (persistence.exportJson() != expectedSource) {
          throw StateError('同期中に端末の内容が変わりました。変更を保持しています。手動で再同期してください。');
        }
        final action = change.action;
        if (action == CalendarAction.conflict) {
          _conflicts.add(change);
          continue;
        }
        if (action == CalendarAction.download ||
            action == CalendarAction.deleteLocal) {
          incoming.add(change);
          continue;
        }
        if ((action == CalendarAction.upload ||
                action == CalendarAction.deleteRemote) &&
            writes >= maxWritesPerRun) {
          limited = true;
          continue;
        }
        if (action == CalendarAction.upload) {
          final resource = codec.encode(change.local!, state);
          final deletedRemote =
              change.remote?['status'] == 'cancelled' ||
              (change.remote == null && baseline.containsKey(change.diaryId));
          if (deletedRemote) {
            // Google can retain a tombstone with only its ID; use a new event ID.
            resource['id'] =
                '${resource['id']}r${clock.now().microsecondsSinceEpoch.toRadixString(16)}';
          }
          final remote = await transport.putEvent(
            resource,
            existingId: deletedRemote ? null : change.remote?['id'] as String?,
            etag: deletedRemote ? null : change.remote?['etag'] as String?,
          );
          if (generation != _generation || _disposed) return;
          writes++;
          baseline[change.diaryId] = _base(change.local!, state, remote);
        } else if (action == CalendarAction.deleteRemote) {
          await transport.deleteEvent(
            change.remote!['id'] as String,
            change.remote!['etag'] as String,
          );
          if (generation != _generation || _disposed) return;
          writes++;
          baseline.remove(change.diaryId);
        } else if (change.local != null &&
            change.remote != null &&
            change.remote!['status'] != 'cancelled') {
          baseline[change.diaryId] = _base(
            change.local!,
            state,
            change.remote!,
          );
        } else {
          baseline.remove(change.diaryId);
        }
        _histories[connection.id] = baseline;
        await _persist();
      }
      if (persistence.exportJson() != expectedSource) {
        throw StateError('同期中に端末の内容が変わりました。手動で再同期してください。');
      }
      if (generation != _generation || _disposed || canSync?.call() == false) {
        throw StateError('編集中のデータを守るため読み込みを保留しました。画面を閉じて手動同期してください。');
      }
      var merged = jsonDecode(expectedSource) as Map<String, dynamic>;
      for (final change in incoming) {
        merged = _apply(merged, change);
      }
      if (incoming.isNotEmpty) {
        persistence.validateJson(jsonEncode(merged));
        _applying = true;
        try {
          persistence.restoreJson(jsonEncode(merged));
          final appliedSource = persistence.exportJson();
          await persistence.save();
          if (persistence.exportJson() != appliedSource) {
            throw StateError('読み込み中に端末で編集されました。変更を保持しています。手動で再同期してください。');
          }
          changedLocal = true;
          expectedSource = persistence.exportJson();
          _projection = _signature(expectedSource);
        } finally {
          _applying = false;
        }
      }
      final finalState = jsonDecode(expectedSource) as Map<String, dynamic>;
      for (final change in incoming) {
        if (change.action == CalendarAction.deleteLocal) {
          baseline.remove(change.diaryId);
        } else {
          final row = (finalState['diary'] as List).firstWhere(
            (e) => e['id'] == change.diaryId,
          );
          baseline[change.diaryId] = _base(
            Map<String, dynamic>.from(row),
            finalState,
            change.remote!,
          );
        }
      }
      _histories[connection.id] = baseline;
      _lastSync = clock.now().toIso8601String();
      _paused = _conflicts.isNotEmpty || limited;
      _pending = _paused;
      _message = _conflicts.isNotEmpty
          ? '両方で変更された日記があります。使用する内容を選んでください。'
          : limited
          ? '1回の更新上限（100件）に達しました。残りは手動で同期してください。'
          : '日記の同期が完了しました。';
      await _persist();
      if (changedLocal) onRemoteChanged?.call();
    } catch (error) {
      _paused = true;
      _pending = true;
      _message = '同期を停止しました。端末の変更は保持しています: $error';
    } finally {
      _busy = false;
      _snapshotTaken = false;
      _notify();
      final pendingAuto = _pendingAuto;
      _pendingAuto = false;
      if (pendingAuto && connected && !_disposed && !_paused && _auto) {
        _timer = Timer(const Duration(seconds: 2), () {
          unawaited(sync(automaticRun: true));
        });
      }
    }
  }

  Map<String, dynamic> _base(
    Map<String, dynamic> row,
    Map<String, dynamic> state,
    Map<String, dynamic> event,
  ) => {
    'eventId': event['id'],
    'local': codec.localFingerprint(row, state),
    'remote': codec.remoteFingerprint(event),
  };

  Map<String, dynamic> _apply(
    Map<String, dynamic> state,
    CalendarChange change,
  ) {
    if (change.action == CalendarAction.download) {
      final existing = (state['diary'] as List)
          .where((e) => e['id'] == change.diaryId)
          .firstOrNull;
      if (existing != null &&
          existing['activityDate'] != change.decoded!.entry['activityDate'] &&
          (state['lensUsages'] as List).any(
            (e) => e['diaryId'] == change.diaryId,
          )) {
        throw StateError('カラコン使用履歴のある日記の日付が変更されています。使用を解除してから同期してください。');
      }
      return codec.merge(state, change.decoded!);
    }
    // Use the ledger's deletion rule, including restoring one-day lens stock.
    final temporary = AppStatePersistence(
      store: settings,
      masters: MasterDataStore(),
      diary: DiaryStore(),
      lenses: LensStore(),
    );
    try {
      temporary.restoreJson(jsonEncode(state));
      temporary.lenses.ledger.removeDiaryUsage(change.diaryId);
      temporary.diary.entries.removeWhere((e) => e.id == change.diaryId);
      return jsonDecode(temporary.exportJson()) as Map<String, dynamic>;
    } finally {
      temporary.masters.dispose();
      temporary.diary.dispose();
      temporary.lenses.dispose();
    }
  }

  Future<void> setVisible(bool value) async {
    if (!connected || _busy) return;
    _busy = true;
    _notify();
    try {
      await transport.setVisible(value);
      final current = _connection!;
      _connection = CalendarConnection(
        id: current.id,
        name: current.name,
        selected: value,
      );
      _message = value
          ? 'Googleカレンダーに表示します。'
          : 'Googleカレンダーで非表示にしました。同期は引き続き利用できます。';
    } catch (error) {
      _message = '表示設定を変更できませんでした: $error';
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> disconnect({bool projectChanged = false}) async {
    _generation++;
    _timer?.cancel();
    _pendingAuto = false;
    _connection = null;
    _conflicts = [];
    _paused = false;
    if (projectChanged) {
      _histories.clear();
      _projection = _signature(persistence.exportJson());
    }
    _message = projectChanged
        ? 'プロジェクトを変更したため連携を解除しました。必要なら再接続してください。'
        : '連携を解除しました。Google上の予定は残しています。';
    _notify();
    try {
      await transport.disconnect();
      await _persist();
    } catch (error) {
      _message = '接続は解除しましたが同期設定を保存できませんでした: $error';
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    persistence.removeSavedListener(_saved);
    unawaited(transport.disconnect().catchError((Object _) {}));
    super.dispose();
  }
}
