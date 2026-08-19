import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../domain/entities/app_log.dart';
import '../../domain/enums/log_level.dart';
import '../../domain/repositories/log_repository.dart';

class SqliteLogRepository implements LogRepository {
  SqliteLogRepository(this._database);

  final AppDatabase _database;

  @override
  Future<void> append(AppLog entry) async {
    final db = await _database.database;
    await db.insert(
      'app_logs',
      _logToRow(entry),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<AppLog>> list({
    LogLevel? minLevel,
    DateTime? createdAfter,
    int? limit,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'app_logs',
      where: createdAfter == null ? null : 'created_at >= ?',
      whereArgs: createdAfter == null
          ? null
          : [createdAfter.toUtc().toIso8601String()],
      orderBy: 'created_at DESC',
    );
    final logs = rows
        .map(_logFromRow)
        .where(
          (log) =>
              minLevel == null || _severity(log.level) >= _severity(minLevel),
        )
        .toList();
    if (limit == null) return logs;
    return logs.take(limit).toList();
  }

  @override
  Future<String> export() async {
    final logs = await list();
    return jsonEncode({
      'schemaVersion': 1,
      'logs': logs.map(_logToJson).toList(),
    });
  }

  @override
  Future<void> clear() async {
    final db = await _database.database;
    await db.delete('app_logs');
  }

  AppLog _logFromRow(Map<String, Object?> row) => AppLog(
    id: row['id']! as String,
    level: _levelFromStorage(row['level']! as String),
    message: row['message']! as String,
    context: _decodeMap(row['context_json']),
    createdAt: DateTime.parse(row['created_at']! as String),
  );

  Map<String, Object?> _logToRow(AppLog value) => {
    'id': value.id,
    'level': value.level.storageKey,
    'message': value.message,
    'context_json': jsonEncode(value.context),
    'created_at': value.createdAt.toUtc().toIso8601String(),
  };

  Map<String, Object?> _logToJson(AppLog value) => {
    'id': value.id,
    'level': value.level.storageKey,
    'message': value.message,
    'context': value.context,
    'createdAt': value.createdAt.toUtc().toIso8601String(),
  };

  Map<String, Object?> _decodeMap(Object? value) {
    if (value is String && value.isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    }
    return const {};
  }

  int _severity(LogLevel level) => switch (level) {
    LogLevel.debug => 0,
    LogLevel.info => 1,
    LogLevel.warning => 2,
    LogLevel.error => 3,
  };

  LogLevel _levelFromStorage(String value) => switch (value) {
    'debug' => LogLevel.debug,
    'info' => LogLevel.info,
    'warning' => LogLevel.warning,
    'error' => LogLevel.error,
    _ => throw FormatException('Unknown log level: $value'),
  };
}
