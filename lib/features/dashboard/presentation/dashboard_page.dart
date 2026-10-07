import 'package:flutter/material.dart';

import '../../contact_lenses/application/lens_store.dart';
import '../../diary/application/diary_store.dart';
import '../../master_data/application/master_data_store.dart';
import '../domain/statistics_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.diaryStore,
    required this.lensStore,
    required this.masterStore,
    super.key,
  });
  final DiaryStore diaryStore;
  final LensStore lensStore;
  final MasterDataStore masterStore;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _service = StatisticsService();
  int? _year = DateTime.now().year;

  String _characterName(String id) {
    for (final character in widget.masterStore.characters) {
      if (character.id == id) return character.name;
    }
    return '不明なキャラクター';
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      widget.diaryStore,
      widget.lensStore,
      widget.masterStore,
    ]),
    builder: (context, _) {
      final years =
          widget.diaryStore.entries
              .map((e) => e.activityDate.year)
              .toSet()
              .toList()
            ..sort((a, b) => b.compareTo(a));
      if (_year != null && !years.contains(_year)) years.insert(0, _year!);
      final unused = widget.lensStore.ledger.purchases.fold<int>(
        0,
        (sum, purchase) =>
            sum + widget.lensStore.ledger.unusedCount(purchase.id),
      );
      final stats = _service.calculate(
        widget.diaryStore.entries,
        year: _year,
        lensUsageProductIds: widget.lensStore.ledger.usages.map((usage) {
          final inventory = widget.lensStore.ledger.inventories.firstWhere(
            (e) => e.id == usage.inventoryId,
          );
          return widget.lensStore.ledger.purchases
              .firstWhere((e) => e.id == inventory.purchaseId)
              .productId;
        }),
        unusedLensStock: unused,
      );
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          DropdownButtonFormField<int?>(
            initialValue: _year,
            decoration: const InputDecoration(labelText: '対象期間'),
            items: [
              const DropdownMenuItem(value: null, child: Text('全期間')),
              for (final year in years)
                DropdownMenuItem(value: year, child: Text('$year年')),
            ],
            onChanged: (value) => setState(() => _year = value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Metric(label: 'コスプレ回数', value: stats.cosplayCount),
              _Metric(label: 'コスプレ日数', value: stats.cosplayDays),
              _Metric(label: '撮影回数', value: stats.photographerCount),
              _Metric(label: '撮影日数', value: stats.photographerDays),
              _Metric(label: '同日活動', value: stats.overlapDays),
              _Metric(label: 'カラコン使用', value: stats.lensUsageCount),
              _Metric(label: '未使用在庫', value: stats.unusedLensStock),
            ],
          ),
          const SizedBox(height: 16),
          Text('月別コスプレ回数', style: Theme.of(context).textTheme.titleMedium),
          for (var month = 1; month <= 12; month++)
            _MonthBar(
              month: month,
              count: stats.cosplayByMonth[month] ?? 0,
              max: stats.cosplayByMonth.values.fold<int>(
                1,
                (a, b) => a > b ? a : b,
              ),
            ),
          const SizedBox(height: 16),
          Text('キャラクター上位', style: Theme.of(context).textTheme.titleMedium),
          if (stats.topCharacters.isEmpty) const Text('記録がありません'),
          for (final rank in stats.topCharacters)
            ListTile(
              dense: true,
              title: Text(_characterName(rank.id)),
              trailing: Text('${rank.count}回'),
            ),
        ],
      );
    },
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 145,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label),
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    ),
  );
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.count,
    required this.max,
  });
  final int month;
  final int count;
  final int max;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 40, child: Text('$month月')),
      Expanded(
        child: LinearProgressIndicator(
          value: count / max,
          minHeight: 12,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      SizedBox(width: 40, child: Text('$count回', textAlign: TextAlign.end)),
    ],
  );
}
