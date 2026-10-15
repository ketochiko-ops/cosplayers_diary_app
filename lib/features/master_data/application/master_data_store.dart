import 'package:flutter/foundation.dart';

import '../domain/master_models.dart';

class MasterDataStore extends ChangeNotifier {
  final List<Genre> genres = [];
  final List<CosplayCharacter> characters = [];
  final List<Costume> costumes = [];
  final List<ParticipationEvent> events = [];
  int _sequence = 0;

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  Genre addGenre(String name, {String memo = ''}) {
    final value = Genre(id: _id('genre'), name: _name(name), memo: memo.trim());
    genres.add(value);
    notifyListeners();
    return value;
  }

  ParticipationEvent addEvent(String name, {String memo = ''}) {
    final value = ParticipationEvent(
      id: _id('event'),
      name: _name(name),
      memo: memo.trim(),
    );
    events.add(value);
    notifyListeners();
    return value;
  }

  void updateEvent(String id, String name) {
    final index = events.indexWhere((value) => value.id == id);
    if (index < 0) throw ArgumentError.value(id, 'id', '参加イベントが見つかりません');
    events[index] = events[index].copyWith(name: _name(name));
    notifyListeners();
  }

  void archiveEvent(String id) {
    final index = events.indexWhere((value) => value.id == id);
    if (index < 0) throw ArgumentError.value(id, 'id', '参加イベントが見つかりません');
    events[index] = events[index].copyWith(archived: true);
    notifyListeners();
  }

  void deleteArchivedEvent(String id) {
    final index = events.indexWhere((value) => value.id == id);
    if (index < 0 || !events[index].archived) {
      throw ArgumentError.value(id, 'id', 'アーカイブ済みの参加イベントを選択してください');
    }
    events.removeAt(index);
    notifyListeners();
  }

  CosplayCharacter addCharacter(
    String genreId,
    String name, {
    String memo = '',
  }) {
    _requireActiveGenre(genreId);
    final value = CosplayCharacter(
      id: _id('character'),
      genreId: genreId,
      name: _name(name),
      memo: memo.trim(),
    );
    characters.add(value);
    notifyListeners();
    return value;
  }

  Costume addCostume(
    String name, {
    required bool isGeneral,
    String? genreId,
    List<String>? genreIds,
    String? characterId,
    List<String>? characterIds,
    List<String> tags = const [],
    String memo = '',
  }) {
    final scope = _costumeScope(
      genreIds: genreIds ?? (genreId == null ? null : [genreId]),
      isGeneral: isGeneral,
      characterIds:
          characterIds ?? (characterId == null ? const [] : [characterId]),
    );
    final value = Costume(
      id: _id('costume'),
      name: _name(name),
      isGeneral: isGeneral,
      genreIds: scope.genreIds,
      characterIds: scope.characterIds,
      tags: _tags(tags),
      memo: memo.trim(),
    );
    costumes.add(value);
    notifyListeners();
    return value;
  }

  void updateGenre(String id, String name) =>
      _replaceGenre(id, (value) => value.copyWith(name: _name(name)));

  void updateCharacter(String id, String name) =>
      _replaceCharacter(id, (value) => value.copyWith(name: _name(name)));

  void updateCostume(
    String id, {
    required String name,
    required bool isGeneral,
    String? genreId,
    List<String>? genreIds,
    String? characterId,
    List<String>? characterIds,
    List<String>? tags,
  }) {
    final index = costumes.indexWhere((value) => value.id == id);
    if (index < 0) throw ArgumentError.value(id, 'id', '衣装が見つかりません');
    final current = costumes[index];
    final scope = _costumeScope(
      genreIds: genreIds ?? (genreId == null ? current.genreIds : [genreId]),
      isGeneral: isGeneral,
      characterIds:
          characterIds ??
          (characterId == null ? current.characterIds : [characterId]),
      current: current,
    );
    costumes[index] = Costume(
      id: current.id,
      name: _name(name),
      isGeneral: isGeneral,
      genreIds: scope.genreIds,
      characterIds: scope.characterIds,
      tags: _tags(tags ?? current.tags),
      memo: current.memo,
      archived: current.archived,
    );
    notifyListeners();
  }

  ({List<String> genreIds, List<String> characterIds}) _costumeScope({
    required List<String>? genreIds,
    required bool isGeneral,
    required List<String> characterIds,
    Costume? current,
  }) {
    final ids = isGeneral ? <String>[] : characterIds.toList();
    if (!isGeneral && ids.isEmpty) {
      throw ArgumentError.value(ids, 'characterIds', '対象キャラクターを選択してください');
    }
    if (ids.toSet().length != ids.length) {
      throw ArgumentError.value(ids, 'characterIds', '同じキャラクターを重複登録できません');
    }
    final resolvedGenres =
        genreIds?.toList() ??
        [
          if (ids.isNotEmpty)
            ...characters
                .where((e) => ids.contains(e.id))
                .map((e) => e.genreId),
        ];
    if (resolvedGenres.toSet().length != resolvedGenres.length &&
        genreIds != null) {
      throw ArgumentError.value(resolvedGenres, 'genreIds', '同じジャンルを重複登録できません');
    }
    final uniqueGenres = resolvedGenres.toSet().toList()..sort();
    for (final id in uniqueGenres) {
      if (current?.genreIds.contains(id) != true) _requireActiveGenre(id);
    }
    for (final id in ids) {
      final character = characters.where((e) => e.id == id).firstOrNull;
      if (character == null ||
          (character.archived &&
              !(current?.characterIds.contains(id) ?? false)) ||
          (uniqueGenres.isNotEmpty &&
              !uniqueGenres.contains(character.genreId))) {
        throw ArgumentError.value(
          id,
          'characterIds',
          '選択したジャンルの有効なキャラクターを選択してください',
        );
      }
    }
    ids.sort();
    return (
      genreIds: List.unmodifiable(uniqueGenres),
      characterIds: List.unmodifiable(ids),
    );
  }

  List<String> _tags(List<String> values) {
    final result = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    return List.unmodifiable(result);
  }

  String _name(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(value, 'name', '名前は必須です');
    return trimmed;
  }

  void _requireActiveGenre(String id) {
    if (!genres.any((value) => value.id == id && !value.archived)) {
      throw ArgumentError.value(id, 'genreId', '有効なジャンルを選択してください');
    }
  }

  void archiveGenre(String id) =>
      _replaceGenre(id, (value) => value.copyWith(archived: true));
  void archiveCharacter(String id) =>
      _replaceCharacter(id, (value) => value.copyWith(archived: true));
  void archiveCostume(String id) =>
      _replaceCostume(id, (value) => value.copyWith(archived: true));

  void deleteArchivedGenre(String id) {
    final index = genres.indexWhere((value) => value.id == id);
    if (index < 0 || !genres[index].archived) {
      throw ArgumentError.value(id, 'id', 'アーカイブ済みのジャンルを選択してください');
    }
    genres.removeAt(index);
    notifyListeners();
  }

  void deleteArchivedCharacter(String id) {
    final index = characters.indexWhere((value) => value.id == id);
    if (index < 0 || !characters[index].archived) {
      throw ArgumentError.value(id, 'id', 'アーカイブ済みのキャラクターを選択してください');
    }
    characters.removeAt(index);
    notifyListeners();
  }

  void deleteArchivedCostume(String id) {
    final index = costumes.indexWhere((value) => value.id == id);
    if (index < 0 || !costumes[index].archived) {
      throw ArgumentError.value(id, 'id', 'アーカイブ済みの衣装を選択してください');
    }
    costumes.removeAt(index);
    notifyListeners();
  }

  void _replaceGenre(String id, Genre Function(Genre) update) {
    final index = genres.indexWhere((e) => e.id == id);
    if (index >= 0) genres[index] = update(genres[index]);
    notifyListeners();
  }

  void _replaceCharacter(
    String id,
    CosplayCharacter Function(CosplayCharacter) update,
  ) {
    final index = characters.indexWhere((e) => e.id == id);
    if (index >= 0) characters[index] = update(characters[index]);
    notifyListeners();
  }

  void _replaceCostume(String id, Costume Function(Costume) update) {
    final index = costumes.indexWhere((e) => e.id == id);
    if (index >= 0) costumes[index] = update(costumes[index]);
    notifyListeners();
  }
}
