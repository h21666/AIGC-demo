import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:aigc_studio/src/core/database/app_database.dart';
import 'package:aigc_studio/src/data/repositories/sqlite_prompt_repository.dart';
import 'package:aigc_studio/src/domain/entities/prompt.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SqlitePromptRepository', () {
    late Directory tempDir;
    late AppDatabase database;
    late SqlitePromptRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('aigc_prompt_test_');
      database = AppDatabase(databasePath: path.join(tempDir.path, 'test.db'));
      repository = SqlitePromptRepository(database);
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('supports CRUD, tags, and archive filtering', () async {
      final promptA = _prompt(
        id: 'prompt-a',
        title: 'City skyline',
        content: 'A neon city skyline',
        tags: const ['city', 'night'],
      );
      final promptB = _prompt(
        id: 'prompt-b',
        title: 'Forest',
        content: 'A misty forest',
        tags: const ['nature'],
      );

      await repository.save(promptA);
      await repository.save(promptB);

      final loadedA = await repository.getById('prompt-a');
      expect(loadedA, isNotNull);
      expect(loadedA!.title, 'City skyline');
      expect(loadedA.tags, containsAll(<String>['city', 'night']));

      await repository.save(_prompt(
        id: 'prompt-a',
        title: 'City skyline updated',
        content: 'A brighter neon city skyline',
        tags: const ['city', 'night', 'featured'],
      ));

      final updatedA = await repository.getById('prompt-a');
      expect(updatedA, isNotNull);
      expect(updatedA!.title, 'City skyline updated');
      expect(updatedA.tags, contains('featured'));

      final cityPrompts = await repository.list(tags: const {'city'});
      expect(cityPrompts.map((prompt) => prompt.id), ['prompt-a']);

      final matchedBothTags = await repository.list(
        tags: const {'city', 'night'},
      );
      expect(matchedBothTags.map((prompt) => prompt.id), ['prompt-a']);

      await repository.archive('prompt-a');

      final activePrompts = await repository.list();
      expect(activePrompts.map((prompt) => prompt.id), ['prompt-b']);

      final allPrompts = await repository.list(includeArchived: true);
      expect(
        allPrompts.map((prompt) => prompt.id),
        containsAll(<String>['prompt-a', 'prompt-b']),
      );

      await repository.delete('prompt-b');
      expect(await repository.getById('prompt-b'), isNull);
    });

    test('creates versions and rolls back to history', () async {
      const promptId = 'prompt-versioned';
      await repository.save(_prompt(
        id: promptId,
        title: 'Base',
        content: 'Initial content',
      ));

      final firstVersion = await repository.createVersion(
        promptId: promptId,
        content: 'Second content',
        changeNote: 'Improve detail',
      );
      final secondVersion = await repository.createVersion(
        promptId: promptId,
        content: 'Third content',
        changeNote: 'Refine composition',
      );

      expect(firstVersion.versionNumber, 1);
      expect(secondVersion.versionNumber, 2);

      final versions = await repository.listVersions(promptId);
      expect(versions.map((version) => version.versionNumber), [2, 1]);

      await repository.rollbackToVersion(
        promptId: promptId,
        versionId: firstVersion.id,
      );

      final rolledBack = await repository.getById(promptId);
      expect(rolledBack, isNotNull);
      expect(rolledBack!.content, 'Second content');
      expect(rolledBack.currentVersionId, firstVersion.id);
    });

    test('exports and imports prompt data without duplication', () async {
      const promptId = 'prompt-export';
      await repository.save(_prompt(
        id: promptId,
        title: 'Export me',
        content: 'Export content',
        tags: const ['shared', 'export'],
      ));
      await repository.createVersion(
        promptId: promptId,
        content: 'Export content v2',
        changeNote: 'Second draft',
      );

      final exported = await repository.exportJson();

      final importedDir =
          await Directory.systemTemp.createTemp('aigc_prompt_import_');
      final importedDatabase = AppDatabase(
        databasePath: path.join(importedDir.path, 'import.db'),
      );
      final importedRepository = SqlitePromptRepository(importedDatabase);
      addTearDown(() async {
        await importedDatabase.close();
        if (await importedDir.exists()) {
          await importedDir.delete(recursive: true);
        }
      });

      await importedRepository.importJson(exported);
      await importedRepository.importJson(exported);

      final importedPrompt = await importedRepository.getById(promptId);
      expect(importedPrompt, isNotNull);
      expect(importedPrompt!.tags, containsAll(<String>['shared', 'export']));
      final importedVersions = await importedRepository.listVersions(promptId);
      expect(importedVersions.length, 1);
    });

    test('rejects malformed json and preserves existing data', () async {
      const promptId = 'prompt-safe';
      await repository.save(_prompt(
        id: promptId,
        title: 'Safe prompt',
        content: 'Safe content',
      ));

      await expectLater(
        repository.importJson('{"prompts": 123}'),
        throwsFormatException,
      );
      expect(await repository.getById(promptId), isNotNull);
    });
  });
}

Prompt _prompt({
  required String id,
  required String title,
  required String content,
  List<String> tags = const [],
}) {
  final timestamp = DateTime.utc(2026, 8, 19, 12, 0, 0);
  return Prompt(
    id: id,
    title: title,
    content: content,
    tags: tags,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
