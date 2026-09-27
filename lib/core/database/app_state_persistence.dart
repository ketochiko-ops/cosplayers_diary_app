import 'dart:async';
import 'dart:convert';

import '../../features/contact_lenses/application/lens_store.dart';
import '../../features/contact_lenses/domain/lens_models.dart';
import '../../features/diary/application/diary_store.dart';
import '../../features/diary/domain/diary_models.dart';
import '../../features/master_data/application/master_data_store.dart';
import '../../features/master_data/domain/master_models.dart';
import 'settings_store.dart';

class AppStatePersistence {
  AppStatePersistence({
    required this.store,
    required this.masters,
    required this.diary,
    required this.lenses,
  });
  static const stateKey = 'app_state_v1';
  final SettingsStore store;
  final MasterDataStore masters;
  final DiaryStore diary;
  final LensStore lenses;
  Timer? _timer;
  bool _attached = false;

  Future<void> load() async {
    final source = await store.readSetting(stateKey);
    if (source == null || source.isEmpty) return;
    restoreJson(source);
  }

  void attach() {
    if (_attached) return;
    _attached = true;
    masters.addListener(_schedule);
    diary.addListener(_schedule);
    lenses.addListener(_schedule);
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 250), save);
  }

  Future<void> save() => store.writeSetting(stateKey, exportJson());

  String exportJson() => jsonEncode({
    'genres': [
      for (final e in masters.genres)
        {'id': e.id, 'name': e.name, 'memo': e.memo, 'archived': e.archived},
    ],
    'characters': [
      for (final e in masters.characters)
        {
          'id': e.id,
          'genreId': e.genreId,
          'name': e.name,
          'memo': e.memo,
          'lensProductIds': e.lensProductIds,
          'defaultLensProductId': e.defaultLensProductId,
          'archived': e.archived,
        },
    ],
    'costumes': [
      for (final e in masters.costumes)
        {
          'id': e.id,
          'name': e.name,
          'isGeneral': e.isGeneral,
          'characterId': e.characterId,
          'memo': e.memo,
          'archived': e.archived,
        },
    ],
    'diary': [
      for (final e in diary.entries)
        {
          'id': e.id,
          'activityDate': e.activityDate.toIso8601String(),
          'activityType': e.activityType.name,
          'genreId': e.genreId,
          'characterId': e.characterId,
          'costumeId': e.costumeId,
          'memo': e.memo,
          'photoId': e.photoId,
          'lensInventoryId': e.lensInventoryId,
          'createdAt': e.createdAt.toIso8601String(),
          'updatedAt': e.updatedAt.toIso8601String(),
        },
    ],
    'lensProducts': [
      for (final e in lenses.ledger.products)
        {
          'id': e.id,
          'name': e.name,
          'manufacturer': e.manufacturer,
          'color': e.color,
          'wearType': e.wearType.name,
          'openPeriodDays': e.openPeriodDays,
          'memo': e.memo,
          'archived': e.archived,
        },
    ],
    'lensPurchases': [
      for (final e in lenses.ledger.purchases)
        {
          'id': e.id,
          'productId': e.productId,
          'purchasedOn': e.purchasedOn.toIso8601String(),
          'quantity': e.quantity,
          'unopenedExpiresOn': e.unopenedExpiresOn?.toIso8601String(),
        },
    ],
    'lensInventories': [
      for (final e in lenses.ledger.inventories)
        {
          'id': e.id,
          'purchaseId': e.purchaseId,
          'openedOn': e.openedOn?.toIso8601String(),
          'disposed': e.disposed,
        },
    ],
    'lensUsages': [
      for (final e in lenses.ledger.usages)
        {
          'id': e.id,
          'diaryId': e.diaryId,
          'inventoryId': e.inventoryId,
          'usedOn': e.usedOn.toIso8601String(),
        },
    ],
  });

  void restoreJson(String source) {
    final value = jsonDecode(source) as Map<String, Object?>;
    masters.genres
      ..clear()
      ..addAll([
        for (final raw in _maps(value['genres']))
          Genre(
            id: raw['id'] as String,
            name: raw['name'] as String,
            memo: raw['memo'] as String? ?? '',
            archived: raw['archived'] as bool? ?? false,
          ),
      ]);
    masters.characters
      ..clear()
      ..addAll([
        for (final raw in _maps(value['characters']))
          CosplayCharacter(
            id: raw['id'] as String,
            genreId: raw['genreId'] as String,
            name: raw['name'] as String,
            memo: raw['memo'] as String? ?? '',
            lensProductIds: (raw['lensProductIds'] as List? ?? const [])
                .cast<String>(),
            defaultLensProductId: raw['defaultLensProductId'] as String?,
            archived: raw['archived'] as bool? ?? false,
          ),
      ]);
    masters.costumes
      ..clear()
      ..addAll([
        for (final raw in _maps(value['costumes']))
          Costume(
            id: raw['id'] as String,
            name: raw['name'] as String,
            isGeneral: raw['isGeneral'] as bool,
            characterId: raw['characterId'] as String?,
            memo: raw['memo'] as String? ?? '',
            archived: raw['archived'] as bool? ?? false,
          ),
      ]);
    diary.entries
      ..clear()
      ..addAll([
        for (final raw in _maps(value['diary']))
          DiaryEntry(
            id: raw['id'] as String,
            activityDate: DateTime.parse(raw['activityDate'] as String),
            activityType: ActivityType.values.byName(
              raw['activityType'] as String,
            ),
            genreId: raw['genreId'] as String?,
            characterId: raw['characterId'] as String?,
            costumeId: raw['costumeId'] as String?,
            memo: raw['memo'] as String? ?? '',
            photoId: raw['photoId'] as String?,
            lensInventoryId: raw['lensInventoryId'] as String?,
            createdAt: DateTime.parse(raw['createdAt'] as String),
            updatedAt: DateTime.parse(raw['updatedAt'] as String),
          ),
      ]);
    lenses.ledger.products
      ..clear()
      ..addAll([
        for (final raw in _maps(value['lensProducts']))
          LensProduct(
            id: raw['id'] as String,
            name: raw['name'] as String,
            manufacturer: raw['manufacturer'] as String,
            color: raw['color'] as String,
            wearType: WearType.values.byName(raw['wearType'] as String),
            openPeriodDays: raw['openPeriodDays'] as int?,
            memo: raw['memo'] as String? ?? '',
            archived: raw['archived'] as bool? ?? false,
          ),
      ]);
    lenses.ledger.purchases
      ..clear()
      ..addAll([
        for (final raw in _maps(value['lensPurchases']))
          LensPurchase(
            id: raw['id'] as String,
            productId: raw['productId'] as String,
            purchasedOn: DateTime.parse(raw['purchasedOn'] as String),
            quantity: raw['quantity'] as int,
            unopenedExpiresOn: _date(raw['unopenedExpiresOn']),
          ),
      ]);
    lenses.ledger.inventories
      ..clear()
      ..addAll([
        for (final raw in _maps(value['lensInventories']))
          LensInventory(
            id: raw['id'] as String,
            purchaseId: raw['purchaseId'] as String,
            openedOn: _date(raw['openedOn']),
            disposed: raw['disposed'] as bool? ?? false,
          ),
      ]);
    lenses.ledger.usages
      ..clear()
      ..addAll([
        for (final raw in _maps(value['lensUsages']))
          LensUsage(
            id: raw['id'] as String,
            diaryId: raw['diaryId'] as String,
            inventoryId: raw['inventoryId'] as String,
            usedOn: DateTime.parse(raw['usedOn'] as String),
          ),
      ]);
  }

  List<Map<String, Object?>> _maps(Object? value) =>
      (value as List? ?? const []).cast<Map<String, Object?>>();
  DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  Future<void> dispose() async {
    _timer?.cancel();
    if (_attached) {
      masters.removeListener(_schedule);
      diary.removeListener(_schedule);
      lenses.removeListener(_schedule);
    }
    await save();
  }
}
