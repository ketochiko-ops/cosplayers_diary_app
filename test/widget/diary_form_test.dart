import 'dart:async';
import 'dart:convert';

import 'package:cosplayers_diary/core/database/app_state_persistence.dart';
import 'package:cosplayers_diary/features/contact_lenses/application/lens_store.dart';
import 'package:cosplayers_diary/features/diary/application/diary_store.dart';
import 'package:cosplayers_diary/features/diary/domain/diary_models.dart';
import 'package:cosplayers_diary/features/diary/presentation/diary_form.dart';
import 'package:cosplayers_diary/features/master_data/application/master_data_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/project_storage_fake.dart';

Future<void> openForm(
  WidgetTester tester,
  MasterDataStore masters,
  DiaryStore diary, {
  DiaryEntry? entry,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DiaryForm(store: diary, masterStore: masters, entry: entry),
              ),
            ),
            child: const Text('開く'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('開く'));
  await tester.pumpAndSettle();
}

Future<void> addMaster(
  WidgetTester tester,
  String kind,
  String name, {
  bool general = false,
}) async {
  final button = find.byTooltip('$kindを追加');
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    button,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(button);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), name);
  if (general) await tester.tap(find.byType(CheckboxListTile));
  await tester.tap(find.text('追加して選択'));
  await tester.pumpAndSettle();
}

List<String?> selections(WidgetTester tester) => tester
    .stateList<FormFieldState<String>>(
      find.byWidgetPredicate(
        (widget) => widget is DropdownButtonFormField<String>,
      ),
    )
    .map((state) => state.value)
    .take(3)
    .toList();

void main() {
  testWidgets('existing diary can be deleted from its editor', (tester) async {
    final diary = DiaryStore()
      ..save(
        DiaryEntry(
          id: 'mistake',
          activityDate: DateTime(2026, 10, 15),
          activityType: ActivityType.other,
        ),
      );
    await openForm(
      tester,
      MasterDataStore(),
      diary,
      entry: diary.entries.single,
    );
    await tester.ensureVisible(find.text('この日記を削除'));
    await tester.tap(find.text('この日記を削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();
    expect(diary.entries, isEmpty);
    expect(find.text('開く'), findsOneWidget);
  });

  testWidgets('editor shows placeholders for deleted master references', (
    tester,
  ) async {
    final masters = MasterDataStore();
    final genre = masters.addGenre('作品');
    final character = masters.addCharacter(genre.id, 'キャラ');
    final costume = masters.addCostume('衣装', isGeneral: true);
    final diary = DiaryStore()
      ..save(
        DiaryEntry(
          id: 'historical',
          activityDate: DateTime(2026, 10, 15),
          activityType: ActivityType.cosplay,
          genreId: genre.id,
          characterId: character.id,
          costumeId: costume.id,
        ),
      );
    masters.archiveCostume(costume.id);
    masters.deleteArchivedCostume(costume.id);
    masters.archiveCharacter(character.id);
    masters.deleteArchivedCharacter(character.id);
    masters.archiveGenre(genre.id);
    masters.deleteArchivedGenre(genre.id);
    await openForm(tester, masters, diary, entry: diary.entries.single);
    expect(find.text('取得できませんでした'), findsNWidgets(3));
    expect(selections(tester), [genre.id, character.id, costume.id]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('diary can create and select a recurring event master', (
    tester,
  ) async {
    final masters = MasterDataStore();
    final diary = DiaryStore()
      ..save(
        DiaryEntry(
          id: 'visit',
          activityDate: DateTime(2026, 10, 15),
          activityType: ActivityType.other,
          calendarTitle: 'アコスタ池袋',
        ),
      );
    await openForm(tester, masters, diary, entry: diary.entries.single);
    await tester.ensureVisible(find.byTooltip('参加イベントを追加'));
    await tester.tap(find.byTooltip('参加イベントを追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'アコスタ池袋');
    await tester.tap(find.text('追加して選択'));
    await tester.pumpAndSettle();
    expect(masters.events.single.name, 'アコスタ池袋');
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(diary.entries.single.eventId, masters.events.single.id);
    expect(diary.entries.single.calendarTitle, isEmpty);
  });

  testWidgets(
    'creates the full master chain from a diary and autosaves linked IDs without losing its draft',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final masters = MasterDataStore();
      final diary = DiaryStore();
      final settings = MemorySettingsStore();
      final persistence = AppStatePersistence(
        store: settings,
        masters: masters,
        diary: diary,
        lenses: LensStore(),
      )..attach();
      addTearDown(() {
        unawaited(persistence.dispose());
      });
      await openForm(tester, masters, diary);
      final memo = find.widgetWithText(TextField, 'メモ');
      await tester.ensureVisible(memo);
      await tester.enterText(memo, '編集中のメモ');
      await addMaster(tester, 'ジャンル', '  新しい作品  ');
      await addMaster(tester, 'キャラクター', '主人公');
      await addMaster(tester, '衣装', '制服');
      final genre = masters.genres.single;
      final character = masters.characters.single;
      final costume = masters.costumes.single;
      expect(genre.name, '新しい作品');
      expect(character.genreId, genre.id);
      expect((costume.isGeneral, costume.characterId), (false, character.id));
      expect(selections(tester), [genre.id, character.id, costume.id]);
      await tester.ensureVisible(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      final saved = diary.entries.single;
      expect(
        (saved.genreId, saved.characterId, saved.costumeId, saved.memo),
        (genre.id, character.id, costume.id, '編集中のメモ'),
      );
      final state = jsonDecode(
        settings.values[AppStatePersistence.stateKey]!,
      ) as Map<String, dynamic>;
      expect(state['genres'].single['name'], '新しい作品');
      expect(state['characters'].single['genreId'], genre.id);
      expect(state['costumes'].single['characterId'], character.id);
      expect(state['diary'].single['costumeId'], costume.id);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'requires parent selection and does not register blank or cancelled names',
    (tester) async {
      final masters = MasterDataStore();
      await openForm(tester, masters, DiaryStore());
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'キャラクターを追加',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == '衣装を追加',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('ジャンルを追加'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(find.text('追加して選択'));
      await tester.pumpAndSettle();
      expect(find.text('名前を入力してください'), findsOneWidget);
      expect(masters.genres, isEmpty);
      await tester.enterText(find.byType(TextFormField), '保存しない作品');
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(masters.genres, isEmpty);
      expect(selections(tester), [null, null, null]);
    },
  );

  testWidgets(
    'adding parents clears lower selections and a general costume is available for another character',
    (tester) async {
      final masters = MasterDataStore();
      final genre = masters.addGenre('前の作品');
      final character = masters.addCharacter(genre.id, '前のキャラ');
      final costume = masters.addCostume(
        '専用衣装',
        isGeneral: false,
        characterId: character.id,
      );
      final entry = DiaryEntry(
        id: 'd',
        activityDate: DateTime(2026, 10, 15),
        activityType: ActivityType.cosplay,
        genreId: genre.id,
        characterId: character.id,
        costumeId: costume.id,
      );
      await openForm(tester, masters, DiaryStore()..save(entry), entry: entry);
      await addMaster(tester, 'ジャンル', '別の作品');
      expect(selections(tester), [masters.genres.last.id, null, null]);
      await addMaster(tester, 'キャラクター', '別のキャラ');
      await addMaster(tester, '衣装', '共通衣装', general: true);
      final general = masters.costumes.last;
      expect((general.isGeneral, general.characterId), (true, null));
      await addMaster(tester, 'キャラクター', 'さらに別のキャラ');
      expect(masters.characters.last.genreId, masters.genres.last.id);
      await tester.ensureVisible(find.byTooltip('衣装を追加'));
      final dropdowns = tester.widgetList<DropdownButton<String>>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DropdownButton<String> &&
              widget.items!.any((item) => item.value == general.id),
        ),
      );
      expect(dropdowns.single.items!.map((item) => item.value), [general.id]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('historical costume remains selected after its scope changes', (
    tester,
  ) async {
    final masters = MasterDataStore();
    final genre = masters.addGenre('作品');
    final original = masters.addCharacter(genre.id, '元のキャラ');
    final other = masters.addCharacter(genre.id, '別のキャラ');
    final costume = masters.addCostume('勝負服', isGeneral: true);
    final entry = DiaryEntry(
      id: 'historical',
      activityDate: DateTime(2026, 10, 15),
      activityType: ActivityType.cosplay,
      genreId: genre.id,
      characterId: original.id,
      costumeId: costume.id,
    );
    masters.updateCostume(
      costume.id,
      name: costume.name,
      isGeneral: false,
      characterId: other.id,
    );
    final diary = DiaryStore()..save(entry);
    await openForm(tester, masters, diary, entry: entry);
    expect(selections(tester), [genre.id, original.id, costume.id]);
    await tester.scrollUntilVisible(
      find.text('保存'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(diary.entries.single.costumeId, costume.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one diary can save two character and costume combinations', (
    tester,
  ) async {
    final masters = MasterDataStore();
    final genre = masters.addGenre('作品');
    final first = masters.addCharacter(genre.id, 'キャラA');
    final second = masters.addCharacter(genre.id, 'キャラB');
    final dress = masters.addCostume('制服', isGeneral: true);
    final casual = masters.addCostume('私服', isGeneral: true);
    final diary = DiaryStore()
      ..save(
        DiaryEntry(
          id: 'multi',
          activityDate: DateTime(2026, 10, 15),
          activityType: ActivityType.cosplay,
          genreId: genre.id,
          characterId: first.id,
          costumeId: dress.id,
        ),
      );
    await openForm(tester, masters, diary, entry: diary.entries.single);
    await tester.scrollUntilVisible(
      find.text('キャラ・衣装を追加'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('キャラ・衣装を追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('extra-0-ジャンル-null')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('作品').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('extra-0-キャラクター-null')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャラB').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('extra-0-衣装-null')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('extra-0-衣装-null')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('私服').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('保存'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(diary.entries.single.looks.map((look) => look.characterId), [
      first.id,
      second.id,
    ]);
    expect(diary.entries.single.looks.map((look) => look.costumeId), [
      dress.id,
      casual.id,
    ]);
    await openForm(tester, masters, diary, entry: diary.entries.single);
    expect(find.text('2件目のキャラ・衣装'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('2件目を削除'));
    await tester.tap(find.byTooltip('2件目を削除'));
    await tester.scrollUntilVisible(
      find.text('保存'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(diary.entries.single.looks, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
