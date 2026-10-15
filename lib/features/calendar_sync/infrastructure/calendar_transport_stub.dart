import 'calendar_transport.dart';

CalendarTransport createCalendarTransport() => _UnavailableCalendar();

class _UnavailableCalendar implements CalendarTransport {
  @override
  bool get supported => false;
  Never _unavailable() =>
      throw UnsupportedError('Googleカレンダー連携はWeb/PWA版で利用できます');
  @override
  Future<CalendarConnection> connect(
    String clientId, {
    List<String> knownCalendarIds = const [],
  }) async => _unavailable();
  @override
  Future<List<Map<String, dynamic>>> listEvents() async => _unavailable();
  @override
  Future<Map<String, dynamic>> putEvent(
    Map<String, dynamic> event, {
    String? existingId,
    String? etag,
  }) async => _unavailable();
  @override
  Future<void> deleteEvent(String id, String etag) async => _unavailable();
  @override
  Future<void> setVisible(bool visible) async => _unavailable();
  @override
  Future<void> disconnect() async {}
}
