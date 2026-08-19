import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'app_database_schema.dart';

class AppDatabase {
  AppDatabase({this.databasePath});

  final String? databasePath;
  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;

    final resolvedDatabasePath =
        databasePath ??
        path.join(await getDatabasesPath(), AppDatabaseSchema.databaseName);
    _database = await openDatabase(
      resolvedDatabasePath,
      version: AppDatabaseSchema.version,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, _) async {
        for (final statement in AppDatabaseSchema.createTableStatements) {
          await database.execute(statement);
        }
        for (final statement in AppDatabaseSchema.createIndexStatements) {
          await database.execute(statement);
        }
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2 && newVersion >= 2) {
          for (final statement in AppDatabaseSchema.migrateFrom1To2Statements) {
            await database.execute(statement);
          }
        }
      },
    );
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
