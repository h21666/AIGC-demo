import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/app_database.dart';
import '../data/clients/silicon_flow_image_client.dart';
import '../data/repositories/sqlite_generated_asset_repository.dart';
import '../data/repositories/sqlite_generation_task_repository.dart';
import '../data/repositories/sqlite_log_repository.dart';
import '../data/repositories/sqlite_prompt_repository.dart';
import '../data/repositories/sqlite_settings_repository.dart';
import '../data/services/asset_library_service.dart';
import '../data/services/asset_thumbnail_service.dart';
import '../data/services/cloud_generation_queue_runner.dart';
import '../data/services/default_local_model_capability_service.dart';
import '../data/services/file_album_exporter.dart';
import '../data/services/generated_image_downloader.dart';
import '../data/services/isolate_local_tflite_interpreter.dart';
import '../data/services/local_model_manager.dart';
import '../data/services/local_tflite_model_service.dart';
import '../data/services/platform_album_exporter.dart';
import '../data/services/platform_media_permission_service.dart';
import '../data/services/static_media_permission_service.dart';
import '../data/storage/flutter_secure_api_key_store.dart';
import '../domain/enums/media_permission_status.dart';

class AppRuntime {
  AppRuntime({
    required this.database,
    required this.prompts,
    required this.tasks,
    required this.assets,
    required this.logs,
    required this.settings,
    required this.queueRunner,
    required this.assetLibrary,
    required this.apiKeyStore,
    required this.localModels,
  });

  final AppDatabase database;
  final SqlitePromptRepository prompts;
  final SqliteGenerationTaskRepository tasks;
  final SqliteGeneratedAssetRepository assets;
  final SqliteLogRepository logs;
  final SqliteSettingsRepository settings;
  final CloudGenerationQueueRunner queueRunner;
  final AssetLibraryService assetLibrary;
  final FlutterSecureApiKeyStore apiKeyStore;
  final LocalModelManager localModels;

  Timer? _queueTimer;

  void startQueuePolling() {
    _queueTimer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => runQueueOnce(),
    );
  }

  Future<void> runQueueOnce() async {
    try {
      await queueRunner.runNextPendingJob();
    } on Object {
      // The runner persists job-level errors. The UI remains alive even if
      // an unexpected platform/network error escapes the runner.
    }
  }

  Future<void> dispose() async {
    _queueTimer?.cancel();
    _queueTimer = null;
    await database.close();
  }
}

Future<AppRuntime> createAppRuntime() async {
  final database = AppDatabase();
  await database.database;

  final prompts = SqlitePromptRepository(database);
  final tasks = SqliteGenerationTaskRepository(database);
  final assets = SqliteGeneratedAssetRepository(database);
  final logs = SqliteLogRepository(database);
  final databasesDirectory = Directory(await getDatabasesPath());
  final cacheDirectory = Directory(
    path.join(databasesDirectory.path, 'aigc_studio_cache'),
  );
  final outputDirectory = Directory(
    path.join(databasesDirectory.path, 'aigc_studio_assets'),
  );
  final thumbnailDirectory = Directory(
    path.join(databasesDirectory.path, 'aigc_studio_thumbnails'),
  );
  final settings = SqliteSettingsRepository(
    database,
    cacheDirectories: [cacheDirectory, thumbnailDirectory],
  );
  const apiKeyStore = FlutterSecureApiKeyStore();
  final applicationSupportDirectory = await getApplicationSupportDirectory();
  const localCapabilityService = DefaultLocalModelCapabilityService();
  final localModels = LocalModelManager(
    modelDirectory: Directory(
      path.join(applicationSupportDirectory.path, 'aigc_studio_models'),
    ),
    capabilityService: localCapabilityService,
  );
  final assetThumbnailService = AssetThumbnailService(
    assetRepository: assets,
    thumbnailDirectory: thumbnailDirectory,
  );
  final assetLibrary = AssetLibraryService(
    assetRepository: assets,
    thumbnailService: assetThumbnailService,
    permissionService: Platform.isAndroid
        ? const PlatformMediaPermissionService()
        : const StaticMediaPermissionService(MediaPermissionStatus.granted),
    albumExporter: Platform.isAndroid
        ? const PlatformAlbumExporter()
        : FileAlbumExporter(
            Directory(
              path.join(databasesDirectory.path, 'aigc_studio_exports'),
            ),
          ),
  );
  final queueRunner = CloudGenerationQueueRunner(
    taskRepository: tasks,
    assetRepository: assets,
    apiKeyStore: apiKeyStore,
    imageClient: SiliconFlowImageClient(),
    imageDownloader: GeneratedImageDownloader(),
    outputDirectory: outputDirectory,
    localModelService: const LocalTfliteModelService(
      capabilityService: localCapabilityService,
      interpreter: IsolateLocalTfliteInterpreter(),
    ),
  );

  await tasks.recoverUnfinishedTasks();
  final runtime = AppRuntime(
    database: database,
    prompts: prompts,
    tasks: tasks,
    assets: assets,
    logs: logs,
    settings: settings,
    queueRunner: queueRunner,
    assetLibrary: assetLibrary,
    apiKeyStore: apiKeyStore,
    localModels: localModels,
  );
  runtime.startQueuePolling();
  return runtime;
}
