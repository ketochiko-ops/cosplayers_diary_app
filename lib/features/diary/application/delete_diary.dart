import '../../contact_lenses/application/lens_store.dart';
import 'diary_store.dart';

/// Removes lens usage first so a failed ledger update never deletes the diary.
void deleteDiary({
  required DiaryStore diary,
  required LensStore lenses,
  required String id,
}) {
  if (!diary.entries.any((entry) => entry.id == id)) return;
  if (lenses.ledger.usages.any((usage) => usage.diaryId == id)) {
    lenses.cancelDiaryUsage(id);
  }
  diary.delete(id);
}
