import 'package:cosplayers_diary/features/diary/application/diary_store.dart';
import 'package:cosplayers_diary/features/diary/domain/diary_models.dart';
import 'package:cosplayers_diary/features/diary/presentation/diary_form.dart';
import 'package:cosplayers_diary/features/diary/presentation/diary_pages.dart';
import 'package:cosplayers_diary/features/master_data/application/master_data_store.dart';
import 'package:cosplayers_diary/features/settings/domain/calendar_week_start.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final start in CalendarWeekStart.values) {
    testWidgets('aligns Sunday month start with ${start.name} weeks', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarPage(
              store: DiaryStore(),
              masterStore: MasterDataStore(),
              initialMonth: DateTime(2026, 2),
              weekStart: start,
            ),
          ),
        ),
      );
      final first = tester.getCenter(
        find.byKey(ValueKey(DateTime(2026, 2, 1))),
      );
      final sunday = tester.getCenter(find.text('日'));
      expect(first.dx, closeTo(sunday.dx, 0.1));
      expect(
        tester
            .getCenter(find.text(start == CalendarWeekStart.monday ? '月' : '日'))
            .dx,
        lessThan(
          tester
              .getCenter(
                find.text(start == CalendarWeekStart.monday ? '日' : '月'),
              )
              .dx,
        ),
      );
      await tester.tap(find.byKey(ValueKey(DateTime(2026, 2, 1))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('この日に日記を追加'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<DiaryForm>(find.byType(DiaryForm)).initialDate,
        DateTime(2026, 2, 1),
      );
    });
  }

  testWidgets(
    'uses compact rows on desktop and resets selection when crossing the year',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarPage(
              store: DiaryStore(),
              masterStore: MasterDataStore(),
              initialMonth: DateTime(2025, 12),
            ),
          ),
        ),
      );
      final first = tester.getTopLeft(
        find.byKey(ValueKey(DateTime(2025, 12, 1))),
      );
      final eighth = tester.getTopLeft(
        find.byKey(ValueKey(DateTime(2025, 12, 8))),
      );
      expect(eighth.dy - first.dy, 44);
      expect(tester.getTopLeft(find.text('日付を選択してください')).dy, lessThan(350));
      await tester.tap(find.byKey(ValueKey(DateTime(2025, 12, 31))));
      await tester.pumpAndSettle();
      expect(find.text('この日に日記を追加'), findsOneWidget);
      await tester.tap(find.byTooltip('次の月'));
      await tester.pumpAndSettle();
      expect(find.text('2026年 1月'), findsOneWidget);
      expect(find.text('この日に日記を追加'), findsNothing);
      await tester.tap(find.byTooltip('前の月'));
      await tester.pumpAndSettle();
      expect(find.text('2025年 12月'), findsOneWidget);
    },
  );

  testWidgets(
    'six-week calendar scrolls on a short phone with larger text and activity badges',
    (tester) async {
      tester.view.physicalSize = const Size(390, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final diary = DiaryStore()
        ..save(
          DiaryEntry(
            id: 'd',
            activityDate: DateTime(2026, 3, 31),
            activityType: ActivityType.other,
            memo: '月末のイベント',
          ),
        );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 300),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: CalendarPage(
                store: diary,
                masterStore: MasterDataStore(),
                initialMonth: DateTime(2026, 3),
              ),
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(ValueKey(DateTime(2026, 3, 31))),
        100,
      );
      await tester.tap(find.byKey(ValueKey(DateTime(2026, 3, 31))));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('月末のイベント'), 100);
      expect(find.text('月末のイベント'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
