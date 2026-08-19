import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../domain/entities/prompt.dart';
import '../../domain/entities/prompt_version.dart';
import '../../domain/repositories/prompt_repository.dart';

class SqlitePromptRepository implements PromptRepository {
  SqlitePromptRepository(this._database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  @override
  Future<Prompt?> getById(String id) async {
    final db = await _database.database;
    final rows = await db.query(
      'prompts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _promptFromRow(rows.single);
  }

  @override
  Future<List<Prompt>> list({Set<String>? tags, bool includeArchived = false}) async {
    final db = await _database.database;
    final rows = await db.query(
      'prompts',
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'updated_at DESC',
    );
    final prompts = rows.map(_promptFromRow).where((prompt) {
      return tags == null || tags.isEmpty || tags.every(prompt.tags.contains);
    }).toList();
    return prompts;
  }

  @override
  Future<void> save(Prompt prompt) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert(
        'prompts',
        _promptToRow(prompt),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _replaceTags(txn, prompt.id, prompt.tags, prompt.updatedAt);
    });
  }

  @override
  Future<void> archive(String id) async {
    final db = await _database.database;
    await db.update(
      'prompts',
      {
        'is_archived': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = await _database.database;
    await db.delete('prompts', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<PromptVersion> createVersion({
    required String promptId,
    required String content,
    String? negativePrompt,
    String? changeNote,
  }) async {
    final db = await _database.database;
    final now = DateTime.now();
    return db.transaction((txn) async {
      final promptRows = await txn.query(
        'prompts',
        where: 'id = ?',
        whereArgs: [promptId],
        limit: 1,
      );
      if (promptRows.isEmpty) throw StateError('Prompt not found: $promptId');
      final maxRows = await txn.rawQuery(
        'SELECT MAX(version_number) AS max_version FROM prompt_versions WHERE prompt_id = ?',
        [promptId],
      );
      final maxVersionValue = maxRows.single['max_version'];
      final nextVersion = ((maxVersionValue as num?)?.toInt() ?? 0) + 1;
      final version = PromptVersion(
        id: _uuid.v4(),
        promptId: promptId,
        versionNumber: nextVersion,
        content: content,
        negativePrompt: negativePrompt,
        changeNote: changeNote,
        createdAt: now,
      );
      await txn.insert('prompt_versions', _versionToRow(version));
      await txn.update(
        'prompts',
        {
          'content': content,
          'negative_prompt': negativePrompt,
          'current_version_id': version.id,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [promptId],
      );
      return version;
    });
  }

  @override
  Future<List<PromptVersion>> listVersions(String promptId) async {
    final db = await _database.database;
    final rows = await db.query(
      'prompt_versions',
      where: 'prompt_id = ?',
      whereArgs: [promptId],
      orderBy: 'version_number DESC',
    );
    return rows.map(_versionFromRow).toList();
  }

  @override
  Future<void> rollbackToVersion({required String promptId, required String versionId}) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'prompt_versions',
        where: 'id = ? AND prompt_id = ?',
        whereArgs: [versionId, promptId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Prompt version not found: $versionId');
      final version = _versionFromRow(rows.single);
      final now = DateTime.now();
      await txn.update(
        'prompts',
        {
          'content': version.content,
          'negative_prompt': version.negativePrompt,
          'current_version_id': version.id,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [promptId],
      );
    });
  }

  @override
  Future<String> exportJson() async {
    final prompts = await list(includeArchived: true);
    final payload = <Map<String, Object?>>[];
    for (final prompt in prompts) {
      payload.add({
        'prompt': _promptToRow(prompt),
        'versions': (await listVersions(prompt.id)).map(_versionToRow).toList(),
      });
    }
    return const JsonEncoder.withIndent('  ').convert({
      'formatVersion': 1,
      'prompts': payload,
    });
  }

  @override
  Future<void> importJson(String json) async {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic> || decoded['prompts'] is! List) {
      throw const FormatException('Invalid prompt export format');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      for (final item in decoded['prompts'] as List) {
        if (item is! Map<String, dynamic> ||
            item['prompt'] is! Map<String, dynamic>) {
          throw const FormatException('Invalid prompt entry');
        }
        final prompt = Map<String, dynamic>.from(item['prompt'] as Map);
        final promptId = prompt['id'] as String?;
        if (promptId == null ||
            prompt['title'] is! String ||
            prompt['content'] is! String) {
          throw const FormatException('Invalid prompt fields');
        }
        await txn.insert('prompts', prompt, conflictAlgorithm: ConflictAlgorithm.replace);
        final tags = _decodeTags(prompt['tags_json']);
        await _replaceTags(
          txn,
          promptId,
          tags,
          DateTime.tryParse(prompt['updated_at'] as String? ?? '') ??
              DateTime.now(),
        );
        await txn.delete('prompt_versions', where: 'prompt_id = ?', whereArgs: [promptId]);
        for (final rawVersion in (item['versions'] as List? ?? const [])) {
          if (rawVersion is! Map<String, dynamic>) {
            throw const FormatException('Invalid version entry');
          }
          await txn.insert(
            'prompt_versions',
            Map<String, dynamic>.from(rawVersion as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<void> _replaceTags(
    DatabaseExecutor db,
    String promptId,
    List<String> tags,
    DateTime createdAt,
  ) async {
    await db.delete('prompt_tag_links', where: 'prompt_id = ?', whereArgs: [promptId]);
    for (final tag
        in tags.map((value) => value.trim()).where((value) => value.isNotEmpty).toSet()) {
      final existing = await db.query(
        'prompt_tags',
        where: 'name = ?',
        whereArgs: [tag],
        limit: 1,
      );
      final tagId = existing.isEmpty ? _uuid.v4() : existing.single['id'] as String;
      if (existing.isEmpty) {
        await db.insert('prompt_tags', {
          'id': tagId,
          'name': tag,
          'created_at': createdAt.toIso8601String(),
        });
      }
      await db.insert(
        'prompt_tag_links',
        {'prompt_id': promptId, 'tag_id': tagId},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Prompt _promptFromRow(Map<String, Object?> row) => Prompt(
        id: row['id']! as String,
        title: row['title']! as String,
        content: row['content']! as String,
        negativePrompt: row['negative_prompt'] as String?,
        description: row['description'] as String?,
        tags: _decodeTags(row['tags_json']),
        currentVersionId: row['current_version_id'] as String?,
        createdAt: DateTime.parse(row['created_at']! as String),
        updatedAt: DateTime.parse(row['updated_at']! as String),
        isArchived: (row['is_archived']! as int) == 1,
      );

  PromptVersion _versionFromRow(Map<String, Object?> row) => PromptVersion(
        id: row['id']! as String,
        promptId: row['prompt_id']! as String,
        versionNumber: row['version_number']! as int,
        content: row['content']! as String,
        negativePrompt: row['negative_prompt'] as String?,
        changeNote: row['change_note'] as String?,
        createdAt: DateTime.parse(row['created_at']! as String),
      );

  Map<String, Object?> _promptToRow(Prompt value) => {
        'id': value.id,
        'title': value.title,
        'content': value.content,
        'negative_prompt': value.negativePrompt,
        'description': value.description,
        'tags_json': jsonEncode(value.tags),
        'current_version_id': value.currentVersionId,
        'created_at': value.createdAt.toIso8601String(),
        'updated_at': value.updatedAt.toIso8601String(),
        'is_archived': value.isArchived ? 1 : 0,
      };

  Map<String, Object?> _versionToRow(PromptVersion value) => {
        'id': value.id,
        'prompt_id': value.promptId,
        'version_number': value.versionNumber,
        'content': value.content,
        'negative_prompt': value.negativePrompt,
        'change_note': value.changeNote,
        'created_at': value.createdAt.toIso8601String(),
      };

  List<String> _decodeTags(Object? value) {
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is List) return decoded.whereType<String>().toList();
    }
    if (value is List) return value.whereType<String>().toList();
    return const [];
  }
}
