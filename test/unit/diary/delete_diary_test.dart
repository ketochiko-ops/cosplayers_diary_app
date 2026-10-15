import 'package:cosplayers_diary/features/contact_lenses/application/lens_store.dart';
import 'package:cosplayers_diary/features/contact_lenses/domain/lens_models.dart';
import 'package:cosplayers_diary/features/diary/application/delete_diary.dart';
import 'package:cosplayers_diary/features/diary/application/diary_store.dart';
import 'package:cosplayers_diary/features/diary/domain/diary_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deleting a diary releases its one-day lens usage', () {
    final diary = DiaryStore()
      ..save(
        DiaryEntry(
          id: 'mistake',
          activityDate: DateTime(2026, 10, 15),
          activityType: ActivityType.other,
        ),
      );
    final lenses = LensStore();
    final product = lenses.addProduct(
      name: 'レンズ',
      manufacturer: 'メーカー',
      color: '青',
      type: WearType.oneDay,
    );
    final purchase = lenses.addPurchase(
      productId: product.id,
      purchasedOn: DateTime(2026, 10, 1),
      quantity: 1,
    );
    lenses.ledger.useOneDay(
      purchaseId: purchase.id,
      diaryId: 'mistake',
      usedOn: DateTime(2026, 10, 15),
    );
    expect(lenses.ledger.unusedCount(purchase.id), 0);
    deleteDiary(diary: diary, lenses: lenses, id: 'mistake');
    expect(diary.entries, isEmpty);
    expect(lenses.ledger.usages, isEmpty);
    expect(lenses.ledger.unusedCount(purchase.id), 1);
  });
}
