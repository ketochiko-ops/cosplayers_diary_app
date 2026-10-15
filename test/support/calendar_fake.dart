import 'dart:convert';

import 'package:cosplayers_diary/core/services/clock.dart';
import 'package:cosplayers_diary/features/calendar_sync/infrastructure/calendar_transport.dart';

class MutableCalendarClock implements Clock {
  DateTime value = DateTime(2026, 10, 15, 12);
  @override
  DateTime now() => value;
}

class FakeCalendarTransport implements CalendarTransport {
  final events = <String, Map<String, dynamic>>{};
  int reads = 0;
  int writes = 0;
  int deleted = 0;
  int sequence = 0;
  bool visible = false;
  bool failRead = false;
  bool failWrite = false;
  bool loseWriteResponse = false;
  Future<void> Function()? onRead;
  String id = 'dedicated';
  @override
  bool get supported => true;
  Map<String, dynamic> clone(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  @override
  Future<CalendarConnection> connect(
    String clientId, {
    List<String> knownCalendarIds = const [],
  }) async => CalendarConnection(id: id, name: 'コスプレ日記', selected: visible);
  @override
  Future<List<Map<String, dynamic>>> listEvents() async {
    reads++;
    await onRead?.call();
    if (failRead) throw StateError('offline');
    return events.values.map(clone).toList();
  }

  @override
  Future<Map<String, dynamic>> putEvent(
    Map<String, dynamic> event, {
    String? existingId,
    String? etag,
  }) async {
    if (failWrite) throw StateError('uncertain write');
    final key = existingId ?? event['id'] as String;
    if (existingId != null && events[key]?['etag'] != etag) {
      throw StateError('etag conflict');
    }
    if (existingId == null && events.containsKey(key)) {
      throw StateError('duplicate');
    }
    writes++;
    final saved = clone(event)
      ..['id'] = key
      ..['etag'] = 'etag-${sequence++}';
    events[key] = saved;
    if (loseWriteResponse) {
      loseWriteResponse = false;
      throw StateError('response lost');
    }
    return clone(saved);
  }

  @override
  Future<void> deleteEvent(String id, String etag) async {
    if (events[id]?['etag'] != etag) throw StateError('etag conflict');
    events[id]!['status'] = 'cancelled';
    events[id]!['etag'] = 'etag-${sequence++}';
    deleted++;
  }

  @override
  Future<void> setVisible(bool value) async {
    visible = value;
  }

  @override
  Future<void> disconnect() async {}
}
