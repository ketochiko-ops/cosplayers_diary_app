import 'package:cosplayers_diary/features/contact_lenses/application/lens_store.dart';
import 'package:cosplayers_diary/features/dashboard/presentation/dashboard_page.dart';
import 'package:cosplayers_diary/features/diary/application/diary_store.dart';
import 'package:cosplayers_diary/features/diary/domain/diary_models.dart';
import 'package:cosplayers_diary/features/master_data/application/master_data_store.dart';
import 'package:cosplayers_diary/features/master_data/domain/master_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'character ranking displays the character name instead of its ID',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final masterStore = MasterDataStore();
      final diaryStore = DiaryStore();
      final lensStore = LensStore();
      addTearDown(masterStore.dispose);
      addTearDown(diaryStore.dispose);
      addTearDown(lensStore.dispose);

      masterStore.characters.add(
        const CosplayCharacter(
          id: 'character-miku',
          genreId: 'genre-vocaloid',
          name: '初音ミク',
        ),
      );
      diaryStore.entries.add(
        DiaryEntry(
          id: 'diary-1',
          activityDate: DateTime(DateTime.now().year, 9, 1),
          activityType: ActivityType.cosplay,
          genreId: 'genre-vocaloid',
          characterId: 'character-miku',
          costumeId: 'costume-default',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardPage(
              diaryStore: diaryStore,
              lensStore: lensStore,
              masterStore: masterStore,
            ),
          ),
        ),
      );

      expect(find.text('初音ミク'), findsOneWidget);
      expect(find.text('character-miku'), findsNothing);
    },
  );
}
