import 'dart:convert';
import 'dart:js_interop';

import 'calendar_transport.dart';

@JS('cosplayCalendar.connect')
external JSPromise<JSString> _connect(
  JSString clientId,
  JSString knownCalendarIds,
);
@JS('cosplayCalendar.listEvents')
external JSPromise<JSString> _listEvents();
@JS('cosplayCalendar.putEvent')
external JSPromise<JSString> _putEvent(
  JSString event,
  JSString? id,
  JSString? etag,
);
@JS('cosplayCalendar.deleteEvent')
external JSPromise<JSAny?> _deleteEvent(JSString id, JSString etag);
@JS('cosplayCalendar.setVisible')
external JSPromise<JSAny?> _setVisible(JSBoolean value);
@JS('cosplayCalendar.disconnect')
external JSPromise<JSAny?> _disconnect();

CalendarTransport createCalendarTransport() => _WebCalendar();

class _WebCalendar implements CalendarTransport {
  @override
  bool get supported => true;
  @override
  Future<CalendarConnection> connect(
    String clientId, {
    List<String> knownCalendarIds = const [],
  }) async => CalendarConnection.fromJson(
    jsonDecode(
      (await _connect(
        clientId.toJS,
        jsonEncode(knownCalendarIds).toJS,
      ).toDart).toDart,
    ) as Map<String, dynamic>,
  );
  @override
  Future<List<Map<String, dynamic>>> listEvents() async =>
      (jsonDecode((await _listEvents().toDart).toDart) as List)
          .cast<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> putEvent(
    Map<String, dynamic> event, {
    String? existingId,
    String? etag,
  }) async => jsonDecode(
    (await _putEvent(
      jsonEncode(event).toJS,
      existingId?.toJS,
      etag?.toJS,
    ).toDart).toDart,
  ) as Map<String, dynamic>;
  @override
  Future<void> deleteEvent(String id, String etag) async {
    await _deleteEvent(id.toJS, etag.toJS).toDart;
  }

  @override
  Future<void> setVisible(bool visible) async {
    await _setVisible(visible.toJS).toDart;
  }

  @override
  Future<void> disconnect() async {
    await _disconnect().toDart;
  }
}
