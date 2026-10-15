import 'calendar_transport_stub.dart'
    if (dart.library.js_interop) 'calendar_transport_web.dart'
    as platform;

class CalendarConnection {
  const CalendarConnection({
    required this.id,
    required this.name,
    required this.selected,
  });
  final String id;
  final String name;
  final bool selected;
  factory CalendarConnection.fromJson(Map<String, dynamic> json) =>
      CalendarConnection(
        id: json['id'] as String,
        name: json['name'] as String,
        selected: json['selected'] == true,
      );
}

abstract interface class CalendarTransport {
  bool get supported;
  Future<CalendarConnection> connect(
    String clientId, {
    List<String> knownCalendarIds = const [],
  });
  Future<List<Map<String, dynamic>>> listEvents();
  Future<Map<String, dynamic>> putEvent(
    Map<String, dynamic> event, {
    String? existingId,
    String? etag,
  });
  Future<void> deleteEvent(String id, String etag);
  Future<void> setVisible(bool visible);
  Future<void> disconnect();
}

CalendarTransport createCalendarTransport() =>
    platform.createCalendarTransport();
