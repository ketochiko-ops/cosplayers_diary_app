enum CalendarWeekStart {
  monday(DateTime.monday, '月曜日始まり'),
  sunday(DateTime.sunday, '日曜日始まり');

  const CalendarWeekStart(this.weekday, this.label);
  final int weekday;
  final String label;
  static const settingKey = 'calendar_week_start';

  static CalendarWeekStart fromSetting(String? value) =>
      value == sunday.name ? sunday : monday;
}
