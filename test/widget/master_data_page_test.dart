import 'package:cosplayers_diary/features/master_data/application/master_data_store.dart';
import 'package:cosplayers_diary/features/master_data/domain/master_service.dart';
import 'package:cosplayers_diary/features/master_data/presentation/master_data_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('edits names and costume scope while keeping stable IDs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MasterDataStore();
    final genre = store.addGenre('ウマ娘');
    final character = store.addCharacter(genre.id, 'スペシャルウィーク');
    final other = store.addCharacter(genre.id, 'トウカイテイオー');
    final unselected = store.addCharacter(genre.id, 'メジロマックイーン');
    final uniform = store.addCostume('制服', isGeneral: true);
    final race = store.addCostume('勝負服', isGeneral: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MasterDataPage(store: store)),
      ),
    );
    await tester.tap(find.byTooltip('ウマ娘を編集'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'ウマ娘 プリティーダービー');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.genres.single.id, genre.id);
    expect(store.genres.single.name, 'ウマ娘 プリティーダービー');

    await tester.tap(find.text('キャラクター').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('スペシャルウィークを編集'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'スペシャルウィーク改');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.characters.first.id, character.id);
    expect(store.characters.first.name, 'スペシャルウィーク改');

    await tester.tap(find.text('衣装').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('勝負服を編集'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '勝負服');
    await tester.tap(find.text('ジャンル').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ウマ娘 プリティーダービー').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('汎用衣装').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('固有衣装').last);
    await tester.pumpAndSettle();
    expect(find.text('対象キャラクターを選択してください'), findsNothing);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('対象キャラクターを選択してください'), findsOneWidget);
    await tester.ensureVisible(find.text('スペシャルウィーク改').last);
    await tester.tap(find.text('スペシャルウィーク改').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('トウカイテイオー').last);
    await tester.tap(find.text('トウカイテイオー').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(store.costumes.last.id, race.id);
    expect(store.costumes.last.isGeneral, isFalse);
    expect(store.costumes.last.genreId, genre.id);
    expect(store.costumes.last.characterIds, [character.id, other.id]);
    expect(store.costumes.first.id, uniform.id);
    expect(store.costumes.first.isGeneral, isTrue);
    const service = MasterDataService();
    expect(
      service
          .costumesForCharacter(store.costumes, store.characters.first)
          .map((value) => value.id),
      [uniform.id, race.id],
    );
    expect(
      service
          .costumesForCharacter(store.costumes, other)
          .map((value) => value.id),
      [uniform.id, race.id],
    );
    expect(
      service
          .costumesForCharacter(store.costumes, unselected)
          .map((value) => value.id),
      [uniform.id],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('adds a character to the selected genre and a specific costume', (
    tester,
  ) async {
    final store = MasterDataStore();
    final first = store.addGenre('作品A');
    final second = store.addGenre('作品B');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MasterDataPage(store: store)),
      ),
    );
    await tester.tap(find.text('キャラクター').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'キャラ');
    await tester.tap(find.text('ジャンル').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('作品B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('追加').last);
    await tester.pumpAndSettle();
    expect(store.characters.single.genreId, second.id);
    expect(store.characters.single.genreId, isNot(first.id));

    await tester.tap(find.text('衣装').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '勝負服');
    await tester.tap(find.text('ジャンル').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('作品B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('汎用衣装').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('固有衣装').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('キャラ').last);
    await tester.tap(find.text('キャラ').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('追加').last);
    await tester.pumpAndSettle();
    expect(store.costumes.single.characterId, store.characters.single.id);
    expect(store.costumes.single.genreId, second.id);
    expect(store.costumes.single.isGeneral, isFalse);
    expect(tester.takeException(), isNull);
  });
}
