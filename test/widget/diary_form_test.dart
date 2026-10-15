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
  await tester.ensureVisible(button);
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
    .toList();

void main() {
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
      expect(selections(tester), [
        masters.genres.last.id,
        masters.characters.last.id,
        null,
      ]);
      final dropdowns = tester.widgetList<DropdownButton<String>>(
        find.byWidgetPredicate((widget) => widget is DropdownButton<String>),
      );
      expect(dropdowns.last.items!.map((item) => item.value), [general.id]);
      expect(tester.takeException(), isNull);
    },
  );
}
