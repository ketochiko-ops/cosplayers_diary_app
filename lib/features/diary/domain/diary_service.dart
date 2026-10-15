import 'diary_models.dart';

class DiaryService {
  const DiaryService();

  List<String> validate(DiaryEntry entry) {
    if (entry.activityType != ActivityType.cosplay) return const [];
    if (entry.looks.isEmpty) return const ['ジャンル', 'キャラクター', '衣装'];
    return [
      for (var i = 0; i < entry.looks.length; i++) ...[
        if (entry.looks[i].genreId == null) i == 0 ? 'ジャンル' : '${i + 1}件目のジャンル',
        if (entry.looks[i].characterId == null)
          i == 0 ? 'キャラクター' : '${i + 1}件目のキャラクター',
        if (entry.looks[i].costumeId == null) i == 0 ? '衣装' : '${i + 1}件目の衣装',
      ],
    ];
  }

  List<DiaryEntry> onDate(Iterable<DiaryEntry> entries, DateTime date) =>
      entries
          .where((entry) => _sameDate(entry.activityDate, date))
          .toList(growable: false)
        ..sort((a, b) => a.activityDate.compareTo(b.activityDate));

  DiaryEntry duplicate(
    DiaryEntry source, {
    required String id,
    required DateTime date,
  }) => source.copyWith(
    id: id,
    activityDate: date,
    clearLens: true,
    updatedAt: date,
  );

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
