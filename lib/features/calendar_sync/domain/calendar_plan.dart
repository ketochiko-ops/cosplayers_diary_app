import 'calendar_codec.dart';

enum CalendarAction {
  upload,
  download,
  deleteLocal,
  deleteRemote,
  unchanged,
  conflict,
}

enum CalendarResolution { local, google }

class CalendarChange {
  const CalendarChange({
    required this.diaryId,
    required this.action,
    this.local,
    this.remote,
    this.decoded,
  });
  final String diaryId;
  final CalendarAction action;
  final Map<String, dynamic>? local;
  final Map<String, dynamic>? remote;
  final CalendarDiary? decoded;
  String get label {
    final title = local?['calendarTitle'] as String?;
    return title != null && title.isNotEmpty
        ? title
        : remote?['summary'] as String? ??
              local?['activityDate'] as String? ??
              '日記';
  }
}

/// Three-way reconciliation. Absence only means deletion after a prior sync.
class CalendarPlanner {
  const CalendarPlanner({this.codec = const CalendarCodec()});
  final CalendarCodec codec;

  List<CalendarChange> plan({
    required Map<String, dynamic> state,
    required List<Map<String, dynamic>> events,
    required Map<String, dynamic> baseline,
    required String calendarId,
    Map<String, CalendarResolution> resolutions = const {},
  }) {
    final local = <String, Map<String, dynamic>>{
      for (final raw in state['diary'] as List)
        raw['id'] as String: Map<String, dynamic>.from(raw),
    };
    final byEvent = <String, String>{
      for (final e in baseline.entries) e.value['eventId'] as String: e.key,
    };
    final remote = <String, Map<String, dynamic>>{};
    final decoded = <String, CalendarDiary>{};
    for (final event in events) {
      final eventId = event['id'] as String;
      if (event['status'] == 'cancelled') {
        final id = byEvent[eventId];
        if (id != null) remote.putIfAbsent(id, () => event);
        continue;
      }
      final diary = codec.decode(event, calendarId);
      final id = diary.entry['id'] as String;
      if (byEvent.containsKey(eventId) && byEvent[eventId] != id) {
        throw const FormatException('予定と日記の対応情報が変更されています');
      }
      if (remote.containsKey(id) && remote[id]!['status'] != 'cancelled') {
        throw const FormatException('同じ日記の予定が複数あります。重複を整理してください');
      }
      remote[id] = event;
      decoded[id] = diary;
    }
    final result = <CalendarChange>[];
    for (final id in {...local.keys, ...remote.keys, ...baseline.keys}) {
      final l = local[id];
      final r = remote[id];
      final hasRemote = r != null && r['status'] != 'cancelled';
      final base = baseline[id] as Map?;
      CalendarAction action;
      if (l != null && hasRemote) {
        final same = codec.same(l, state, decoded[id]!);
        if (base == null) {
          action = same ? CalendarAction.unchanged : CalendarAction.conflict;
        } else {
          final localChanged =
              codec.localFingerprint(l, state) != base['local'];
          final remoteChanged = codec.remoteFingerprint(r) != base['remote'];
          action = same
              ? CalendarAction.unchanged
              : localChanged && remoteChanged
              ? CalendarAction.conflict
              : localChanged
              ? CalendarAction.upload
              : remoteChanged
              ? CalendarAction.download
              : CalendarAction.unchanged;
        }
      } else if (l != null) {
        action = base == null
            ? CalendarAction.upload
            : codec.localFingerprint(l, state) == base['local']
            ? CalendarAction.deleteLocal
            : CalendarAction.conflict;
      } else if (hasRemote) {
        action = base == null
            ? CalendarAction.download
            : codec.remoteFingerprint(r) == base['remote']
            ? CalendarAction.deleteRemote
            : CalendarAction.conflict;
      } else {
        action = CalendarAction.unchanged;
      }
      if (action == CalendarAction.conflict && resolutions.containsKey(id)) {
        action = resolutions[id] == CalendarResolution.local
            ? l == null
                  ? CalendarAction.deleteRemote
                  : CalendarAction.upload
            : hasRemote
            ? CalendarAction.download
            : CalendarAction.deleteLocal;
      }
      result.add(
        CalendarChange(
          diaryId: id,
          action: action,
          local: l,
          remote: r,
          decoded: decoded[id],
        ),
      );
    }
    return result;
  }
}
