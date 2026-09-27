import 'package:cosplayers_diary/core/database/app_database.dart';
import 'package:cosplayers_diary/core/database/app_state_persistence.dart';
import 'package:cosplayers_diary/features/backup/application/backup_coordinator.dart';
import 'package:cosplayers_diary/features/contact_lenses/application/lens_store.dart';
import 'package:cosplayers_diary/features/contact_lenses/domain/lens_models.dart';
import 'package:cosplayers_diary/features/dashboard/domain/statistics_service.dart';
import 'package:cosplayers_diary/features/diary/application/diary_store.dart';
import 'package:cosplayers_diary/features/diary/domain/diary_models.dart';
import 'package:cosplayers_diary/features/master_data/application/master_data_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'A: master chain and cosplay diary can be saved and displayed again',
    () {
      final masters = MasterDataStore();
      final diaries = DiaryStore();
      final genre = masters.addGenre('作品');
      final character = masters.addCharacter(genre.id, 'キャラ');
      final costume = masters.addCostume(
        '衣装',
        isGeneral: false,
        characterId: character.id,
      );
      diaries.save(
        DiaryEntry(
          id: diaries.nextId(),
          activityDate: DateTime(2026, 1, 1),
          activityType: ActivityType.cosplay,
          genreId: genre.id,
          characterId: character.id,
          costumeId: costume.id,
        ),
      );
      expect(diaries.entries.single.characterId, character.id);
    },
  );

  test('B/C: lens use changes stock and editing usage off restores it', () {
    final lenses = LensStore();
    final product = lenses.addProduct(
      name: 'Blue',
      manufacturer: 'M',
      color: '青',
      type: WearType.oneDay,
      periodDays: 1,
    );
    final purchase = lenses.addPurchase(
      productId: product.id,
      purchasedOn: DateTime(2026, 1, 1),
      quantity: 1,
    );
    lenses.ledger.useOneDay(
      purchaseId: purchase.id,
      diaryId: 'd1',
      usedOn: DateTime(2026, 1, 2),
    );
    expect(lenses.ledger.unusedCount(purchase.id), 0);
    lenses.cancelDiaryUsage('d1');
    expect(lenses.ledger.unusedCount(purchase.id), 1);
  });

  test('D: ZIP backup restores masters diary and lens inventory into empty database', () async {
    final firstDb = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    final masters = MasterDataStore()..addGenre('作品');
    final diaries = DiaryStore()
      ..save(
        DiaryEntry(
          id: 'd1',
          activityDate: DateTime(2026, 1, 1),
          activityType: ActivityType.other,
        ),
      );
    final lenses = LensStore();
    final product = lenses.addProduct(
      name: 'Blue',
      manufacturer: 'M',
      color: '青',
      type: WearType.monthly,
      periodDays: 30,
    );
    lenses.addPurchase(
      productId: product.id,
      purchasedOn: DateTime(2026, 1, 1),
      quantity: 2,
    );
    final first = AppStatePersistence(
      store: firstDb,
      masters: masters,
      diary: diaries,
      lenses: lenses,
    );
    final zip = BackupCoordinator(first).create(DateTime.utc(2026, 1, 2));
    await firstDb.close();

    final secondDb = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    final restoredMasters = MasterDataStore();
    final restoredDiaries = DiaryStore();
    final restoredLenses = LensStore();
    final second = AppStatePersistence(
      store: secondDb,
      masters: restoredMasters,
      diary: restoredDiaries,
      lenses: restoredLenses,
    );
    final result = await BackupCoordinator(second).restore(zip);
    expect(result.isValid, isTrue);
    expect(
      (
        restoredMasters.genres.length,
        restoredDiaries.entries.length,
        restoredLenses.ledger.purchases.length,
      ),
      (1, 1, 1),
    );
    await secondDb.close();
  });

  test('E: cosplay and photographer on same date aggregate independently', () {
    final entries = [
      DiaryEntry(
        id: 'c',
        activityDate: DateTime(2026, 1, 1),
        activityType: ActivityType.cosplay,
        genreId: 'g',
        characterId: 'c',
        costumeId: 's',
      ),
      DiaryEntry(
        id: 'p',
        activityDate: DateTime(2026, 1, 1),
        activityType: ActivityType.photographer,
      ),
    ];
    final stats = const StatisticsService().calculate(entries, year: 2026);
    expect(
      (stats.cosplayCount, stats.photographerCount, stats.overlapDays),
      (1, 1, 1),
    );
  });
}
