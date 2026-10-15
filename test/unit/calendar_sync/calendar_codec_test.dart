import 'package:cosplayers_diary/features/calendar_sync/domain/calendar_codec.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> calendarState() => {
  'genres': [
    {'id': 'g', 'name': '作品A'},
  ],
  'characters': [
    {'id': 'c', 'genreId': 'g', 'name': 'キャラA'},
  ],
  'costumes': [
    {'id': 's', 'characterId': 'c', 'name': '制服', 'isGeneral': false},
  ],
  'diary': [
    {
      'id': 'diary-1',
      'activityDate': '2026-10-31T00:00:00.000',
      'activityType': 'cosplay',
      'genreId': 'g',
      'characterId': 'c',
      'costumeId': 's',
      'memo': '撮影会\n集合は10時',
      'calendarTitle': '',
      'photoId': 'private-photo',
      'lensInventoryId': 'private-lens',
      'createdAt': '2026-10-01T00:00:00.000',
      'updatedAt': '2026-10-01T00:00:00.000',
    },
  ],
  'lensProducts': [],
  'lensPurchases': [],
  'lensInventories': [],
  'lensUsages': [],
};

void main() {
  const codec = CalendarCodec();
  test(
    'event exposes readable Japanese fields and uses exclusive next-day end',
    () {
      final state = calendarState();
      final row = (state['diary'] as List).single as Map<String, dynamic>;
      final event = codec.encode(row, state);
      expect(event['summary'], '[コスプレ] 作品A / キャラA / 制服');
      expect(event['description'], contains('メモ:\n撮影会\n集合は10時'));
      expect(event['end'], {'date': '2026-11-01'});
      expect(event.toString(), isNot(contains('private-photo')));
      expect(event.toString(), isNot(contains('private-lens')));
      expect(event['transparency'], 'transparent');
      expect(event['reminders'], {'useDefault': false, 'overrides': []});
    },
  );
  test('remote date and Gemini title edits survive import and re-export', () {
    final state = calendarState();
    final row = (state['diary'] as List).single as Map<String, dynamic>;
    final event = codec.encode(row, state)
      ..['summary'] = '撮影会を延期'
      ..['start'] = {'date': '2026-11-03'};
    final imported = codec.decode(event, 'calendar-1');
    final merged = codec.merge(state, imported);
    final next = codec.encode((merged['diary'] as List).single, merged);
    expect(next['summary'], '撮影会を延期');
    expect(next['start'], {'date': '2026-11-03'});
    expect((merged['diary'] as List).single['photoId'], 'private-photo');
  });
  test('another device can reconstruct the referenced masters', () {
    final state = calendarState();
    (state['characters'] as List).add({
      'id': 'c2',
      'genreId': 'g',
      'name': 'キャラB',
    });
    (state['costumes'] as List).single
      ..['genreId'] = 'g'
      ..['genreIds'] = ['g']
      ..['characterIds'] = ['c', 'c2']
      ..['tags'] = ['夏用', '青'];
    final event = codec.encode((state['diary'] as List).single, state);
    expect(event['summary'], contains('制服（夏用・青）'));
    expect(event['description'], contains('制服（夏用・青）'));
    final empty = calendarState();
    for (final key in ['diary', 'genres', 'characters', 'costumes']) {
      empty[key] = [];
    }
    final restored = codec.merge(empty, codec.decode(event, 'calendar-1'));
    expect((restored['characters'] as List).single['name'], 'キャラA');
    expect((restored['costumes'] as List).single['genreId'], 'g');
    expect((restored['costumes'] as List).single['genreIds'], ['g']);
    expect((restored['costumes'] as List).single['characterIds'], ['c', 'c2']);
    expect((restored['costumes'] as List).single['tags'], ['夏用', '青']);
    expect((restored['diary'] as List).single['lensInventoryId'], isNull);
  });
  test(
    'a plain event created by Gemini can become an other-activity diary',
    () {
      final decoded = codec.decode({
        'id': 'google-event',
        'summary': '衣装を準備する',
        'description': '小物を確認',
        'start': {'date': '2026-11-01'},
        'created': '2026-10-15T00:00:00Z',
      }, 'calendar-1');
      expect(decoded.entry['activityType'], 'other');
      expect(decoded.entry['calendarTitle'], '衣装を準備する');
      expect(decoded.entry['memo'], '小物を確認');
    },
  );
  test('metadata exceeding provider capacity fails instead of truncating', () {
    final state = calendarState();
    (state['genres'] as List).single['name'] = '長' * 40000;
    expect(
      () => codec.encode((state['diary'] as List).single, state),
      throwsFormatException,
    );
  });
  test('missing master reports an understandable sync error', () {
    final state = calendarState();
    (state['costumes'] as List).clear();
    expect(
      () => codec.encode((state['diary'] as List).single, state),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('取得できませんでした'),
        ),
      ),
    );
  });
  test('event master travels with the diary and names the calendar event', () {
    final state = calendarState()
      ..['events'] = [
        {'id': 'event-1', 'name': 'アコスタ池袋'},
      ];
    final row = (state['diary'] as List).single as Map<String, dynamic>;
    row['eventId'] = 'event-1';
    final event = codec.encode(row, state);
    expect(event['summary'], 'アコスタ池袋');
    expect(event['description'], contains('参加イベント: アコスタ池袋'));
    final imported = codec.decode(event, 'calendar-1');
    expect(imported.entry['eventId'], 'event-1');
    final empty = calendarState()
      ..['events'] = []
      ..['diary'] = [];
    final restored = codec.merge(empty, imported);
    expect((restored['events'] as List).single['name'], 'アコスタ池袋');
  });
}
