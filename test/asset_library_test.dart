import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:aigc_studio/src/core/database/app_database.dart';
import 'package:aigc_studio/src/data/repositories/sqlite_generated_asset_repository.dart';
import 'package:aigc_studio/src/data/repositories/sqlite_generation_task_repository.dart';
import 'package:aigc_studio/src/data/repositories/sqlite_prompt_repository.dart';
import 'package:aigc_studio/src/data/services/asset_library_service.dart';
import 'package:aigc_studio/src/data/services/asset_thumbnail_service.dart';
import 'package:aigc_studio/src/data/services/file_album_exporter.dart';
import 'package:aigc_studio/src/data/services/static_media_permission_service.dart';
import 'package:aigc_studio/src/domain/entities/generation_task.dart';
import 'package:aigc_studio/src/domain/entities/generated_asset.dart';
import 'package:aigc_studio/src/domain/entities/prompt.dart';
import 'package:aigc_studio/src/domain/enums/generation_provider.dart';
import 'package:aigc_studio/src/domain/enums/generation_task_status.dart';
import 'package:aigc_studio/src/domain/enums/generated_asset_source.dart';
import 'package:aigc_studio/src/domain/enums/media_permission_status.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Asset library', () {
    late Directory tempDir;
    late Directory imageDir;
    late Directory thumbnailDir;
    late Directory exportDir;
    late AppDatabase database;
    late SqliteGeneratedAssetRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('aigc_asset_test_');
      imageDir = Directory(path.join(tempDir.path, 'images'));
      thumbnailDir = Directory(path.join(tempDir.path, 'thumbs'));
      exportDir = Directory(path.join(tempDir.path, 'exports'));
      await imageDir.create(recursive: true);
      database = AppDatabase(databasePath: path.join(tempDir.path, 'test.db'));
      repository = SqliteGeneratedAssetRepository(database);
      await _seedTasks(database);
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'persists and lists generated asset metadata by filters and ids',
      () async {
        final first = await _createAsset(
          id: 'asset-1',
          imageDir: imageDir,
          taskId: 'task-1',
          createdAt: DateTime.utc(2026, 8, 19, 12),
        );
        final second = await _createAsset(
          id: 'asset-2',
          imageDir: imageDir,
          taskId: 'task-2',
          createdAt: DateTime.utc(2026, 8, 19, 13),
        );
        await repository.saveAll([first, second]);

        final taskAssets = await repository.list(taskId: 'task-1');
        expect(taskAssets.map((asset) => asset.id), ['asset-1']);

        final latest = await repository.list(limit: 1);
        expect(latest.map((asset) => asset.id), ['asset-2']);

        final selected = await repository.listByIds([
          'asset-2',
          'missing',
          'asset-1',
        ]);
        expect(selected.map((asset) => asset.id), ['asset-2', 'asset-1']);
      },
    );

    test('creates thumbnails and returns memory-safe previews', () async {
      final asset = await _createAsset(
        id: 'asset-thumb',
        imageDir: imageDir,
        width: 900,
        height: 600,
      );
      await repository.save(asset);
      final thumbnailService = AssetThumbnailService(
        assetRepository: repository,
        thumbnailDirectory: thumbnailDir,
        maxThumbnailSide: 128,
      );

      final updated = await thumbnailService.ensureThumbnail(asset);
      final preview = thumbnailService.previewFor(updated);

      expect(updated.thumbnailPath, isNotNull);
      expect(await File(updated.thumbnailPath!).exists(), isTrue);
      expect(updated.width, 900);
      expect(updated.height, 600);
      expect(preview.displayPath, updated.thumbnailPath);
      expect(preview.usesThumbnail, isTrue);

      final thumbnailBytes = await File(updated.thumbnailPath!).readAsBytes();
      final thumbnail = img.decodeImage(thumbnailBytes);
      expect(thumbnail, isNotNull);
      expect(thumbnail!.width <= 128 || thumbnail.height <= 128, isTrue);
    });

    test('exports selected assets and marks exported timestamp', () async {
      final first = await _createAsset(id: 'asset-1', imageDir: imageDir);
      final second = await _createAsset(id: 'asset-2', imageDir: imageDir);
      await repository.saveAll([first, second]);
      final library = _library(
        repository: repository,
        thumbnailDir: thumbnailDir,
        exportDir: exportDir,
        permissionStatus: MediaPermissionStatus.granted,
      );

      final result = await library.exportSelected([
        'asset-2',
        'asset-1',
        'asset-1',
      ]);

      expect(result.exportedCount, 2);
      expect(result.failedCount, 0);
      expect(result.exportedPaths.length, 2);
      for (final exportedPath in result.exportedPaths) {
        expect(await File(exportedPath).exists(), isTrue);
      }
      expect((await repository.getById('asset-1'))!.exportedAt, isNotNull);
      expect((await repository.getById('asset-2'))!.exportedAt, isNotNull);
    });

    test('does not export when permission is denied', () async {
      final asset = await _createAsset(id: 'asset-denied', imageDir: imageDir);
      await repository.save(asset);
      final library = _library(
        repository: repository,
        thumbnailDir: thumbnailDir,
        exportDir: exportDir,
        permissionStatus: MediaPermissionStatus.denied,
      );

      final result = await library.exportSelected(['asset-denied']);

      expect(result.exportedCount, 0);
      expect(result.failedCount, 1);
      expect(await exportDir.exists(), isFalse);
      expect((await repository.getById('asset-denied'))!.exportedAt, isNull);
    });

    test('continues export when one selected file is missing', () async {
      final good = await _createAsset(id: 'asset-good', imageDir: imageDir);
      final missing = GeneratedAsset(
        id: 'asset-missing',
        source: GeneratedAssetSource.cloud,
        filePath: path.join(imageDir.path, 'missing.png'),
        createdAt: DateTime.utc(2026, 8, 19, 12),
      );
      await repository.saveAll([good, missing]);
      final library = _library(
        repository: repository,
        thumbnailDir: thumbnailDir,
        exportDir: exportDir,
        permissionStatus: MediaPermissionStatus.granted,
      );

      final result = await library.exportSelected([
        'asset-good',
        'asset-missing',
      ]);

      expect(result.exportedCount, 1);
      expect(result.failedCount, 1);
      expect(result.failures['asset-missing'], 'Asset file not found');
    });

    test('skips selected ids that do not exist', () async {
      final good = await _createAsset(id: 'asset-good', imageDir: imageDir);
      await repository.save(good);
      final library = _library(
        repository: repository,
        thumbnailDir: thumbnailDir,
        exportDir: exportDir,
        permissionStatus: MediaPermissionStatus.granted,
      );

      final result = await library.exportSelected(['asset-good', 'unknown']);

      expect(result.exportedCount, 1);
      expect(result.skippedCount, 1);
      expect(result.failedCount, 0);
    });
  });
}

Future<void> _seedTasks(AppDatabase database) async {
  final promptRepository = SqlitePromptRepository(database);
  final taskRepository = SqliteGenerationTaskRepository(database);
  final timestamp = DateTime.utc(2026, 8, 19, 12);
  await promptRepository.save(
    Prompt(
      id: 'prompt-1',
      title: 'Prompt',
      content: 'A neon skyline',
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
  );
  final version = (await promptRepository.listVersions('prompt-1')).single;
  for (final taskId in ['task-1', 'task-2']) {
    await taskRepository.saveTask(
      GenerationTask(
        id: taskId,
        promptId: 'prompt-1',
        promptVersionId: version.id,
        status: GenerationTaskStatus.completed,
        provider: GenerationProvider.siliconFlow,
        promptSnapshot: const {'title': 'Prompt', 'content': 'A neon skyline'},
        createdAt: timestamp,
        updatedAt: timestamp,
        completedAt: timestamp,
      ),
    );
  }
}

AssetLibraryService _library({
  required SqliteGeneratedAssetRepository repository,
  required Directory thumbnailDir,
  required Directory exportDir,
  required MediaPermissionStatus permissionStatus,
}) {
  return AssetLibraryService(
    assetRepository: repository,
    thumbnailService: AssetThumbnailService(
      assetRepository: repository,
      thumbnailDirectory: thumbnailDir,
    ),
    permissionService: StaticMediaPermissionService(permissionStatus),
    albumExporter: FileAlbumExporter(exportDir),
  );
}

Future<GeneratedAsset> _createAsset({
  required String id,
  required Directory imageDir,
  String taskId = 'task-1',
  int width = 64,
  int height = 64,
  DateTime? createdAt,
}) async {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(60, 120, 200));
  final file = File(path.join(imageDir.path, '$id.png'));
  await file.writeAsBytes(img.encodePng(image));
  final bytes = await file.length();
  return GeneratedAsset(
    id: id,
    source: GeneratedAssetSource.cloud,
    filePath: file.path,
    taskId: taskId,
    width: width,
    height: height,
    sizeBytes: bytes,
    mimeType: 'image/png',
    promptSnapshot: const {'title': 'Prompt', 'content': 'A neon skyline'},
    createdAt: createdAt ?? DateTime.utc(2026, 8, 19, 12),
  );
}
