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
  Future<List<Prompt>> list({
    Set<String>? tags,
    bool includeArchived = false,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'prompts',
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'updated_at DESC',
    );
    return rows.map(_promptFromRow).where((prompt) {
      return tags == null || tags.isEmpty || tags.every(prompt.tags.contains);
    }).toList();
  }

  @override
  Future<void> save(Prompt prompt) async {
    final db = await _database.database;
    final tags = _normalizeTags(prompt.tags);
    await db.transaction((txn) async {
      final existingRows = await txn.query(
        'prompts',
        where: 'id = ?',
        whereArgs: [prompt.id],
        limit: 1,
      );
      final existing = existingRows.isEmpty
          ? null
          : _promptFromRow(existingRows.single);
      final promptRow = _promptToRow(
        prompt,
        tags: tags,
        currentVersionId: existing?.currentVersionId ?? prompt.currentVersionId,
      );
      if (existing == null) {
        await txn.insert('prompts', promptRow);
      } else {
        await txn.update(
          'prompts',
          promptRow,
          where: 'id = ?',
          whereArgs: [prompt.id],
        );
      }
      await _replaceTags(txn, prompt.id, tags, prompt.updatedAt);

      if (existing == null || _snapshotChanged(existing, prompt, tags)) {
        final version = await _insertVersion(
          txn,
          promptId: prompt.id,
          title: prompt.title,
          content: prompt.content,
          tags: tags,
          negativePrompt: prompt.negativePrompt,
          changeNote: existing == null ? 'Initial version' : 'Auto save',
          createdAt: prompt.updatedAt,
        );
        await txn.update(
          'prompts',
          {'current_version_id': version.id},
          where: 'id = ?',
          whereArgs: [prompt.id],
        );
      }
    });
  }

  @override
  Future<void> archive(String id) async {
    final db = await _database.database;
    await db.update(
      'prompts',
      {
        'is_archived': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
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
    String? title,
    required String content,
    List<String>? tags,
    String? negativePrompt,
    String? changeNote,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc();
    return db.transaction((txn) async {
      final promptRows = await txn.query(
        'prompts',
        where: 'id = ?',
        whereArgs: [promptId],
        limit: 1,
      );
      if (promptRows.isEmpty) throw StateError('Prompt not found: $promptId');
      final prompt = _promptFromRow(promptRows.single);
      final version = await _insertVersion(
        txn,
        promptId: promptId,
        title: title ?? prompt.title,
        content: content,
        tags: _normalizeTags(tags ?? prompt.tags),
        negativePrompt: negativePrompt,
        changeNote: changeNote,
        createdAt: now,
      );
      await _applyVersionSnapshot(txn, version, now);
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
  Future<void> rollbackToVersion({
    required String promptId,
    required String versionId,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'prompt_versions',
        where: 'id = ? AND prompt_id = ?',
        whereArgs: [versionId, promptId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Prompt version not found: $versionId');
      }
      final source = _versionFromRow(rows.single);
      final rollbackVersion = await _insertVersion(
        txn,
        promptId: promptId,
        title: source.title,
        content: source.content,
        tags: source.tags,
        negativePrompt: source.negativePrompt,
        changeNote: 'Rollback to V${source.versionNumber}',
        createdAt: now,
      );
      await _applyVersionSnapshot(txn, rollbackVersion, now);
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
    return const JsonEncoder.withIndent('  ')
        .convert({'schemaVersion': 2, 'prompts': payload});
  }

  @override
  Future<PromptImportResult> importJson(String json) async {
    final entries = _parseImport(json);
    final db = await _database.database;
    var imported = 0;
    var skipped = 0;
    var failed = 0;

    final existingChecks = <_PromptImportEntry>[];
    for (final entry in entries) {
      final existing = await db.query(
        'prompts',
        where: 'id = ?',
        whereArgs: [entry.promptId],
        limit: 1,
      );
      if (existing.isEmpty) {
        existingChecks.add(entry);
        continue;
      }
      final existingVersions = await db.query(
        'prompt_versions',
        where: 'prompt_id = ?',
        whereArgs: [entry.promptId],
        orderBy: 'version_number DESC',
      );
      if (_samePromptExport(existing.single, existingVersions, entry)) {
        skipped++;
      } else {
        failed++;
      }
    }
    if (failed > 0) {
      throw FormatException('Prompt import has $failed ID conflict(s)');
    }

    await db.transaction((txn) async {
      for (final entry in existingChecks) {
        await txn.insert('prompts', entry.prompt);
        final tags = _decodeTags(entry.prompt['tags_json']);
        await _replaceTags(
          txn,
          entry.promptId,
          tags,
          DateTime.tryParse(entry.prompt['updated_at'] as String? ?? '') ??
              DateTime.now().toUtc(),
        );
        for (final version in entry.versions) {
          await txn.insert('prompt_versions', version);
        }
        imported++;
      }
    });
    return PromptImportResult(
      importedCount: imported,
      skippedCount: skipped,
      failedCount: failed,
    );
  }

  Future<PromptVersion> _insertVersion(
    DatabaseExecutor db, {
    required String promptId,
    required String title,
    required String content,
    required List<String> tags,
    required String? negativePrompt,
    required String? changeNote,
    required DateTime createdAt,
  }) async {
    final maxRows = await db.rawQuery(
      'SELECT MAX(version_number) AS max_version FROM prompt_versions WHERE prompt_id = ?',
      [promptId],
    );
    final maxVersionValue = maxRows.single['max_version'];
    final nextVersion = ((maxVersionValue as num?)?.toInt() ?? 0) + 1;
    final version = PromptVersion(
      id: _uuid.v4(),
      promptId: promptId,
      versionNumber: nextVersion,
      title: title,
      content: content,
      tags: _normalizeTags(tags),
      negativePrompt: negativePrompt,
      changeNote: changeNote,
      createdAt: createdAt.toUtc(),
    );
    await db.insert('prompt_versions', _versionToRow(version));
    return version;
  }

  Future<void> _applyVersionSnapshot(
    DatabaseExecutor db,
    PromptVersion version,
    DateTime updatedAt,
  ) async {
    await db.update(
      'prompts',
      {
        'title': version.title,
        'content': version.content,
        'negative_prompt': version.negativePrompt,
        'tags_json': jsonEncode(version.tags),
        'current_version_id': version.id,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [version.promptId],
    );
    await _replaceTags(db, version.promptId, version.tags, updatedAt);
  }

  Future<void> _replaceTags(
    DatabaseExecutor db,
    String promptId,
    List<String> tags,
    DateTime createdAt,
  ) async {
    await db.delete(
      'prompt_tag_links',
      where: 'prompt_id = ?',
      whereArgs: [promptId],
    );
    for (final tag in _normalizeTags(tags)) {
      final existing = await db.query(
        'prompt_tags',
        where: 'name = ?',
        whereArgs: [tag],
        limit: 1,
      );
      final tagId = existing.isEmpty
          ? _uuid.v4()
          : existing.single['id'] as String;
      if (existing.isEmpty) {
        await db.insert('prompt_tags', {
          'id': tagId,
          'name': tag,
          'created_at': createdAt.toUtc().toIso8601String(),
        });
      }
      await db.insert('prompt_tag_links', {
        'prompt_id': promptId,
        'tag_id': tagId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  List<_PromptImportEntry> _parseImport(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic> || decoded['prompts'] is! List) {
      throw const FormatException('Invalid prompt export format');
    }
    if (decoded['schemaVersion'] != 2) {
      throw const FormatException('Unsupported prompt schemaVersion');
    }
    return (decoded['prompts'] as List).map((item) {
      if (item is! Map<String, dynamic> ||
          item['prompt'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid prompt entry');
      }
      final prompt = Map<String, Object?>.from(item['prompt'] as Map);
      final promptId = prompt['id'] as String?;
      if (promptId == null ||
          prompt['title'] is! String ||
          prompt['content'] is! String ||
          prompt['created_at'] is! String ||
          prompt['updated_at'] is! String) {
        throw const FormatException('Invalid prompt fields');
      }
      final versions = <Map<String, Object?>>[];
      for (final rawVersion in (item['versions'] as List? ?? const [])) {
        if (rawVersion is! Map<String, dynamic>) {
          throw const FormatException('Invalid version entry');
        }
        final version = Map<String, Object?>.from(rawVersion as Map);
        if (version['id'] is! String ||
            version['prompt_id'] != promptId ||
            version['version_number'] is! int ||
            version['title'] is! String ||
            version['content'] is! String ||
            version['created_at'] is! String) {
          throw const FormatException('Invalid version fields');
        }
        versions.add(version);
      }
      return _PromptImportEntry(
        promptId: promptId,
        prompt: prompt,
        versions: versions,
      );
    }).toList();
  }

  bool _samePromptExport(
    Map<String, Object?> existingPrompt,
    List<Map<String, Object?>> existingVersions,
    _PromptImportEntry incoming,
  ) {
    return jsonEncode(existingPrompt) == jsonEncode(incoming.prompt) &&
        jsonEncode(existingVersions) == jsonEncode(incoming.versions);
  }

  bool _snapshotChanged(Prompt existing, Prompt next, List<String> nextTags) {
    return existing.title != next.title ||
        existing.content != next.content ||
        existing.negativePrompt != next.negativePrompt ||
        jsonEncode(_normalizeTags(existing.tags)) != jsonEncode(nextTags);
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
    title: row['title']! as String,
    content: row['content']! as String,
    tags: _decodeTags(row['tags_json']),
    negativePrompt: row['negative_prompt'] as String?,
    changeNote: row['change_note'] as String?,
    createdAt: DateTime.parse(row['created_at']! as String),
  );

  Map<String, Object?> _promptToRow(
    Prompt value, {
    List<String>? tags,
    String? currentVersionId,
  }) => {
    'id': value.id,
    'title': value.title,
    'content': value.content,
    'negative_prompt': value.negativePrompt,
    'description': value.description,
    'tags_json': jsonEncode(tags ?? _normalizeTags(value.tags)),
    'current_version_id': currentVersionId ?? value.currentVersionId,
    'created_at': value.createdAt.toUtc().toIso8601String(),
    'updated_at': value.updatedAt.toUtc().toIso8601String(),
    'is_archived': value.isArchived ? 1 : 0,
  };

  Map<String, Object?> _versionToRow(PromptVersion value) => {
    'id': value.id,
    'prompt_id': value.promptId,
    'version_number': value.versionNumber,
    'title': value.title,
    'content': value.content,
    'tags_json': jsonEncode(value.tags),
    'negative_prompt': value.negativePrompt,
    'change_note': value.changeNote,
    'created_at': value.createdAt.toUtc().toIso8601String(),
  };

  List<String> _decodeTags(Object? value) {
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is List) return _normalizeTags(decoded.whereType<String>());
    }
    if (value is List) return _normalizeTags(value.whereType<String>());
    return const [];
  }

  List<String> _normalizeTags(Iterable<String> tags) {
    return tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }
}

class _PromptImportEntry {
  const _PromptImportEntry({
    required this.promptId,
    required this.prompt,
    required this.versions,
  });

  final String promptId;
  final Map<String, Object?> prompt;
  final List<Map<String, Object?>> versions;
}
