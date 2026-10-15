import 'package:cosplayers_diary/features/calendar_sync/domain/calendar_codec.dart';
import 'package:cosplayers_diary/features/calendar_sync/domain/calendar_plan.dart';
import 'package:flutter_test/flutter_test.dart';

import 'calendar_codec_test.dart' show calendarState;

void main() {
  const codec = CalendarCodec();
  const planner = CalendarPlanner();
  late Map<String, dynamic> state;
  late Map<String, dynamic> event;
  late Map<String, dynamic> baseline;
  setUp(() {
    state = calendarState();
    event = codec.encode((state['diary'] as List).single, state)
      ..['etag'] = 'one';
    baseline = {
      'diary-1': {
        'eventId': event['id'],
        'local': codec.localFingerprint((state['diary'] as List).single, state),
        'remote': codec.remoteFingerprint(event),
      },
    };
  });
  CalendarAction action({Map<String, dynamic>? base}) => planner
      .plan(
        state: state,
        events: [event],
        baseline: base ?? baseline,
        calendarId: 'cal',
      )
      .single
      .action;

  test('unchanged data does not write and canonical comparison ignores property order', () {
    event = Map.fromEntries(event.entries.toList().reversed);
    expect(action(), CalendarAction.unchanged);
  });
  test('local changes upload while remote changes download', () {
    (state['diary'] as List).single['memo'] = '変更';
    expect(action(), CalendarAction.upload);
    (state['diary'] as List).single['memo'] = '撮影会\n集合は10時';
    event['summary'] = 'Googleで変更';
    expect(action(), CalendarAction.download);
  });
  test(
    'a new device imports remote entries instead of deleting unknown ones',
    () {
      state['diary'] = [];
      expect(action(base: {}), CalendarAction.download);
    },
  );
  test(
    'first connection never overwrites different data with the same diary ID',
    () {
      (state['diary'] as List).single['memo'] = '端末';
      expect(action(base: {}), CalendarAction.conflict);
    },
  );
  test('duplicates or unsupported metadata cannot produce partial plans', () {
    expect(
      () => planner.plan(
        state: state,
        events: [
          event,
          {...event, 'id': 'duplicate'},
        ],
        baseline: baseline,
        calendarId: 'cal',
      ),
      throwsFormatException,
    );
  });
  test(
    'related master name changes are part of the local change projection',
    () {
      (state['genres'] as List).single['name'] = '名前を修正';
      expect(action(), CalendarAction.upload);
    },
  );
}
