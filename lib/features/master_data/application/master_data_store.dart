import 'package:flutter/foundation.dart';

import '../domain/master_models.dart';

class MasterDataStore extends ChangeNotifier {
  final List<Genre> genres = [];
  final List<CosplayCharacter> characters = [];
  final List<Costume> costumes = [];
  int _sequence = 0;

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  Genre addGenre(String name, {String memo = ''}) {
    final value = Genre(id: _id('genre'), name: _name(name), memo: memo.trim());
    genres.add(value);
    notifyListeners();
    return value;
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
    String? characterId,
    String memo = '',
  }) {
    if (!isGeneral) _requireActiveCharacter(characterId);
    final value = Costume(
      id: _id('costume'),
      name: _name(name),
      isGeneral: isGeneral,
      characterId: isGeneral ? null : characterId,
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
    String? characterId,
  }) {
    final index = costumes.indexWhere((value) => value.id == id);
    if (index < 0) throw ArgumentError.value(id, 'id', '衣装が見つかりません');
    final current = costumes[index];
    if (!isGeneral &&
        (characterId != current.characterId || current.isGeneral)) {
      _requireActiveCharacter(characterId);
    }
    costumes[index] = Costume(
      id: current.id,
      name: _name(name),
      isGeneral: isGeneral,
      characterId: isGeneral ? null : characterId,
      memo: current.memo,
      archived: current.archived,
    );
    notifyListeners();
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

  void _requireActiveCharacter(String? id) {
    if (!characters.any((value) => value.id == id && !value.archived)) {
      throw ArgumentError.value(id, 'characterId', '有効なキャラクターを選択してください');
    }
  }

  void archiveGenre(String id) =>
      _replaceGenre(id, (value) => value.copyWith(archived: true));
  void archiveCharacter(String id) =>
      _replaceCharacter(id, (value) => value.copyWith(archived: true));
  void archiveCostume(String id) =>
      _replaceCostume(id, (value) => value.copyWith(archived: true));

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
