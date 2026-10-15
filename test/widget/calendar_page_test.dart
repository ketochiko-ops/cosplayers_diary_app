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
      expect(
        tester
            .widget<DropdownButton<int>>(
              find.byKey(const ValueKey('calendar-year')),
            )
            .value,
        2026,
      );
      expect(
        tester
            .widget<DropdownButton<int>>(
              find.byKey(const ValueKey('calendar-month')),
            )
            .value,
        1,
      );
      expect(find.text('この日に日記を追加'), findsNothing);
      await tester.tap(find.byTooltip('前の月'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<int>>(
              find.byKey(const ValueKey('calendar-year')),
            )
            .value,
        2025,
      );
      expect(
        tester
            .widget<DropdownButton<int>>(
              find.byKey(const ValueKey('calendar-month')),
            )
            .value,
        12,
      );
    },
  );

  testWidgets('year and month menus jump and clear the selected day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarPage(
            store: DiaryStore(),
            masterStore: MasterDataStore(),
            initialMonth: DateTime(2026, 10),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey(DateTime(2026, 10, 15))));
    await tester.pumpAndSettle();
    expect(find.text('この日に日記を追加'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calendar-year')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2030年').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-month')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2月').last);
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey(DateTime(2030, 2, 1))), findsOneWidget);
    expect(find.text('この日に日記を追加'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'calendar and diary list show event, character and tagged costume',
    (tester) async {
      final masters = MasterDataStore();
      final genre = masters.addGenre('作品');
      final character = masters.addCharacter(genre.id, '主人公');
      final costume = masters.addCostume(
        'メイド服',
        isGeneral: false,
        genreIds: [genre.id],
        characterIds: [character.id],
        tags: ['黒', 'ロング'],
      );
      final diary = DiaryStore()
        ..save(
          DiaryEntry(
            id: 'event',
            activityDate: DateTime(2026, 10, 15),
            activityType: ActivityType.cosplay,
            genreId: genre.id,
            characterId: character.id,
            costumeId: costume.id,
            calendarTitle: '秋の撮影会',
          ),
        );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarPage(
              store: diary,
              masterStore: masters,
              initialMonth: DateTime(2026, 10),
            ),
          ),
        ),
      );
      expect(find.text('秋の撮影会'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey(DateTime(2026, 10, 15))));
      await tester.pumpAndSettle();
      expect(find.textContaining('イベント: 秋の撮影会'), findsOneWidget);
      expect(find.textContaining('キャラ: 主人公'), findsOneWidget);
      expect(find.textContaining('衣装: メイド服（黒・ロング）'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: DiaryListPage(store: diary, masterStore: masters),
        ),
      );
      expect(find.textContaining('イベント: 秋の撮影会'), findsOneWidget);
      expect(find.textContaining('キャラ: 主人公'), findsOneWidget);
      expect(find.textContaining('衣装: メイド服（黒・ロング）'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

  testWidgets('calendar warns when an archived master is deleted', (
    tester,
  ) async {
    final masters = MasterDataStore();
    final genre = masters.addGenre('作品');
    final character = masters.addCharacter(genre.id, 'キャラ');
    final costume = masters.addCostume('衣装', isGeneral: true);
    final diary = DiaryStore()
      ..save(
        DiaryEntry(
          id: 'missing-master',
          activityDate: DateTime(2026, 10, 15),
          activityType: ActivityType.cosplay,
          genreId: genre.id,
          characterId: character.id,
          costumeId: costume.id,
          calendarTitle: '秋の撮影会',
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarPage(
            store: diary,
            masterStore: masters,
            initialMonth: DateTime(2026, 10),
          ),
        ),
      ),
    );
    masters.archiveCostume(costume.id);
    masters.deleteArchivedCostume(costume.id);
    await tester.pumpAndSettle();
    expect(find.text('⚠ 秋の撮影会'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey(DateTime(2026, 10, 15))));
    await tester.pumpAndSettle();
    expect(find.textContaining('衣装: 取得できませんでした'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('diary list confirms deletion from its menu', (tester) async {
    final diary = DiaryStore()
      ..save(
        DiaryEntry(
          id: 'mistake',
          activityDate: DateTime(2026, 10, 15),
          activityType: ActivityType.other,
          calendarTitle: '誤登録',
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: DiaryListPage(store: diary, masterStore: MasterDataStore()),
      ),
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(diary.entries, hasLength(1));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();
    expect(diary.entries, isEmpty);
    expect(find.text('日記はまだありません'), findsOneWidget);
  });

  testWidgets('recurring event name appears on calendar and diary list', (
    tester,
  ) async {
    final masters = MasterDataStore();
    final event = masters.addEvent('アコスタ池袋');
    final diary = DiaryStore()
      ..save(
        DiaryEntry(
          id: 'visit',
          activityDate: DateTime(2026, 10, 15),
          activityType: ActivityType.other,
          eventId: event.id,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarPage(
            store: diary,
            masterStore: masters,
            initialMonth: DateTime(2026, 10),
          ),
        ),
      ),
    );
    expect(find.text('アコスタ池袋'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey(DateTime(2026, 10, 15))));
    await tester.pumpAndSettle();
    expect(find.textContaining('参加イベント: アコスタ池袋'), findsOneWidget);
    masters.archiveEvent(event.id);
    masters.deleteArchivedEvent(event.id);
    await tester.pumpAndSettle();
    expect(find.text('⚠ 取得できませんでした'), findsOneWidget);
    expect(find.textContaining('参加イベント: 取得できませんでした'), findsOneWidget);
  });
}
