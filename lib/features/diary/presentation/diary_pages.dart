import 'package:flutter/material.dart';

import '../../master_data/application/master_data_store.dart';
import '../../settings/domain/calendar_week_start.dart';
import '../application/diary_store.dart';
import '../domain/diary_models.dart';
import 'diary_form.dart';
import 'confirm_diary_deletion.dart';
import '../../photos/application/photo_controller.dart';

String _characterLabel(CosplayLook look, MasterDataStore masters) =>
    masters.characters
        .where((value) => value.id == look.characterId)
        .firstOrNull
        ?.name ??
    '取得できませんでした';

String _costumeLabel(CosplayLook look, MasterDataStore masters) =>
    masters.costumes
        .where((value) => value.id == look.costumeId)
        .firstOrNull
        ?.displayName ??
    '取得できませんでした';

String _genreLabel(CosplayLook look, MasterDataStore masters) =>
    masters.genres
        .where((value) => value.id == look.genreId)
        .firstOrNull
        ?.name ??
    '取得できませんでした';

String _eventLabel(DiaryEntry entry, MasterDataStore masters) =>
    masters.events
        .where((value) => value.id == entry.eventId)
        .firstOrNull
        ?.name ??
    '取得できませんでした';

bool _hasMissingMaster(DiaryEntry entry, MasterDataStore masters) =>
    (entry.eventId != null &&
        !masters.events.any((value) => value.id == entry.eventId)) ||
    (entry.activityType == ActivityType.cosplay &&
        (entry.looks.isEmpty ||
            entry.looks.any(
              (look) =>
                  !masters.genres.any((value) => value.id == look.genreId) ||
                  !masters.characters.any(
                    (value) => value.id == look.characterId,
                  ) ||
                  !masters.costumes.any((value) => value.id == look.costumeId),
            )));

String _characterNames(DiaryEntry entry, MasterDataStore masters) =>
    entry.looks.map((look) => _characterLabel(look, masters)).join('・');

String _dayPreview(DiaryEntry entry, MasterDataStore masters) {
  final title = entry.calendarTitle.trim();
  if (title.isNotEmpty) return title;
  if (entry.eventId != null) return _eventLabel(entry, masters);
  if (entry.activityType == ActivityType.cosplay) {
    return _characterNames(entry, masters);
  }
  final firstMemoLine = entry.memo.trim().split('\n').first.trim();
  return firstMemoLine.isNotEmpty ? firstMemoLine : entry.activityType.label;
}

class DiaryListPage extends StatelessWidget {
  const DiaryListPage({
    required this.store,
    required this.masterStore,
    this.photos,
    this.onDelete,
    super.key,
  });
  final DiaryStore store;
  final MasterDataStore masterStore;
  final PhotoController? photos;
  final void Function(String id)? onDelete;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([store, masterStore]),
    builder: (context, _) => Scaffold(
      body: store.entries.isEmpty
          ? const Center(child: Text('日記はまだありません'))
          : ListView.builder(
              itemCount: store.entries.length,
              itemBuilder: (context, index) => DiaryTile(
                entry: store.entries[index],
                store: store,
                masterStore: masterStore,
                photos: photos,
                onDelete: onDelete,
              ),
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: '日記を追加',
        onPressed: () => _open(context),
        child: const Icon(Icons.add),
      ),
    ),
  );

  void _open(BuildContext context, {DateTime? date}) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DiaryForm(
        store: store,
        masterStore: masterStore,
        initialDate: date,
        photos: photos,
        onDelete: onDelete,
      ),
    ),
  );
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    required this.store,
    required this.masterStore,
    this.photos,
    this.onDelete,
    this.initialMonth,
    this.weekStart = CalendarWeekStart.monday,
    super.key,
  });
  final DiaryStore store;
  final MasterDataStore masterStore;
  final PhotoController? photos;
  final void Function(String id)? onDelete;
  final DateTime? initialMonth;
  final CalendarWeekStart weekStart;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month = widget.initialMonth ?? DateTime.now();
  DateTime? _selected;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.store, widget.masterStore]),
    builder: (context, _) {
      final days = DateUtils.getDaysInMonth(_month.year, _month.month);
      final offset =
          (DateTime(_month.year, _month.month).weekday -
              widget.weekStart.weekday +
              7) %
          7;
      final weekdays = List.generate(
        7,
        (index) => (widget.weekStart.weekday + index - 1) % 7 + 1,
      );
      final textScale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
        1.0,
        double.infinity,
      );
      final selectedEntries = _selected == null
          ? <DiaryEntry>[]
          : widget.store.service.onDate(widget.store.entries, _selected!);
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '前の月',
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    key: const ValueKey('calendar-year'),
                    value: _month.year,
                    items: [
                      for (final year in {
                        for (var year = 1900; year <= 2100; year++) year,
                        _month.year,
                      }.toList()..sort())
                        DropdownMenuItem(value: year, child: Text('$year年')),
                    ],
                    onChanged: (year) {
                      if (year != null) _setMonth(year, _month.month);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    key: const ValueKey('calendar-month'),
                    value: _month.month,
                    items: [
                      for (var month = 1; month <= 12; month++)
                        DropdownMenuItem(value: month, child: Text('$month月')),
                    ],
                    onChanged: (month) {
                      if (month != null) _setMonth(_month.year, month);
                    },
                  ),
                ),
                IconButton(
                  tooltip: '次の月',
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 24 * textScale,
              child: Row(
                children: [
                  for (final weekday in weekdays)
                    Expanded(
                      child: Center(
                        child: Text(
                          const ['月', '火', '水', '木', '金', '土', '日'][weekday -
                              1],
                          style: TextStyle(color: _weekdayColor(weekday)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 52 * textScale,
            ),
            itemCount: offset + days,
            itemBuilder: (context, index) {
              if (index < offset) return const SizedBox.shrink();
              final date = DateTime(
                _month.year,
                _month.month,
                index - offset + 1,
              );
              final dayEntries = widget.store.service.onDate(
                widget.store.entries,
                date,
              );
              final count = dayEntries.length;
              final hasMissingMaster = dayEntries.any(
                (entry) => _hasMissingMaster(entry, widget.masterStore),
              );
              final preview = count == 0
                  ? ''
                  : _dayPreview(dayEntries.first, widget.masterStore);
              final characterNames = dayEntries
                  .where((entry) => entry.activityType == ActivityType.cosplay)
                  .expand((entry) => entry.looks)
                  .map((look) => _characterLabel(look, widget.masterStore))
                  .toSet()
                  .join('・');
              return Semantics(
                label:
                    '${date.year}年${date.month}月${date.day}日、活動$count件${hasMissingMaster ? '、参照データを取得できませんでした' : ''}${count == 0 ? '' : '、$preview'}${characterNames.isEmpty || characterNames == preview ? '' : '、キャラ: $characterNames'}',
                selected: DateUtils.isSameDay(_selected, date),
                child: InkWell(
                  key: ValueKey(date),
                  onTap: () => setState(() => _selected = date),
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: hasMissingMaster
                          ? Theme.of(context).colorScheme.errorContainer
                          : DateUtils.isSameDay(_selected, date)
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : null,
                      border: hasMissingMaster
                          ? Border.all(
                              color: Theme.of(context).colorScheme.error,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(color: _weekdayColor(date.weekday)),
                        ),
                        if (count > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              '${hasMissingMaster ? '⚠ ' : ''}${count > 1 ? '$count件 ' : ''}$preview',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        if (characterNames.isNotEmpty &&
                            characterNames != preview)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              characterNames,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: Divider(height: 8)),
          if (_selected != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DiaryForm(
                        store: widget.store,
                        masterStore: widget.masterStore,
                        photos: widget.photos,
                        onDelete: widget.onDelete,
                        initialDate: _selected,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('この日に日記を追加'),
                ),
              ),
            ),
          if (_selected == null || selectedEntries.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    _selected == null ? '日付を選択してください' : 'この日の活動はありません',
                  ),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: selectedEntries.length,
              itemBuilder: (context, index) => DiaryTile(
                entry: selectedEntries[index],
                store: widget.store,
                masterStore: widget.masterStore,
                photos: widget.photos,
                onDelete: widget.onDelete,
              ),
            ),
        ],
      );
    },
  );

  void _changeMonth(int delta) => _setMonth(_month.year, _month.month + delta);

  void _setMonth(int year, int month) => setState(() {
    _month = DateTime(year, month);
    _selected = null;
  });

  Color? _weekdayColor(int weekday) => switch (weekday) {
    DateTime.saturday => Colors.blue.shade700,
    DateTime.sunday => Colors.red.shade700,
    _ => null,
  };
}

class DiaryTile extends StatelessWidget {
  const DiaryTile({
    required this.entry,
    required this.store,
    required this.masterStore,
    this.photos,
    this.onDelete,
    super.key,
  });
  final DiaryEntry entry;
  final DiaryStore store;
  final MasterDataStore masterStore;
  final PhotoController? photos;
  final void Function(String id)? onDelete;

  @override
  Widget build(BuildContext context) {
    final missingMaster = _hasMissingMaster(entry, masterStore);
    final details = <String>[
      if (missingMaster) '⚠ 参照先を取得できませんでした',
      if (entry.eventId != null) '参加イベント: ${_eventLabel(entry, masterStore)}',
      if (entry.calendarTitle.trim().isNotEmpty)
        '${entry.eventId == null ? 'イベント' : '予定名'}: ${entry.calendarTitle.trim()}',
      if (entry.activityType == ActivityType.cosplay)
        for (final look in entry.looks)
          'ジャンル: ${_genreLabel(look, masterStore)}  /  キャラ: ${_characterLabel(look, masterStore)}  /  衣装: ${_costumeLabel(look, masterStore)}',
      if (entry.memo.trim().isNotEmpty) 'メモ: ${entry.memo.trim()}',
    ];
    return ListTile(
      leading: CircleAvatar(
        child: Icon(
          missingMaster
              ? Icons.warning_amber_rounded
              : _icon(entry.activityType),
        ),
      ),
      title: Text(
        '${entry.activityDate.year}/${entry.activityDate.month}/${entry.activityDate.day}  ${entry.activityType.label}',
      ),
      isThreeLine: details.length > 1,
      subtitle: details.isEmpty
          ? null
          : Text(
              details.join('\n'),
              maxLines: 12,
              overflow: TextOverflow.ellipsis,
            ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DiaryForm(
            store: store,
            masterStore: masterStore,
            entry: entry,
            photos: photos,
            onDelete: onDelete,
          ),
        ),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'delete' && await confirmDiaryDeletion(context)) {
            (onDelete ?? store.delete)(entry.id);
          }
          if (value == 'duplicate') store.duplicate(entry, DateTime.now());
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'duplicate', child: Text('複製（今日）')),
          PopupMenuItem(value: 'delete', child: Text('削除')),
        ],
      ),
    );
  }

  IconData _icon(ActivityType type) => switch (type) {
    ActivityType.cosplay => Icons.auto_awesome,
    ActivityType.photographer => Icons.photo_camera,
    ActivityType.other => Icons.event,
  };
}
