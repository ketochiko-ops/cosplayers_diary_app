import 'dart:convert';

import 'package:cosplayers_diary/core/database/app_state_persistence.dart';
import 'package:cosplayers_diary/features/calendar_sync/application/calendar_sync_controller.dart';
import 'package:cosplayers_diary/features/calendar_sync/domain/calendar_plan.dart';
import 'package:cosplayers_diary/features/contact_lenses/application/lens_store.dart';
import 'package:cosplayers_diary/features/contact_lenses/domain/lens_models.dart';
import 'package:cosplayers_diary/features/diary/application/diary_store.dart';
import 'package:cosplayers_diary/features/diary/domain/diary_models.dart';
import 'package:cosplayers_diary/features/master_data/application/master_data_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/calendar_fake.dart';
import '../../support/project_storage_fake.dart';

void main() {
  late MemorySettingsStore settings;
  late AppStatePersistence persistence;
  late DiaryStore diary;
  late FakeCalendarTransport remote;
  late MutableCalendarClock clock;
  late CalendarSyncController sync;
  setUp(() async {
    settings = MemorySettingsStore();
    diary = DiaryStore();
    persistence = AppStatePersistence(
      store: settings,
      masters: MasterDataStore(),
      diary: diary,
      lenses: LensStore(),
    );
    remote = FakeCalendarTransport();
    clock = MutableCalendarClock();
    sync = CalendarSyncController(
      persistence: persistence,
      settings: settings,
      transport: remote,
      clock: clock,
    );
    await sync.load();
  });
  tearDown(() => sync.dispose());
  DiaryEntry entry([String memo = '最初']) => DiaryEntry(
    id: 'diary-1',
    activityDate: DateTime(2026, 10, 31),
    activityType: ActivityType.other,
    memo: memo,
  );

  test(
    'connection is optional; connect syncs and repeated sync never duplicates',
    () async {
      diary.save(entry());
      await persistence.save();
      expect(remote.reads, 0);
      await sync.connect('id');
      expect(remote.events.length, 1);
      expect(sync.usedToday, 1);
      await sync.sync();
      expect(remote.writes, 1);
      expect(remote.events.length, 1);
    },
  );

  test('only first edit each day syncs automatically; remaining edits need manual sync', () async {
    await sync.connect('id');
    diary.save(entry());
    await persistence.save();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(remote.writes, 1);
    expect(sync.usedToday, 2);
    diary.save(entry('2回目'));
    await persistence.save();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(remote.writes, 1);
    expect(sync.pending, isTrue);
    await sync.sync();
    expect(remote.writes, 2);
    expect(sync.usedToday, 3);
    clock.value = clock.value.add(const Duration(days: 1));
    diary.save(entry('翌日'));
    await persistence.save();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(remote.writes, 3);
    expect(sync.usedToday, 1);
  });

  test(
    'manual save of a pending edit does not also queue an automatic run',
    () async {
      await sync.connect('id');
      diary.save(entry());
      await sync.sync();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(sync.usedToday, 2);
      expect(remote.writes, 1);
    },
  );

  test(
    'daily cap survives reload, account switching and failed attempts',
    () async {
      await sync.setAutomatic(false);
      await sync.connect('id');
      remote.failRead = true;
      for (var i = 0; i < 12; i++) {
        await sync.sync();
      }
      expect(sync.usedToday, 10);
      expect(remote.reads, 10);
      sync.dispose();
      sync = CalendarSyncController(
        persistence: persistence,
        settings: settings,
        transport: remote,
        clock: clock,
      );
      await sync.load();
      remote.id = 'another-account-calendar';
      await sync.connect('id');
      expect(sync.usedToday, 10);
      expect(remote.reads, 10);
    },
  );

  test('a second device imports diaries and an external date/title edit returns to app', () async {
    diary.save(entry());
    await sync.connect('id');
    final event = remote.events.values.single;
    event['summary'] = '延期した撮影会';
    event['start'] = {'date': '2026-11-03'};
    event['end'] = {'date': '2026-11-04'};
    event['etag'] = 'changed';
    await sync.sync();
    expect(diary.entries.single.calendarTitle, '延期した撮影会');
    expect(diary.entries.single.activityDate.day, 3);
    final secondPersistence = AppStatePersistence(
      store: MemorySettingsStore(),
      masters: MasterDataStore(),
      diary: DiaryStore(),
      lenses: LensStore(),
    );
    final second = CalendarSyncController(
      persistence: secondPersistence,
      settings: MemorySettingsStore(),
      transport: remote,
      clock: clock,
    );
    await second.load();
    await second.connect('id');
    expect(secondPersistence.diary.entries.single.calendarTitle, '延期した撮影会');
    expect(remote.writes, 1);
    second.dispose();
  });

  test(
    'both-side edits stop on conflict and the user can select Google data',
    () async {
      diary.save(entry());
      await sync.connect('id');
      await sync.setAutomatic(false);
      diary.save(entry('端末の変更'));
      await persistence.save();
      final event = remote.events.values.single;
      event['description'] = 'Googleから変更';
      event['etag'] = 'changed';
      await sync.sync();
      expect(sync.conflicts, hasLength(1));
      expect(diary.entries.single.memo, '端末の変更');
      expect(remote.writes, 1);
      await sync.sync(resolutions: {'diary-1': CalendarResolution.google});
      expect(diary.entries.single.memo, 'Googleから変更');
      expect(sync.conflicts, isEmpty);
    },
  );

  test(
    'deletion only propagates for previously synchronized diaries',
    () async {
      diary.save(entry());
      await sync.connect('id');
      await sync.setAutomatic(false);
      diary.delete('diary-1');
      await persistence.save();
      await sync.sync();
      expect(remote.deleted, 1);
      expect(diary.entries, isEmpty);
    },
  );

  test(
    'remote deletion removes a known local diary without resurrecting it',
    () async {
      diary.save(entry());
      await sync.connect('id');
      remote.events.values.single['status'] = 'cancelled';
      await sync.sync();
      expect(diary.entries, isEmpty);
      expect(remote.writes, 1);
    },
  );

  test('choosing local after a remote deletion creates a replacement without tombstone ETag', () async {
    diary.save(entry());
    await sync.connect('id');
    await sync.setAutomatic(false);
    final oldId = remote.events.keys.single;
    remote.events[oldId] = {'id': oldId, 'status': 'cancelled'};
    diary.save(entry('残したい変更'));
    await persistence.save();
    await sync.sync();
    expect(sync.conflicts, hasLength(1));
    await sync.sync(resolutions: {'diary-1': CalendarResolution.local});
    expect(
      remote.events.values.where((e) => e['status'] != 'cancelled'),
      hasLength(1),
    );
    expect(sync.conflicts, isEmpty);
    await sync.sync();
    expect(sync.paused, isFalse);
  });

  test('remote date changes protect lens usage and deletion restores one-day stock', () async {
    final lenses = persistence.lenses;
    final product = lenses.addProduct(
      name: '赤',
      manufacturer: 'メーカー',
      color: '赤',
      type: WearType.oneDay,
    );
    final purchase = lenses.addPurchase(
      productId: product.id,
      purchasedOn: DateTime(2026, 10, 1),
      quantity: 2,
    );
    final inventory = lenses.ledger.useOneDay(
      purchaseId: purchase.id,
      diaryId: 'diary-1',
      usedOn: DateTime(2026, 10, 31),
    );
    diary.save(entry().copyWith(lensInventoryId: inventory.id));
    await sync.connect('id');
    expect(lenses.ledger.unusedCount(purchase.id), 1);
    final event = remote.events.values.single;
    event['start'] = {'date': '2026-11-03'};
    event['end'] = {'date': '2026-11-04'};
    event['etag'] = 'changed';
    await sync.sync();
    expect(sync.paused, isTrue);
    expect(diary.entries.single.activityDate.day, 31);
    expect(lenses.ledger.usages, hasLength(1));
    event['status'] = 'cancelled';
    await sync.sync();
    expect(diary.entries, isEmpty);
    expect(lenses.ledger.usages, isEmpty);
    expect(lenses.ledger.inventories, isEmpty);
    expect(lenses.ledger.unusedCount(purchase.id), 2);
  });

  test(
    'a project switch disconnects before any further cloud writes',
    () async {
      diary.save(entry());
      await sync.connect('id');
      await sync.disconnect(projectChanged: true);
      diary.save(entry('別のプロジェクト'));
      await persistence.save();
      await sync.sync();
      expect(remote.writes, 1);
      expect(sync.connected, isFalse);
    },
  );

  test(
    'local edits during cloud reads never get overwritten by stale import',
    () async {
      diary.save(entry());
      await sync.connect('id');
      await sync.setAutomatic(false);
      remote.events.values.single['description'] = 'Google側';
      remote.onRead = () async {
        diary.save(entry('通信中の変更'));
        await persistence.save();
      };
      await sync.sync();
      expect(diary.entries.single.memo, '通信中の変更');
      expect(sync.paused, isTrue);
      expect(remote.writes, 1);
    },
  );

  test('an accepted upload with a lost response is reconciled without duplicate insertion', () async {
    diary.save(entry());
    remote.loseWriteResponse = true;
    await sync.connect('id');
    expect(sync.paused, isTrue);
    expect(remote.events, hasLength(1));
    await sync.sync();
    expect(remote.writes, 1);
    expect(sync.paused, isFalse);
    expect(diary.entries.single.memo, '最初');
  });

  test('automatic off leaves edits pending until the user syncs', () async {
    await sync.connect('id');
    await sync.setAutomatic(false);
    diary.save(entry());
    await persistence.save();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(remote.writes, 0);
    await sync.sync();
    expect(remote.writes, 1);
  });

  test('a first edit during a failed sync stays pending without an automatic retry', () async {
    await sync.connect('id');
    remote.onRead = () async {
      diary.save(entry('通信中の最初の編集'));
      await persistence.save();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      throw StateError('offline');
    };
    await sync.sync();
    final reads = remote.reads;
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    expect(remote.reads, reads);
    expect(sync.paused, isTrue);
    expect(sync.pending, isTrue);
    expect(diary.entries.single.memo, '通信中の最初の編集');
  });

  test(
    'first-edit automatic reservation survives reloading before later edits',
    () async {
      await sync.connect('id');
      diary.save(entry());
      await persistence.save();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      sync.dispose();
      sync = CalendarSyncController(
        persistence: persistence,
        settings: settings,
        transport: remote,
        clock: clock,
      );
      await sync.load();
      await sync.connect('id');
      final reads = remote.reads;
      diary.save(entry('再起動後'));
      await persistence.save();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(remote.reads, reads);
      expect(sync.pending, isTrue);
    },
  );

  test(
    'large initial upload is bounded and the next manual run continues',
    () async {
      for (var i = 0; i < 105; i++) {
        diary.save(entry().copyWith(id: 'diary-$i'));
      }
      await sync.connect('id');
      expect(remote.writes, 100);
      expect(sync.pending, isTrue);
      await sync.sync();
      expect(remote.writes, 105);
      expect(sync.pending, isFalse);
    },
  );

  test('older JSON without calendarTitle remains readable', () {
    diary.save(entry());
    final source = jsonDecode(persistence.exportJson()) as Map<String, dynamic>;
    (source['diary'] as List).single.remove('calendarTitle');
    persistence.restoreJson(jsonEncode(source));
    expect(diary.entries.single.calendarTitle, '');
    expect(diary.entries.single.memo, '最初');
  });

  test(
    'visibility toggle keeps events and does not consume a diary sync run',
    () async {
      diary.save(entry());
      await sync.connect('id');
      final count = sync.usedToday;
      await sync.setVisible(true);
      expect(sync.visible, isTrue);
      await sync.setVisible(false);
      expect(sync.visible, isFalse);
      expect(remote.events.length, 1);
      expect(sync.usedToday, count);
      expect(
        settings.values[CalendarSyncController.settingsKey],
        isNot(contains('test-token')),
      );
      expect(
        jsonDecode(settings.values[CalendarSyncController.settingsKey]!),
        isA<Map>(),
      );
    },
  );
}
