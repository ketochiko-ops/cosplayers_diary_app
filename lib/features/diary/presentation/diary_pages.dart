import 'package:flutter/material.dart';

import '../../master_data/application/master_data_store.dart';
import '../../settings/domain/calendar_week_start.dart';
import '../application/diary_store.dart';
import '../domain/diary_models.dart';
import 'diary_form.dart';
import '../../photos/application/photo_controller.dart';

String _characterLabel(DiaryEntry entry, MasterDataStore masters) =>
    masters.characters
        .where((value) => value.id == entry.characterId)
        .firstOrNull
        ?.name ??
    '不明なキャラクター';

String _costumeLabel(DiaryEntry entry, MasterDataStore masters) =>
    masters.costumes
        .where((value) => value.id == entry.costumeId)
        .firstOrNull
        ?.displayName ??
    '不明な衣装';

String _dayPreview(DiaryEntry entry, MasterDataStore masters) {
  final title = entry.calendarTitle.trim();
  if (title.isNotEmpty) return title;
  if (entry.activityType == ActivityType.cosplay) {
    return _characterLabel(entry, masters);
  }
  final firstMemoLine = entry.memo.trim().split('\n').first.trim();
  return firstMemoLine.isNotEmpty ? firstMemoLine : entry.activityType.label;
}

class DiaryListPage extends StatelessWidget {
  const DiaryListPage({
    required this.store,
    required this.masterStore,
    this.photos,
    super.key,
  });
  final DiaryStore store;
  final MasterDataStore masterStore;
  final PhotoController? photos;

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
      ),
    ),
  );
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    required this.store,
    required this.masterStore,
    this.photos,
    this.initialMonth,
    this.weekStart = CalendarWeekStart.monday,
    super.key,
  });
  final DiaryStore store;
  final MasterDataStore masterStore;
  final PhotoController? photos;
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
              mainAxisExtent: 44 * textScale,
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
              final preview = count == 0
                  ? ''
                  : _dayPreview(dayEntries.first, widget.masterStore);
              return Semantics(
                label:
                    '${date.year}年${date.month}月${date.day}日、活動$count件${count == 0 ? '' : '、$preview'}',
                selected: DateUtils.isSameDay(_selected, date),
                child: InkWell(
                  key: ValueKey(date),
                  onTap: () => setState(() => _selected = date),
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: DateUtils.isSameDay(_selected, date)
                          ? Theme.of(context).colorScheme.secondaryContainer
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
                              count > 1 ? '$count件 $preview' : preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10),
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
    super.key,
  });
  final DiaryEntry entry;
  final DiaryStore store;
  final MasterDataStore masterStore;
  final PhotoController? photos;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (entry.calendarTitle.trim().isNotEmpty)
        'イベント: ${entry.calendarTitle.trim()}',
      if (entry.activityType == ActivityType.cosplay)
        'キャラ: ${_characterLabel(entry, masterStore)}  /  衣装: ${_costumeLabel(entry, masterStore)}',
      if (entry.memo.trim().isNotEmpty) 'メモ: ${entry.memo.trim()}',
    ];
    return ListTile(
      leading: CircleAvatar(child: Icon(_icon(entry.activityType))),
      title: Text(
        '${entry.activityDate.year}/${entry.activityDate.month}/${entry.activityDate.day}  ${entry.activityType.label}',
      ),
      isThreeLine: details.length > 1,
      subtitle: details.isEmpty
          ? null
          : Text(
              details.join('\n'),
              maxLines: 4,
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
          ),
        ),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'delete') store.delete(entry.id);
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
