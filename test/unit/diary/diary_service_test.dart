import 'package:cosplayers_diary/features/diary/domain/diary_models.dart';
import 'package:cosplayers_diary/features/diary/domain/diary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = DiaryService();

  test('cosplay requires genre character and costume', () {
    final entry = DiaryEntry(
      id: 'd1',
      activityDate: DateTime(2026, 2, 1),
      activityType: ActivityType.cosplay,
    );
    expect(service.validate(entry), containsAll(['ジャンル', 'キャラクター', '衣装']));
  });

  test('photographer permits cosplay fields to be empty', () {
    final entry = DiaryEntry(
      id: 'd1',
      activityDate: DateTime(2026, 2, 1),
      activityType: ActivityType.photographer,
    );
    expect(service.validate(entry), isEmpty);
  });

  test('each look must include a genre character and costume', () {
    final entry = DiaryEntry(
      id: 'multi',
      activityDate: DateTime(2026, 2, 1),
      activityType: ActivityType.cosplay,
      looks: const [
        CosplayLook(genreId: 'g', characterId: 'c', costumeId: 's'),
        CosplayLook(genreId: 'g', characterId: 'c2', costumeId: null),
      ],
    );
    expect(service.validate(entry), ['2件目の衣装']);
  });

  test('entries on the same date are all returned', () {
    final entries = [
      DiaryEntry(
        id: 'd1',
        activityDate: DateTime(2026, 2, 1, 9),
        activityType: ActivityType.cosplay,
        genreId: 'g',
        characterId: 'c',
        costumeId: 's',
      ),
      DiaryEntry(
        id: 'd2',
        activityDate: DateTime(2026, 2, 1, 18),
        activityType: ActivityType.photographer,
      ),
      DiaryEntry(
        id: 'd3',
        activityDate: DateTime(2026, 2, 2),
        activityType: ActivityType.other,
      ),
    ];
    expect(service.onDate(entries, DateTime(2026, 2, 1)).map((e) => e.id), [
      'd1',
      'd2',
    ]);
  });

  test(
    'duplicate clears usage and identity while keeping cosplay selections',
    () {
      final source = DiaryEntry(
        id: 'd1',
        activityDate: DateTime(2026, 2, 1),
        activityType: ActivityType.cosplay,
        looks: const [
          CosplayLook(genreId: 'g', characterId: 'c', costumeId: 's'),
          CosplayLook(genreId: 'g', characterId: 'c2', costumeId: 's2'),
        ],
        lensInventoryId: 'i1',
      );
      final copy = service.duplicate(
        source,
        id: 'd2',
        date: DateTime(2026, 3, 1),
      );
      expect(copy.id, 'd2');
      expect(copy.lensInventoryId, isNull);
      expect(copy.characterId, 'c');
      expect(copy.looks.map((look) => look.characterId), ['c', 'c2']);
    },
  );
}
