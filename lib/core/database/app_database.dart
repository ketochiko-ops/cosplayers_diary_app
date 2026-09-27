import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';

import 'schema.dart';
import 'settings_store.dart';

class AppDatabase implements SettingsStore {
  AppDatabase._(this.raw);
  final Database raw;

  static Future<AppDatabase> openDefault() async {
    final root = await sqflite.getDatabasesPath();
    return open(
      path: path.join(root, 'cosplayers_diary.db'),
      factory: sqflite.databaseFactory,
    );
  }

  static Future<AppDatabase> open({
    required String path,
    required DatabaseFactory factory,
  }) async {
    final database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _apply(db, 0, version),
        onUpgrade: _apply,
      ),
    );
    return AppDatabase._(database);
  }

  static Future<void> _apply(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await db.transaction((transaction) async {
      for (final migration in migrations) {
        if (migration.version > oldVersion && migration.version <= newVersion) {
          for (final statement in migration.statements) {
            await transaction.execute(statement);
          }
        }
      }
    });
  }

  @override
  Future<String?> readSetting(String key) async {
    final rows = await raw.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  @override
  Future<void> writeSetting(String key, String value) => raw.insert(
    'settings',
    {'key': key, 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> close() => raw.close();
}
