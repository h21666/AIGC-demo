import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../domain/entities/generated_asset.dart';
import '../../domain/enums/generated_asset_source.dart';
import '../../domain/repositories/asset_repository.dart';

class SqliteGeneratedAssetRepository implements AssetRepository {
  SqliteGeneratedAssetRepository(this._database);

  final AppDatabase _database;

  @override
  Future<GeneratedAsset?> getById(String id) async {
    final db = await _database.database;
    final rows = await db.query(
      'generated_assets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _assetFromRow(rows.single);
  }

  @override
  Future<List<GeneratedAsset>> list({
    String? taskId,
    DateTime? createdAfter,
    DateTime? createdBefore,
  }) async {
    final db = await _database.database;
    final clauses = <String>[];
    final args = <Object?>[];
    if (taskId != null) {
      clauses.add('task_id = ?');
      args.add(taskId);
    }
    if (createdAfter != null) {
      clauses.add('created_at >= ?');
      args.add(createdAfter.toUtc().toIso8601String());
    }
    if (createdBefore != null) {
      clauses.add('created_at <= ?');
      args.add(createdBefore.toUtc().toIso8601String());
    }
    final rows = await db.query(
      'generated_assets',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
    return rows.map(_assetFromRow).toList();
  }

  @override
  Future<void> save(GeneratedAsset asset) async {
    final db = await _database.database;
    await db.insert(
      'generated_assets',
      _assetToRow(asset),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = await _database.database;
    await db.delete('generated_assets', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> markExported(String id, DateTime exportedAt) async {
    final db = await _database.database;
    await db.update(
      'generated_assets',
      {'exported_at': exportedAt.toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  GeneratedAsset _assetFromRow(Map<String, Object?> row) => GeneratedAsset(
    id: row['id']! as String,
    source: _sourceFromStorage(row['source']! as String),
    filePath: row['file_path']! as String,
    taskId: row['task_id'] as String?,
    jobId: row['job_id'] as String?,
    thumbnailPath: row['thumbnail_path'] as String?,
    width: row['width'] as int?,
    height: row['height'] as int?,
    sizeBytes: row['size_bytes'] as int?,
    mimeType: row['mime_type'] as String?,
    seed: row['seed'] as String?,
    promptSnapshot: _decodeMap(row['prompt_snapshot']),
    metadata: _decodeMap(row['metadata_json']),
    createdAt: DateTime.parse(row['created_at']! as String),
    exportedAt: _parseDateTime(row['exported_at']),
  );

  Map<String, Object?> _assetToRow(GeneratedAsset value) => {
    'id': value.id,
    'source': value.source.storageKey,
    'file_path': value.filePath,
    'task_id': value.taskId,
    'job_id': value.jobId,
    'thumbnail_path': value.thumbnailPath,
    'width': value.width,
    'height': value.height,
    'size_bytes': value.sizeBytes,
    'mime_type': value.mimeType,
    'seed': value.seed,
    'prompt_snapshot': jsonEncode(value.promptSnapshot),
    'metadata_json': jsonEncode(value.metadata),
    'created_at': value.createdAt.toUtc().toIso8601String(),
    'exported_at': value.exportedAt?.toUtc().toIso8601String(),
  };

  Map<String, Object?> _decodeMap(Object? value) {
    if (value is String && value.isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    }
    return const {};
  }

  DateTime? _parseDateTime(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  GeneratedAssetSource _sourceFromStorage(String value) => switch (value) {
    'cloud' => GeneratedAssetSource.cloud,
    'local' => GeneratedAssetSource.local,
    'imported' => GeneratedAssetSource.imported,
    _ => throw FormatException('Unknown generated asset source: $value'),
  };
}
