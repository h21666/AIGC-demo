import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

class SqliteSettingsRepository implements SettingsRepository {
  SqliteSettingsRepository(this._database, {this.cacheDirectories = const []});

  final AppDatabase _database;
  final List<Directory> cacheDirectories;

  @override
  Future<AppSettings?> get(String key) async {
    final db = await _database.database;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : _settingFromRow(rows.single);
  }

  @override
  Future<void> set(AppSettings setting) async {
    final db = await _database.database;
    await db.insert(
      'app_settings',
      _settingToRow(setting),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> remove(String key) async {
    final db = await _database.database;
    await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
  }

  @override
  Future<void> clearCache() async {
    for (final directory in cacheDirectories) {
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(followLinks: false)) {
        await entity.delete(recursive: true);
      }
    }
  }

  AppSettings _settingFromRow(Map<String, Object?> row) => AppSettings(
    key: row['key']! as String,
    value: row['value']! as String,
    updatedAt: DateTime.parse(row['updated_at']! as String),
  );

  Map<String, Object?> _settingToRow(AppSettings value) => {
    'key': value.key,
    'value': value.value,
    'updated_at': value.updatedAt.toUtc().toIso8601String(),
  };
}
