import 'package:flutter/material.dart';

import '../application/master_data_store.dart';
import '../domain/master_models.dart';

enum _MasterKind { genre, character, costume }

extension on _MasterKind {
  String get label => switch (this) {
    _MasterKind.genre => 'ジャンル',
    _MasterKind.character => 'キャラクター',
    _MasterKind.costume => '衣装',
  };
}

typedef _MasterInput = ({String name, String? parentId, bool isGeneral});

class MasterDataPage extends StatefulWidget {
  const MasterDataPage({required this.store, super.key});
  final MasterDataStore store;

  @override
  State<MasterDataPage> createState() => _MasterDataPageState();
}

class _MasterDataPageState extends State<MasterDataPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final genres = widget.store.genres.where((e) => !e.archived).toList();
      final characters = widget.store.characters
          .where((e) => !e.archived)
          .toList();
      final costumes = widget.store.costumes.where((e) => !e.archived).toList();
      return Column(
        children: [
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'ジャンル'),
              Tab(text: 'キャラクター'),
              Tab(text: '衣装'),
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
                        detail: widget.store.genres
                            .where((e) => e.id == character.genreId)
                            .firstOrNull
                            ?.name,
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
                        name: costume.name,
                        detail: costume.isGeneral
                            ? '汎用衣装'
                            : '固有衣装 · ${widget.store.characters.where((e) => e.id == costume.characterId).firstOrNull?.name ?? '不明なキャラクター'}',
                        onEdit: () =>
                            _edit(_MasterKind.costume, costume: costume),
                        onArchive: () =>
                            widget.store.archiveCostume(costume.id),
                      ),
                  ],
                ),
              ],
            ),
          ),
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
            characterId: input.parentId,
          );
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
  }) async {
    final input = await showDialog<_MasterInput>(
      context: context,
      builder: (_) => _MasterEditorDialog(
        kind: kind,
        store: widget.store,
        genre: genre,
        character: character,
        costume: costume,
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
            characterId: input.parentId,
          );
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
  });
  final _MasterKind kind;
  final MasterDataStore store;
  final Genre? genre;
  final CosplayCharacter? character;
  final Costume? costume;

  @override
  State<_MasterEditorDialog> createState() => _MasterEditorDialogState();
}

class _MasterEditorDialogState extends State<_MasterEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.genre?.name ?? widget.character?.name ?? widget.costume?.name,
  );
  late bool _isGeneral = widget.costume?.isGeneral ?? true;
  late String? _parentId =
      widget.character?.genreId ?? widget.costume?.characterId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing =
        widget.genre != null ||
        widget.character != null ||
        widget.costume != null;
    final genres = widget.store.genres.where((e) => !e.archived).toList();
    final characters = widget.store.characters
        .where((e) => !e.archived || e.id == widget.costume?.characterId)
        .toList();
    return AlertDialog(
      title: Text('${widget.kind.label}を${editing ? '編集' : '追加'}'),
      content: SizedBox(
        width: 360,
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
                        'ジャンル: ${widget.store.genres.where((e) => e.id == _parentId).firstOrNull?.name ?? '不明'}',
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
                    DropdownButtonFormField<String>(
                      key: ValueKey('costume-owner-$_parentId'),
                      initialValue: characters.any((e) => e.id == _parentId)
                          ? _parentId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '対象キャラクター'),
                      items: [
                        for (final character in characters)
                          DropdownMenuItem(
                            value: character.id,
                            child: Text(
                              '${widget.store.genres.where((e) => e.id == character.genreId).firstOrNull?.name ?? '不明'} · ${character.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => _parentId = value),
                      validator: (value) =>
                          value == null ? 'キャラクターを選択してください' : null,
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
            Navigator.pop(context, (
              name: _name.text.trim(),
              parentId: _isGeneral && widget.kind == _MasterKind.costume
                  ? null
                  : _parentId,
              isGeneral: _isGeneral,
            ));
          },
          child: Text(editing ? '保存' : '追加'),
        ),
      ],
    );
  }
}
