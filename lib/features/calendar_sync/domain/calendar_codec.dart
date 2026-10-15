import 'dart:convert';

class CalendarDiary {
  const CalendarDiary(this.entry, this.masters);
  final Map<String, dynamic> entry;
  final Map<String, dynamic> masters;
}

/// Calendar-only projection. Inventory, photos and master memos stay on device.
class CalendarCodec {
  const CalendarCodec();
  static const appTag = 'cosplayers_diary_v1';
  static const memoMarker = '\nメモ:\n';

  String eventId(String diaryId) {
    final id =
        'cd${utf8.encode(diaryId).map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';
    if (id.length > 1024) throw const FormatException('日記IDが長すぎます');
    return id;
  }

  Map<String, dynamic> encode(
    Map<String, dynamic> row,
    Map<String, dynamic> state,
  ) {
    final masters = _mastersFor(row, state);
    _validateReferences(row, masters);
    final date = _day(row['activityDate'] as String);
    final next = DateTime.parse(date).add(const Duration(days: 1));
    final payload = {
      'entry': {
        for (final e in row.entries)
          if (!const ['memo', 'photoId', 'lensInventoryId'].contains(e.key))
            e.key: e.value,
      },
      'masters': masters,
    };
    final encoded = jsonEncode(payload);
    if (utf8.encode(encoded).length > 24000) {
      throw const FormatException('カレンダー連携用の作品・衣装情報が大きすぎます');
    }
    final runes = encoded.runes.toList();
    final parts = <String>[];
    for (var start = 0; start < runes.length; start += 900) {
      parts.add(
        String.fromCharCodes(
          runes.sublist(
            start,
            start + 900 < runes.length ? start + 900 : runes.length,
          ),
        ),
      );
    }
    final memo = row['memo'] as String? ?? '';
    if (utf8.encode(memo).length > 16000) {
      throw const FormatException('カレンダーへ送るメモはUTF-8で16KB以内にしてください');
    }
    String name(String key) =>
        (masters[key] as List).firstOrNull?['name'] as String? ?? '未指定';
    final label = _label(row['activityType'] as String);
    final description =
        'コスプレ日記\n活動日: $date\n活動種別: $label\n作品: ${name('genres')}\nキャラクター: ${name('characters')}\n衣装: ${name('costumes')}$memoMarker$memo';
    return {
      'id': eventId(row['id'] as String),
      'summary': title(row, masters),
      'description': description,
      'start': {'date': date},
      'end': {'date': _formatDay(next)},
      'status': 'confirmed',
      'visibility': 'private',
      'transparency': 'transparent',
      'reminders': {'useDefault': false, 'overrides': <dynamic>[]},
      'extendedProperties': {
        'private': {
          'app': appTag,
          'diaryId': row['id'],
          'parts': '${parts.length}',
          for (var i = 0; i < parts.length; i++) 'data$i': parts[i],
        },
      },
    };
  }

  String title(Map<String, dynamic> row, Map<String, dynamic> masters) {
    final override = (row['calendarTitle'] as String? ?? '').trim();
    if (override.isNotEmpty) return override;
    final names = <String>[
      for (final key in ['genres', 'characters', 'costumes'])
        if ((masters[key] as List).isNotEmpty)
          (masters[key] as List).first['name'] as String,
    ];
    final label = _label(row['activityType'] as String);
    return '[$label] ${names.isEmpty ? 'コスプレ日記' : names.join(' / ')}';
  }

  CalendarDiary decode(Map<String, dynamic> event, String calendarId) {
    if (event['recurrence'] != null || event['recurringEventId'] != null) {
      throw const FormatException('繰り返し予定は日記へ同期できません。単発の予定にしてください');
    }
    final props = Map<String, dynamic>.from(
      event['extendedProperties']?['private'] ?? {},
    );
    final start = Map<String, dynamic>.from(event['start'] ?? {});
    final date = start['date'] as String? ?? start['dateTime'] as String?;
    if (date == null) throw const FormatException('予定の活動日がありません');
    final day = _day(date);
    final description = event['description'] as String? ?? '';
    final summary = event['summary'] as String? ?? '名称未設定の予定';
    if (props['app'] == appTag) {
      final count = int.tryParse(props['parts'] as String? ?? '') ?? 0;
      if (count < 1 || count > 32) throw const FormatException('日記の同期情報が不正です');
      final buffer = StringBuffer();
      for (var i = 0; i < count; i++) {
        final part = props['data$i'];
        if (part is! String) throw const FormatException('日記の同期情報が不足しています');
        buffer.write(part);
      }
      final payload = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      final row = Map<String, dynamic>.from(payload['entry']);
      final masters = Map<String, dynamic>.from(payload['masters']);
      if (row['id'] != props['diaryId']) {
        throw const FormatException('日記IDが一致しません');
      }
      _validateReferences(row, masters);
      final expectedTitle = title(row, masters);
      final marker = description.indexOf(memoMarker);
      row['memo'] = marker < 0
          ? description
          : description.substring(marker + memoMarker.length);
      row['activityDate'] = '${day}T00:00:00.000';
      row['calendarTitle'] = summary == expectedTitle
          ? row['calendarTitle'] ?? ''
          : summary;
      row['updatedAt'] = event['updated'] ?? row['updatedAt'];
      row['photoId'] = null;
      row['lensInventoryId'] = null;
      return CalendarDiary(row, masters);
    }
    if (props.containsKey('app')) {
      throw const FormatException('未対応のアプリが作成した予定です');
    }
    return CalendarDiary(
      {
        'id': 'gcal:$calendarId:${event['id']}',
        'activityDate': '${day}T00:00:00.000',
        'activityType': 'other',
        'genreId': null,
        'characterId': null,
        'costumeId': null,
        'memo': description,
        'calendarTitle': summary,
        'photoId': null,
        'lensInventoryId': null,
        'createdAt': event['created'] ?? '${day}T00:00:00.000',
        'updatedAt': event['updated'] ?? '${day}T00:00:00.000',
      },
      {
        'genres': <dynamic>[],
        'characters': <dynamic>[],
        'costumes': <dynamic>[],
      },
    );
  }

  Map<String, dynamic> merge(
    Map<String, dynamic> state,
    CalendarDiary imported,
  ) {
    final merged = jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
    for (final key in ['genres', 'characters', 'costumes']) {
      final list = merged[key] as List;
      for (final raw in imported.masters[key] as List) {
        if (!list.any((e) => e['id'] == raw['id'])) list.add(raw);
      }
    }
    final entries = merged['diary'] as List;
    final index = entries.indexWhere((e) => e['id'] == imported.entry['id']);
    final row = Map<String, dynamic>.from(imported.entry);
    if (index >= 0) {
      row['photoId'] = entries[index]['photoId'];
      row['lensInventoryId'] = entries[index]['lensInventoryId'];
      entries[index] = row;
    } else {
      entries.add(row);
    }
    return merged;
  }

  String localFingerprint(
    Map<String, dynamic> row,
    Map<String, dynamic> state,
  ) => fingerprint({
    'entry': {
      for (final e in row.entries)
        if (!const [
          'photoId',
          'lensInventoryId',
          'createdAt',
          'updatedAt',
        ].contains(e.key))
          e.key: e.value,
      'calendarTitle': row['calendarTitle'] ?? '',
    },
    'masters': _mastersFor(row, state),
  });

  String remoteFingerprint(Map<String, dynamic> event) => fingerprint({
    for (final key in [
      'summary',
      'description',
      'start',
      'end',
      'status',
      'extendedProperties',
      'recurrence',
    ])
      key: event[key],
  });

  bool same(
    Map<String, dynamic> local,
    Map<String, dynamic> state,
    CalendarDiary remote,
  ) {
    final remoteState = <String, dynamic>{...state, ...remote.masters};
    return localFingerprint(local, state) ==
        localFingerprint(remote.entry, remoteState);
  }

  Map<String, dynamic> _mastersFor(
    Map<String, dynamic> row,
    Map<String, dynamic> state,
  ) {
    List<Map<String, dynamic>> selected(
      String key,
      String? id,
      List<String> fields,
    ) => [
      for (final raw in state[key] as List)
        if (raw['id'] == id) {for (final key in fields) key: raw[key]},
    ];
    return {
      'genres': selected('genres', row['genreId'] as String?, ['id', 'name']),
      'characters': selected('characters', row['characterId'] as String?, [
        'id',
        'name',
        'genreId',
      ]),
      'costumes': selected('costumes', row['costumeId'] as String?, [
        'id',
        'name',
        'isGeneral',
        'genreId',
        'characterIds',
        'characterId',
      ]),
    };
  }

  void _validateReferences(
    Map<String, dynamic> row,
    Map<String, dynamic> masters,
  ) {
    final type = row['activityType'] as String;
    _label(type);
    for (final pair in {
      'genres': 'genreId',
      'characters': 'characterId',
      'costumes': 'costumeId',
    }.entries) {
      final id = row[pair.value];
      if (type == 'cosplay' && id == null) {
        throw const FormatException('コスプレ日記の関連情報が不足しています');
      }
      if (id != null &&
          !(masters[pair.key] as List).any((e) => e['id'] == id)) {
        throw const FormatException('日記に関連する作品・キャラクター・衣装が見つかりません');
      }
    }
  }

  String _day(String value) {
    final date = DateTime.parse(value);
    // Date-only and offset strings keep the provider's displayed calendar day.
    return value.length >= 10 ? value.substring(0, 10) : _formatDay(date);
  }

  String _formatDay(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String _label(String type) => switch (type) {
    'cosplay' => 'コスプレ',
    'photographer' => 'カメラマン',
    'other' => 'その他',
    _ => throw const FormatException('活動種別が不正です'),
  };

  static String fingerprint(Object? value) => jsonEncode(_sorted(value));
  static Object? _sorted(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _sorted(value[key])};
    }
    if (value is List) return value.map(_sorted).toList();
    return value;
  }
}
