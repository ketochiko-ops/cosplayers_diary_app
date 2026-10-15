import 'package:flutter/material.dart';

import '../../master_data/application/master_data_store.dart';
import '../../settings/domain/calendar_week_start.dart';
import '../application/diary_store.dart';
import '../domain/diary_models.dart';
import 'diary_form.dart';
import '../../photos/application/photo_controller.dart';

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
    animation: store,
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
    animation: widget.store,
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
                Text(
                  '${_month.year}年 ${_month.month}月',
                  style: Theme.of(context).textTheme.titleMedium,
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
              final count = widget.store.service
                  .onDate(widget.store.entries, date)
                  .length;
              return Semantics(
                label: '${date.year}年${date.month}月${date.day}日、活動$count件',
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
                        if (count > 0) Badge(label: Text('$count')),
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

  void _changeMonth(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
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
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(child: Icon(_icon(entry.activityType))),
    title: Text(
      '${entry.activityDate.year}/${entry.activityDate.month}/${entry.activityDate.day}  ${entry.activityType.label}',
    ),
    subtitle: entry.memo.isEmpty
        ? null
        : Text(entry.memo, maxLines: 1, overflow: TextOverflow.ellipsis),
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

  IconData _icon(ActivityType type) => switch (type) {
    ActivityType.cosplay => Icons.auto_awesome,
    ActivityType.photographer => Icons.photo_camera,
    ActivityType.other => Icons.event,
  };
}
