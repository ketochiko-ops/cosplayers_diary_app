import 'package:flutter/material.dart';

import '../application/master_data_store.dart';
import '../domain/master_models.dart';
import '../../diary/application/diary_store.dart';
import '../../dashboard/domain/statistics_service.dart';

enum _MasterKind { genre, character, costume, event }

extension on _MasterKind {
  String get label => switch (this) {
    _MasterKind.genre => 'ジャンル',
    _MasterKind.character => 'キャラクター',
    _MasterKind.costume => '衣装',
    _MasterKind.event => '参加イベント',
  };
}

typedef _MasterInput = ({
  String name,
  String? parentId,
  bool isGeneral,
  List<String> genreIds,
  List<String> characterIds,
  List<String> tags,
});

class MasterDataPage extends StatefulWidget {
  const MasterDataPage({required this.store, this.diaryStore, super.key});
  final MasterDataStore store;
  final DiaryStore? diaryStore;

  @override
  State<MasterDataPage> createState() => _MasterDataPageState();
}

class _MasterDataPageState extends State<MasterDataPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      widget.store,
      _tabs,
      if (widget.diaryStore != null) widget.diaryStore!,
    ]),
    builder: (context, _) {
      final genres = widget.store.genres.where((e) => !e.archived).toList();
      final characters = widget.store.characters
          .where((e) => !e.archived)
          .toList();
      final costumes = widget.store.costumes.where((e) => !e.archived).toList();
      final events = widget.store.events.where((e) => !e.archived).toList();
      final eventCounts = const StatisticsService()
          .calculate(widget.diaryStore?.entries ?? const [])
          .eventParticipationCounts;
      final archived = <_ArchivedMasterRow>[
        for (final genre in widget.store.genres.where((e) => e.archived))
          _ArchivedMasterRow(
            kind: _MasterKind.genre,
            name: genre.name,
            onDelete: () =>
                _deleteArchived(_MasterKind.genre, genre.id, genre.name),
          ),
        for (final character in widget.store.characters.where(
          (e) => e.archived,
        ))
          _ArchivedMasterRow(
            kind: _MasterKind.character,
            name: character.name,
            onDelete: () => _deleteArchived(
              _MasterKind.character,
              character.id,
              character.name,
            ),
          ),
        for (final costume in widget.store.costumes.where((e) => e.archived))
          _ArchivedMasterRow(
            kind: _MasterKind.costume,
            name: costume.displayName,
            onDelete: () => _deleteArchived(
              _MasterKind.costume,
              costume.id,
              costume.displayName,
            ),
          ),
        for (final event in widget.store.events.where((e) => e.archived))
          _ArchivedMasterRow(
            kind: _MasterKind.event,
            name: event.name,
            onDelete: () =>
                _deleteArchived(_MasterKind.event, event.id, event.name),
          ),
      ];
      return Column(
        children: [
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'ジャンル'),
              Tab(text: 'キャラクター'),
              Tab(text: '衣装'),
              Tab(text: '参加イベント'),
              Tab(text: 'アーカイブ'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _MasterList(
                  empty: 'ジャンルを登録してください',
                  entries: [
                    for (final genre in genres)
                      _MasterRow(
                        name: genre.name,
                        onEdit: () => _edit(_MasterKind.genre, genre: genre),
                        onArchive: () => widget.store.archiveGenre(genre.id),
                      ),
                  ],
                ),
                _MasterList(
                  empty: 'キャラクターを登録してください',
                  entries: [
                    for (final character in characters)
                      _MasterRow(
                        name: character.name,
                        detail:
                            widget.store.genres
                                .where((e) => e.id == character.genreId)
                                .firstOrNull
                                ?.name ??
                            '取得できませんでした',
                        onEdit: () =>
                            _edit(_MasterKind.character, character: character),
                        onArchive: () =>
                            widget.store.archiveCharacter(character.id),
                      ),
                  ],
                ),
                _MasterList(
                  empty: '衣装を登録してください',
                  entries: [
                    for (final costume in costumes)
                      _MasterRow(
                        name: costume.displayName,
                        detail:
                            '${costume.genreIds.isEmpty ? '全ジャンル' : costume.genreIds.map((id) => widget.store.genres.where((e) => e.id == id).firstOrNull?.name ?? '取得できませんでした').join('、')} · ${costume.isGeneral ? '汎用衣装' : '固有衣装 · ${costume.characterIds.map((id) => widget.store.characters.where((e) => e.id == id).firstOrNull?.name ?? '取得できませんでした').join('、')}'}',
                        onEdit: () =>
                            _edit(_MasterKind.costume, costume: costume),
                        onArchive: () =>
                            widget.store.archiveCostume(costume.id),
                      ),
                  ],
                ),
                _MasterList(
                  empty: '参加イベントを登録してください',
                  entries: [
                    for (final event in events)
                      _MasterRow(
                        name: event.name,
                        detail: '参加 ${eventCounts[event.id] ?? 0}回',
                        onEdit: () => _edit(_MasterKind.event, event: event),
                        onArchive: () => widget.store.archiveEvent(event.id),
                      ),
                  ],
                ),
                _ArchivedMasterList(entries: archived),
              ],
            ),
          ),
          if (_tabs.index != 4)
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('追加'),
              ),
            ),
        ],
      );
    },
  );

  Future<void> _deleteArchived(_MasterKind kind, String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$nameを完全に削除しますか？'),
        content: const Text(
          'この操作は元に戻せません。日記や他のマスターから参照されている場合は「取得できませんでした」と表示されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('完全に削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      switch (kind) {
        case _MasterKind.genre:
          widget.store.deleteArchivedGenre(id);
        case _MasterKind.character:
          widget.store.deleteArchivedCharacter(id);
        case _MasterKind.costume:
          widget.store.deleteArchivedCostume(id);
        case _MasterKind.event:
          widget.store.deleteArchivedEvent(id);
      }
    } on ArgumentError catch (error) {
      _showError(error);
    }
  }

  Future<void> _add() async {
    final kind = _MasterKind.values[_tabs.index];
    final input = await showDialog<_MasterInput>(
      context: context,
      builder: (_) => _MasterEditorDialog(kind: kind, store: widget.store),
    );
    if (input == null || !mounted) return;
    try {
      switch (kind) {
        case _MasterKind.genre:
          widget.store.addGenre(input.name);
        case _MasterKind.character:
          widget.store.addCharacter(input.parentId!, input.name);
        case _MasterKind.costume:
          widget.store.addCostume(
            input.name,
            isGeneral: input.isGeneral,
            genreIds: input.genreIds,
            characterIds: input.characterIds,
            tags: input.tags,
          );
        case _MasterKind.event:
          widget.store.addEvent(input.name);
      }
    } on ArgumentError catch (error) {
      _showError(error);
    }
  }

  Future<void> _edit(
    _MasterKind kind, {
    Genre? genre,
    CosplayCharacter? character,
    Costume? costume,
    ParticipationEvent? event,
  }) async {
    final input = await showDialog<_MasterInput>(
      context: context,
      builder: (_) => _MasterEditorDialog(
        kind: kind,
        store: widget.store,
        genre: genre,
        character: character,
        costume: costume,
        event: event,
      ),
    );
    if (input == null || !mounted) return;
    try {
      switch (kind) {
        case _MasterKind.genre:
          widget.store.updateGenre(genre!.id, input.name);
        case _MasterKind.character:
          widget.store.updateCharacter(character!.id, input.name);
        case _MasterKind.costume:
          widget.store.updateCostume(
            costume!.id,
            name: input.name,
            isGeneral: input.isGeneral,
            genreIds: input.genreIds,
            characterIds: input.characterIds,
            tags: input.tags,
          );
        case _MasterKind.event:
          widget.store.updateEvent(event!.id, input.name);
      }
    } on ArgumentError catch (error) {
      _showError(error);
    }
  }

  void _showError(ArgumentError error) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message.toString())));
}

class _MasterRow {
  const _MasterRow({
    required this.name,
    required this.onEdit,
    required this.onArchive,
    this.detail,
  });
  final String name;
  final String? detail;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
}

class _ArchivedMasterRow {
  const _ArchivedMasterRow({
    required this.kind,
    required this.name,
    required this.onDelete,
  });
  final _MasterKind kind;
  final String name;
  final VoidCallback onDelete;
}

class _ArchivedMasterList extends StatelessWidget {
  const _ArchivedMasterList({required this.entries});
  final List<_ArchivedMasterRow> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const Center(child: Text('アーカイブ済みのデータはありません'));
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListTile(
          title: Text(entry.name),
          subtitle: Text(entry.kind.label),
          trailing: IconButton(
            tooltip: '${entry.name}を完全に削除',
            icon: const Icon(Icons.delete_forever_outlined),
            onPressed: entry.onDelete,
          ),
        );
      },
    );
  }
}

class _MasterList extends StatelessWidget {
  const _MasterList({required this.empty, required this.entries});
  final String empty;
  final List<_MasterRow> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return Center(child: Text(empty));
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListTile(
          title: Text(entry.name),
          subtitle: entry.detail == null ? null : Text(entry.detail!),
          onTap: entry.onEdit,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: '${entry.name}を編集',
                icon: const Icon(Icons.edit_outlined),
                onPressed: entry.onEdit,
              ),
              IconButton(
                tooltip: '${entry.name}をアーカイブ',
                icon: const Icon(Icons.archive_outlined),
                onPressed: entry.onArchive,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MasterEditorDialog extends StatefulWidget {
  const _MasterEditorDialog({
    required this.kind,
    required this.store,
    this.genre,
    this.character,
    this.costume,
    this.event,
  });
  final _MasterKind kind;
  final MasterDataStore store;
  final Genre? genre;
  final CosplayCharacter? character;
  final Costume? costume;
  final ParticipationEvent? event;

  @override
  State<_MasterEditorDialog> createState() => _MasterEditorDialogState();
}

class _MasterEditorDialogState extends State<_MasterEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text:
        widget.genre?.name ??
        widget.character?.name ??
        widget.costume?.name ??
        widget.event?.name,
  );
  late final TextEditingController _tags = TextEditingController(
    text: widget.costume?.tags.join('、') ?? '',
  );
  late bool _isGeneral = widget.costume?.isGeneral ?? true;
  late String? _parentId = widget.character?.genreId;
  late final Set<String> _selectedGenres = {...?widget.costume?.genreIds};
  late final Set<String> _selectedCharacters = {
    ...?widget.costume?.characterIds,
  };
  bool _showCharacterError = false;

  @override
  void dispose() {
    _name.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing =
        widget.genre != null ||
        widget.character != null ||
        widget.costume != null ||
        widget.event != null;
    final genres = widget.store.genres
        .where((e) => !e.archived || _selectedGenres.contains(e.id))
        .toList();
    final characters = widget.store.characters
        .where(
          (e) =>
              (_selectedGenres.isEmpty ||
                  _selectedGenres.contains(e.genreId)) &&
              (!e.archived || _selectedCharacters.contains(e.id)),
        )
        .toList();
    return AlertDialog(
      title: Text('${widget.kind.label}を${editing ? '編集' : '追加'}'),
      content: SizedBox(
        width: 360,
        height: widget.kind == _MasterKind.costume
            ? (MediaQuery.sizeOf(context).height * 0.48).clamp(180.0, 360.0)
            : null,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '名前'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '名前を入力してください'
                      : null,
                ),
                if (widget.kind == _MasterKind.character) ...[
                  const SizedBox(height: 12),
                  if (editing)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ジャンル: ${widget.store.genres.where((e) => e.id == _parentId).firstOrNull?.name ?? '取得できませんでした'}',
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _parentId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'ジャンル'),
                      items: [
                        for (final genre in genres)
                          DropdownMenuItem(
                            value: genre.id,
                            child: Text(genre.name),
                          ),
                      ],
                      onChanged: (value) => setState(() => _parentId = value),
                      validator: (value) =>
                          value == null ? 'ジャンルを選択してください' : null,
                    ),
                ],
                if (widget.kind == _MasterKind.costume) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _tags,
                    decoration: const InputDecoration(
                      labelText: 'タグ（カンマ区切り）',
                      hintText: '例: メイド服、ロング丈',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ジャンル（未選択なら全ジャンル）',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final genre in genres)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(genre.name),
                      value: _selectedGenres.contains(genre.id),
                      onChanged: (selected) => setState(() {
                        if (selected == true) {
                          _selectedGenres.add(genre.id);
                        } else {
                          _selectedGenres.remove(genre.id);
                        }
                        if (_selectedGenres.isNotEmpty) {
                          _selectedCharacters.removeWhere((id) {
                            final character = widget.store.characters
                                .where((e) => e.id == id)
                                .firstOrNull;
                            return character == null ||
                                !_selectedGenres.contains(character.genreId);
                          });
                        }
                      }),
                    ),
                  for (final id in _selectedGenres.where(
                    (id) => !widget.store.genres.any((e) => e.id == id),
                  ))
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('取得できませんでした'),
                      value: true,
                      onChanged: (_) =>
                          setState(() => _selectedGenres.remove(id)),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<bool>(
                    initialValue: _isGeneral,
                    decoration: const InputDecoration(labelText: '衣装の種類'),
                    items: const [
                      DropdownMenuItem(value: true, child: Text('汎用衣装')),
                      DropdownMenuItem(value: false, child: Text('固有衣装')),
                    ],
                    onChanged: (value) => setState(() => _isGeneral = value!),
                  ),
                  if (!_isGeneral) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '対象キャラクター（複数選択）',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (characters.isEmpty) const Text('対象にできるキャラクターを登録してください'),
                    for (final character in characters)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(character.name),
                        value: _selectedCharacters.contains(character.id),
                        onChanged: (selected) => setState(() {
                          _showCharacterError = false;
                          if (selected == true) {
                            _selectedCharacters.add(character.id);
                          } else {
                            _selectedCharacters.remove(character.id);
                          }
                        }),
                      ),
                    for (final id in _selectedCharacters.where(
                      (id) => !widget.store.characters.any((e) => e.id == id),
                    ))
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('取得できませんでした'),
                        value: true,
                        onChanged: (_) =>
                            setState(() => _selectedCharacters.remove(id)),
                      ),
                    if (_showCharacterError)
                      Text(
                        '対象キャラクターを選択してください',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (widget.kind == _MasterKind.costume &&
                !_isGeneral &&
                _selectedCharacters.isEmpty) {
              setState(() => _showCharacterError = true);
              return;
            }
            Navigator.pop(context, (
              name: _name.text.trim(),
              parentId: _parentId,
              isGeneral: _isGeneral,
              genreIds: _selectedGenres.toList(),
              characterIds: _isGeneral
                  ? <String>[]
                  : _selectedCharacters.toList(),
              tags: _tags.text
                  .replaceAll('、', ',')
                  .replaceAll('，', ',')
                  .split(','),
            ));
          },
          child: Text(editing ? '保存' : '追加'),
        ),
      ],
    );
  }
}
