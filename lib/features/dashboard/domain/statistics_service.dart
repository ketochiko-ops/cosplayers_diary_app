import '../../diary/domain/diary_models.dart';

class RankingEntry {
  const RankingEntry(this.id, this.count);
  final String id;
  final int count;
}

class ActivityStatistics {
  const ActivityStatistics({
    required this.cosplayCount,
    required this.cosplayDays,
    required this.photographerCount,
    required this.photographerDays,
    required this.overlapDays,
    required this.cosplayByMonth,
    required this.photographerByMonth,
    required this.topCharacters,
    required this.topGenres,
    required this.topCostumes,
    required this.eventParticipationCounts,
    required this.topEvents,
    required this.lensUsageCount,
    required this.lensUsageByProduct,
    required this.unusedLensStock,
    required this.expiringLensCount,
  });
  final int cosplayCount;
  final int cosplayDays;
  final int photographerCount;
  final int photographerDays;
  final int overlapDays;
  final Map<int, int> cosplayByMonth;
  final Map<int, int> photographerByMonth;
  final List<RankingEntry> topCharacters;
  final List<RankingEntry> topGenres;
  final List<RankingEntry> topCostumes;
  final Map<String, int> eventParticipationCounts;
  final List<RankingEntry> topEvents;
  final int lensUsageCount;
  final Map<String, int> lensUsageByProduct;
  final int unusedLensStock;
  final int expiringLensCount;
}

class StatisticsService {
  const StatisticsService();

  ActivityStatistics calculate(
    Iterable<DiaryEntry> source, {
    int? year,
    Iterable<String> lensUsageProductIds = const [],
    int unusedLensStock = 0,
    int expiringLensCount = 0,
  }) {
    final entries = source
        .where((entry) => year == null || entry.activityDate.year == year)
        .toList();
    final cosplay = entries
        .where((entry) => entry.activityType == ActivityType.cosplay)
        .toList();
    final photographers = entries
        .where((entry) => entry.activityType == ActivityType.photographer)
        .toList();
    final cosplayDates = cosplay
        .map((entry) => _dateKey(entry.activityDate))
        .toSet();
    final photographerDates = photographers
        .map((entry) => _dateKey(entry.activityDate))
        .toSet();
    final eventDays = <String, Set<String>>{};
    for (final entry in entries) {
      final eventId = entry.eventId;
      if (eventId != null && eventId.isNotEmpty) {
        eventDays
            .putIfAbsent(eventId, () => <String>{})
            .add(_dateKey(entry.activityDate));
      }
    }
    final eventCounts = {
      for (final entry in eventDays.entries) entry.key: entry.value.length,
    };
    return ActivityStatistics(
      cosplayCount: cosplay.length,
      cosplayDays: cosplayDates.length,
      photographerCount: photographers.length,
      photographerDays: photographerDates.length,
      overlapDays: cosplayDates.intersection(photographerDates).length,
      cosplayByMonth: _months(cosplay),
      photographerByMonth: _months(photographers),
      topCharacters: _ranking(cosplay.map((entry) => entry.characterId)),
      topGenres: _ranking(cosplay.map((entry) => entry.genreId)),
      topCostumes: _ranking(cosplay.map((entry) => entry.costumeId)),
      eventParticipationCounts: eventCounts,
      topEvents: _rankCounts(eventCounts),
      lensUsageCount: lensUsageProductIds.length,
      lensUsageByProduct: _counts(lensUsageProductIds),
      unusedLensStock: unusedLensStock,
      expiringLensCount: expiringLensCount,
    );
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Map<int, int> _months(Iterable<DiaryEntry> entries) => {
    for (var month = 1; month <= 12; month++)
      month: entries.where((entry) => entry.activityDate.month == month).length,
  };

  Map<String, int> _counts(Iterable<String?> values) {
    final result = <String, int>{};
    for (final value in values) {
      if (value != null && value.isNotEmpty) {
        result[value] = (result[value] ?? 0) + 1;
      }
    }
    return result;
  }

  List<RankingEntry> _ranking(Iterable<String?> values) {
    return _rankCounts(_counts(values));
  }

  List<RankingEntry> _rankCounts(Map<String, int> counts) {
    final result = [
      for (final entry in counts.entries) RankingEntry(entry.key, entry.value),
    ];
    result.sort((a, b) {
      final count = b.count.compareTo(a.count);
      return count != 0 ? count : a.id.compareTo(b.id);
    });
    return result.take(5).toList(growable: false);
  }
}
