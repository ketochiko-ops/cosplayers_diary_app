import 'package:cosplayers_diary/core/database/app_state_persistence.dart';
import 'package:cosplayers_diary/features/calendar_sync/application/calendar_sync_controller.dart';
import 'package:cosplayers_diary/features/calendar_sync/presentation/calendar_sync_card.dart';
import 'package:cosplayers_diary/features/contact_lenses/application/lens_store.dart';
import 'package:cosplayers_diary/features/diary/application/diary_store.dart';
import 'package:cosplayers_diary/features/master_data/application/master_data_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/calendar_fake.dart';
import '../support/project_storage_fake.dart';

void main() {
  late CalendarSyncController sync;
  late FakeCalendarTransport remote;
  setUp(() async {
    final settings = MemorySettingsStore();
    final persistence = AppStatePersistence(
      store: settings,
      masters: MasterDataStore(),
      diary: DiaryStore(),
      lenses: LensStore(),
    );
    remote = FakeCalendarTransport();
    sync = CalendarSyncController(
      persistence: persistence,
      settings: settings,
      transport: remote,
      clock: MutableCalendarClock(),
    );
    await sync.load();
  });
  tearDown(() => sync.dispose());
  testWidgets(
    'an unconfigured app cannot launch OAuth but Gemini guidance remains readable',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [CalendarSyncCard(sync: sync, clientId: '')],
            ),
          ),
        ),
      );
      expect(find.text('サイト運営者によるGoogleカレンダーの設定待ちです。'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Googleカレンダーに接続'),
      );
      expect(button.onPressed, isNull);
      expect(remote.reads, 0);
    },
  );
  testWidgets('consent is explicit; cancellation performs no sync', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [CalendarSyncCard(sync: sync, clientId: 'test-id')],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Googleカレンダーに接続'));
    await tester.pumpAndSettle();
    expect(find.text('日記・予定をGoogleと同期しますか？'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(remote.reads, 0);
  });
  testWidgets(
    'connected phone layout supports visibility toggle and displays daily budget',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => sync.connect('test-id'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [CalendarSyncCard(sync: sync, clientId: 'test-id')],
            ),
          ),
        ),
      );
      expect(find.text('この端末・ブラウザで本日 1 / 10回（残り9回）'), findsOneWidget);
      final visible = find.widgetWithText(SwitchListTile, 'Googleカレンダーに表示');
      await tester.ensureVisible(visible);
      await tester.tap(visible);
      await tester.pumpAndSettle();
      expect(remote.visible, isTrue);
      expect(sync.usedToday, 1);
    },
  );
}
