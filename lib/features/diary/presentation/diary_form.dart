import 'package:flutter/material.dart';

import '../../master_data/application/master_data_store.dart';
import '../../master_data/domain/master_models.dart';
import '../../master_data/domain/master_service.dart';
import '../application/diary_store.dart';
import '../domain/diary_models.dart';

class DiaryForm extends StatefulWidget {
  const DiaryForm({
    required this.store,
    required this.masterStore,
    this.initialDate,
    this.entry,
    super.key,
  });
  final DiaryStore store;
  final MasterDataStore masterStore;
  final DateTime? initialDate;
  final DiaryEntry? entry;

  @override
  State<DiaryForm> createState() => _DiaryFormState();
}

class _DiaryFormState extends State<DiaryForm> {
  static const _masters = MasterDataService();
  late DateTime _date =
      widget.entry?.activityDate ?? widget.initialDate ?? DateTime.now();
  late ActivityType _type = widget.entry?.activityType ?? ActivityType.cosplay;
  String? _genreId;
  String? _characterId;
  String? _costumeId;
  late final TextEditingController _memo = TextEditingController(
    text: widget.entry?.memo ?? '',
  );

  late final TextEditingController _calendarTitle = TextEditingController(
    text: widget.entry?.calendarTitle ?? '',
  );

  @override
  void initState() {
    super.initState();
    _genreId = widget.entry?.genreId;
    _characterId = widget.entry?.characterId;
    _costumeId = widget.entry?.costumeId;
  }

  @override
  void dispose() {
    _memo.dispose();
    _calendarTitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final genres = _masters.activeGenres(widget.masterStore.genres);
    final genre = _byId(genres, _genreId);
    final characters = genre == null
        ? <CosplayCharacter>[]
        : _masters.charactersForGenre(widget.masterStore.characters, genre);
    final character = _byId(characters, _characterId);
    final costumes = character == null
        ? <Costume>[]
        : _masters.costumesForCharacter(widget.masterStore.costumes, character);
    return Scaffold(
      appBar: AppBar(title: Text(widget.entry == null ? '日記を追加' : '日記を編集')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('活動日'),
            subtitle: Text('${_date.year}/${_date.month}/${_date.day}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          DropdownButtonFormField<ActivityType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: '活動種別'),
            items: [
              for (final type in ActivityType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: (value) => setState(() {
              _type = value!;
              if (_type != ActivityType.cosplay) {
                _genreId = _characterId = _costumeId = null;
              }
            }),
          ),
          if (_type == ActivityType.cosplay) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: genre == null ? null : _genreId,
              decoration: const InputDecoration(labelText: 'ジャンル'),
              items: [
                for (final value in genres)
                  DropdownMenuItem(value: value.id, child: Text(value.name)),
              ],
              onChanged: (value) => setState(() {
                _genreId = value;
                _characterId = _costumeId = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: character == null ? null : _characterId,
              decoration: const InputDecoration(labelText: 'キャラクター'),
              items: [
                for (final value in characters)
                  DropdownMenuItem(value: value.id, child: Text(value.name)),
              ],
              onChanged: (value) => setState(() {
                _characterId = value;
                _costumeId = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: costumes.any((e) => e.id == _costumeId)
                  ? _costumeId
                  : null,
              decoration: const InputDecoration(labelText: '衣装'),
              items: [
                for (final value in costumes)
                  DropdownMenuItem(value: value.id, child: Text(value.name)),
              ],
              onChanged: (value) => setState(() => _costumeId = value),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _calendarTitle,
            decoration: const InputDecoration(
              labelText: '予定名（任意）',
              helperText: '未入力なら活動種別・作品・キャラクターから自動作成します',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memo,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'メモ'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('保存'),
          ),
        ],
      ),
    );
  }

  T? _byId<T>(Iterable<T> values, String? id) {
    for (final value in values) {
      final valueId = switch (value) {
        Genre e => e.id,
        CosplayCharacter e => e.id,
        Costume e => e.id,
        _ => null,
      };
      if (valueId == id) return value;
    }
    return null;
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) setState(() => _date = value);
  }

  void _save() {
    final current = widget.entry;
    final entry = DiaryEntry(
      id: current?.id ?? widget.store.nextId(),
      activityDate: _date,
      activityType: _type,
      genreId: _genreId,
      characterId: _characterId,
      costumeId: _costumeId,
      memo: _memo.text.trim(),
      calendarTitle: _calendarTitle.text.trim(),
      photoId: current?.photoId,
      lensInventoryId: current?.lensInventoryId,
      createdAt: current?.createdAt,
    );
    try {
      widget.store.save(entry);
      Navigator.pop(context);
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
  }
}
