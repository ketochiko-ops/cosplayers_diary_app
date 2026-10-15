import 'package:flutter/material.dart';

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../photos/application/photo_controller.dart';
import '../../photos/domain/photo_service.dart';

import '../../master_data/application/master_data_store.dart';
import '../../master_data/domain/master_models.dart';
import '../../master_data/domain/master_service.dart';
import '../../master_data/presentation/quick_add_master_dialog.dart';
import '../application/diary_store.dart';
import '../domain/diary_models.dart';
import 'confirm_diary_deletion.dart';

class DiaryForm extends StatefulWidget {
  const DiaryForm({
    required this.store,
    required this.masterStore,
    this.initialDate,
    this.entry,
    this.photos,
    this.onDelete,
    super.key,
  });
  final DiaryStore store;
  final MasterDataStore masterStore;
  final DateTime? initialDate;
  final DiaryEntry? entry;
  final PhotoController? photos;
  final void Function(String id)? onDelete;

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
  PhotoRecord? _photo;
  Future<Uint8List>? _photoBytes;
  bool _picking = false;
  late final String _entryId = widget.entry?.id ?? widget.store.nextId();
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
    _photo = widget.photos?.find(widget.entry?.photoId);
    if (_photo != null) {
      _photoBytes = widget.photos!.files.read(_photo!.relativePath);
    }
  }

  @override
  void dispose() {
    _memo.dispose();
    _calendarTitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final genres = _masters.activeGenres(widget.masterStore.genres).toList();
    if (_genreId != null && !genres.any((value) => value.id == _genreId)) {
      final previous = _byId(widget.masterStore.genres, _genreId);
      if (previous != null) genres.add(previous);
    }
    final genre = _byId(genres, _genreId);
    final characters = genre == null
        ? <CosplayCharacter>[]
        : _masters
              .charactersForGenre(widget.masterStore.characters, genre)
              .toList();
    if (_characterId != null &&
        !characters.any((value) => value.id == _characterId)) {
      final previous = _byId(widget.masterStore.characters, _characterId);
      if (previous != null) characters.add(previous);
    }
    final character = _byId(characters, _characterId);
    final costumes = character == null
        ? <Costume>[]
        : _masters
              .costumesForCharacter(widget.masterStore.costumes, character)
              .toList();
    // A diary keeps its original costume ID even if the master is later
    // archived or assigned to another character. Keep that historical choice
    // visible while editing this entry.
    if (widget.entry?.costumeId == _costumeId &&
        !costumes.any((value) => value.id == _costumeId)) {
      final previous = widget.masterStore.costumes
          .where((value) => value.id == _costumeId)
          .firstOrNull;
      if (previous != null) costumes.add(previous);
    }
    final missingGenre =
        _genreId != null && !genres.any((value) => value.id == _genreId);
    final missingCharacter =
        _characterId != null &&
        !characters.any((value) => value.id == _characterId);
    final missingCostume =
        _costumeId != null && !costumes.any((value) => value.id == _costumeId);
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
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('genre:$_genreId'),
                    initialValue: _genreId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'ジャンル'),
                    items: [
                      if (missingGenre)
                        DropdownMenuItem(
                          value: _genreId,
                          child: const Text('取得できませんでした'),
                        ),
                      for (final value in genres)
                        DropdownMenuItem(
                          value: value.id,
                          child: Text(value.name),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _genreId = value;
                      _characterId = _costumeId = null;
                    }),
                  ),
                ),
                IconButton(
                  tooltip: 'ジャンルを追加',
                  onPressed: _addGenre,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('character:$_genreId:$_characterId'),
                    initialValue: _characterId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'キャラクター',
                      helperText: genre == null ? '先にジャンルを選択・追加してください' : null,
                    ),
                    items: [
                      if (missingCharacter)
                        DropdownMenuItem(
                          value: _characterId,
                          child: const Text('取得できませんでした'),
                        ),
                      for (final value in characters)
                        DropdownMenuItem(
                          value: value.id,
                          child: Text(value.name),
                        ),
                    ],
                    onChanged: genre == null
                        ? null
                        : (value) => setState(() {
                            _characterId = value;
                            _costumeId = null;
                          }),
                  ),
                ),
                IconButton(
                  tooltip: 'キャラクターを追加',
                  onPressed: genre == null || genre.archived
                      ? null
                      : () => _addCharacter(genre),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('costume:$_characterId:$_costumeId'),
                    initialValue: _costumeId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: '衣装',
                      helperText: character == null
                          ? '先にキャラクターを選択・追加してください'
                          : null,
                    ),
                    items: [
                      if (missingCostume)
                        DropdownMenuItem(
                          value: _costumeId,
                          child: const Text('取得できませんでした'),
                        ),
                      for (final value in costumes)
                        DropdownMenuItem(
                          value: value.id,
                          child: Text(value.displayName),
                        ),
                    ],
                    onChanged: character == null
                        ? null
                        : (value) => setState(() => _costumeId = value),
                  ),
                ),
                IconButton(
                  tooltip: '衣装を追加',
                  onPressed: character == null || character.archived
                      ? null
                      : () => _addCostume(character),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _calendarTitle,
            decoration: const InputDecoration(
              labelText: 'イベント・予定名（任意）',
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
          if (widget.photos != null) ...[
            const Text('写真', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_photoBytes != null)
              FutureBuilder<Uint8List>(
                future: _photoBytes,
                builder: (context, snapshot) => snapshot.hasError
                    ? const Text('画像を読み込めません。元のプロジェクトフォルダを開き直してください。')
                    : snapshot.hasData
                    ? Image.memory(
                        snapshot.data!,
                        height: 220,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Text('この画像形式を表示できません'),
                      )
                    : const LinearProgressIndicator(),
              ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _picking ? null : _pickPhoto,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text(_photo == null ? '画像を追加' : '画像を変更'),
                ),
                if (_photo != null)
                  TextButton(
                    onPressed: _picking
                        ? null
                        : () => setState(() {
                            _photo = null;
                            _photoBytes = null;
                          }),
                    child: const Text('画像を取り外す'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          FilledButton.icon(
            onPressed: _picking ? null : _save,
            icon: const Icon(Icons.save),
            label: const Text('保存'),
          ),
          if (widget.entry != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _deleteEntry,
              icon: const Icon(Icons.delete_outline),
              label: const Text('この日記を削除'),
            ),
          ],
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

  Future<void> _addGenre() async {
    final result = await showQuickAddMasterDialog(
      context: context,
      title: 'ジャンルを追加',
    );
    if (result == null || !mounted) return;
    final genre = widget.masterStore.addGenre(result.name);
    setState(() {
      _genreId = genre.id;
      _characterId = _costumeId = null;
    });
  }

  Future<void> _addCharacter(Genre genre) async {
    final result = await showQuickAddMasterDialog(
      context: context,
      title: 'キャラクターを追加',
      parentLabel: 'ジャンル: ${genre.name}',
    );
    if (result == null || !mounted) return;
    final character = widget.masterStore.addCharacter(genre.id, result.name);
    setState(() {
      _characterId = character.id;
      _costumeId = null;
    });
  }

  Future<void> _addCostume(CosplayCharacter character) async {
    final result = await showQuickAddMasterDialog(
      context: context,
      title: '衣装を追加',
      parentLabel: 'キャラクター: ${character.name}',
      allowGeneral: true,
    );
    if (result == null || !mounted) return;
    final costume = widget.masterStore.addCostume(
      result.name,
      isGeneral: result.isGeneral,
      genreIds: [character.genreId],
      characterIds: result.isGeneral ? const [] : [character.id],
    );
    setState(() => _costumeId = costume.id);
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
      id: _entryId,
      activityDate: _date,
      activityType: _type,
      genreId: _genreId,
      characterId: _characterId,
      costumeId: _costumeId,
      memo: _memo.text.trim(),
      calendarTitle: _calendarTitle.text.trim(),
      photoId: widget.photos == null ? current?.photoId : _photo?.id,
      lensInventoryId: current?.lensInventoryId,
      createdAt: current?.createdAt,
    );
    try {
      widget.store.save(entry);
      if (_photo != null) widget.photos!.retain(_photo!);
      Navigator.pop(context);
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
  }

  Future<void> _deleteEntry() async {
    if (!await confirmDiaryDeletion(context) || !mounted) return;
    (widget.onDelete ?? widget.store.delete)(widget.entry!.id);
    Navigator.pop(context);
  }

  Future<void> _pickPhoto() async {
    setState(() => _picking = true);
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (picked == null || !mounted) return;
      final photo = await widget.photos!.add(
        await picked.readAsBytes(),
        picked.name,
        _entryId,
      );
      if (!mounted) return;
      setState(() {
        _photo = photo;
        _photoBytes = widget.photos!.files.read(photo.relativePath);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('画像を保存できませんでした: $error')));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }
}
