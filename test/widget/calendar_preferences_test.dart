import 'package:cosplayers_diary/app/app.dart';
import 'package:cosplayers_diary/core/database/project_sync_controller.dart';
import 'package:cosplayers_diary/features/settings/domain/calendar_week_start.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/project_storage_fake.dart';

class FailingWeekSettings extends MemorySettingsStore {
  @override
  Future<void> writeSetting(String key, String value) async {
    if (key == CalendarWeekStart.settingKey) throw StateError('保存に失敗');
    await super.writeSetting(key, value);
  }
}

Future<void> chooseWeekStart(
  WidgetTester tester,
  String current,
  String next,
) async {
  await tester.tap(find.text('設定'));
  await tester.pumpAndSettle();
  final field = find.text(current);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(next).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'defaults to Monday, switches both ways and remembers Sunday after restart',
    (tester) async {
      final settings = MemorySettingsStore()
        ..values[ProjectSyncController.preferenceKey] = 'browser';
      Future<void> start() async {
        await tester.pumpWidget(
          CosplayDiaryApp(
            settingsStore: settings,
            projectStorage: FakeProjectStorage(),
          ),
        );
        await tester.pumpAndSettle();
      }

      await start();
      expect(
        tester.getCenter(find.text('月')).dx,
        lessThan(tester.getCenter(find.text('日')).dx),
      );
      await chooseWeekStart(tester, '月曜日始まり', '日曜日始まり');
      expect(settings.values[CalendarWeekStart.settingKey], 'sunday');
      await tester.tap(find.text('カレンダー'));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('日')).dx,
        lessThan(tester.getCenter(find.text('月')).dx),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await start();
      expect(
        tester.getCenter(find.text('日')).dx,
        lessThan(tester.getCenter(find.text('月')).dx),
      );
      await chooseWeekStart(tester, '日曜日始まり', '月曜日始まり');
      expect(settings.values[CalendarWeekStart.settingKey], 'monday');
      await tester.tap(find.text('カレンダー'));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('月')).dx,
        lessThan(tester.getCenter(find.text('日')).dx),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('a failed settings write keeps the current week start', (
    tester,
  ) async {
    final settings = FailingWeekSettings()
      ..values[ProjectSyncController.preferenceKey] = 'browser';
    await tester.pumpWidget(
      CosplayDiaryApp(
        settingsStore: settings,
        projectStorage: FakeProjectStorage(),
      ),
    );
    await tester.pumpAndSettle();
    await chooseWeekStart(tester, '月曜日始まり', '日曜日始まり');
    expect(find.textContaining('週の始まりを保存できませんでした'), findsOneWidget);
    final state = tester.state<FormFieldState<CalendarWeekStart>>(
      find.byWidgetPredicate(
        (widget) => widget is DropdownButtonFormField<CalendarWeekStart>,
      ),
    );
    expect(state.value, CalendarWeekStart.monday);
    expect(settings.values[CalendarWeekStart.settingKey], isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
