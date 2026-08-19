import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:aigc_studio/src/core/database/app_database.dart';
import 'package:aigc_studio/src/data/clients/cloud_generation_exception.dart';
import 'package:aigc_studio/src/data/clients/image_generation_client.dart';
import 'package:aigc_studio/src/data/repositories/sqlite_generated_asset_repository.dart';
import 'package:aigc_studio/src/data/repositories/sqlite_generation_task_repository.dart';
import 'package:aigc_studio/src/data/repositories/sqlite_prompt_repository.dart';
import 'package:aigc_studio/src/data/services/cloud_generation_queue_runner.dart';
import 'package:aigc_studio/src/data/services/generated_image_downloader.dart';
import 'package:aigc_studio/src/data/services/local_tflite_model_service.dart';
import 'package:aigc_studio/src/data/storage/in_memory_secure_api_key_store.dart';
import 'package:aigc_studio/src/domain/entities/generation_job.dart';
import 'package:aigc_studio/src/domain/entities/generation_task.dart';
import 'package:aigc_studio/src/domain/entities/local_model_capability_report.dart';
import 'package:aigc_studio/src/domain/entities/local_tflite_request.dart';
import 'package:aigc_studio/src/domain/entities/local_tflite_result.dart';
import 'package:aigc_studio/src/domain/entities/prompt.dart';
import 'package:aigc_studio/src/domain/entities/silicon_flow_image_request.dart';
import 'package:aigc_studio/src/domain/entities/silicon_flow_image_result.dart';
import 'package:aigc_studio/src/domain/enums/local_generation_route.dart';
import 'package:aigc_studio/src/domain/enums/cloud_generation_failure_type.dart';
import 'package:aigc_studio/src/domain/enums/generation_job_status.dart';
import 'package:aigc_studio/src/domain/enums/generation_provider.dart';
import 'package:aigc_studio/src/domain/enums/generation_task_status.dart';
import 'package:aigc_studio/src/domain/repositories/device_capability_service.dart';
import 'package:aigc_studio/src/domain/repositories/local_tflite_interpreter.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('CloudGenerationException', () {
    test('classifies authentication, rate limit, timeout, and no network', () {
      expect(_fromStatus(401).type, CloudGenerationFailureType.authentication);
      expect(_fromStatus(401).retryable, isFalse);

      expect(_fromStatus(429).type, CloudGenerationFailureType.rateLimited);
      expect(_fromStatus(429).retryable, isTrue);

      final timeout = CloudGenerationException.fromDioException(
        DioException(
          requestOptions: RequestOptions(path: '/images/generations'),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      expect(timeout.type, CloudGenerationFailureType.timeout);
      expect(timeout.retryable, isTrue);

      final noNetwork = CloudGenerationException.fromDioException(
        DioException(
          requestOptions: RequestOptions(path: '/images/generations'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(noNetwork.type, CloudGenerationFailureType.noNetwork);
      expect(noNetwork.retryable, isTrue);
    });
  });

  group('CloudGenerationQueueRunner', () {
    late Directory tempDir;
    late AppDatabase database;
    late SqliteGenerationTaskRepository taskRepository;
    late SqliteGeneratedAssetRepository assetRepository;
    late InMemorySecureApiKeyStore apiKeyStore;
    late String promptVersionId;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('aigc_cloud_test_');
      database = AppDatabase(databasePath: path.join(tempDir.path, 'test.db'));
      taskRepository = SqliteGenerationTaskRepository(database);
      assetRepository = SqliteGeneratedAssetRepository(database);
      apiKeyStore = InMemorySecureApiKeyStore();
      await apiKeyStore.writeApiKey('test-key');
      promptVersionId = await _seedPrompt(database);
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('generates, downloads, saves asset, and completes job', () async {
      await _seedTaskAndJob(taskRepository, promptVersionId);
      final client = _FakeImageGenerationClient.success();
      final runner = CloudGenerationQueueRunner(
        taskRepository: taskRepository,
        assetRepository: assetRepository,
        apiKeyStore: apiKeyStore,
        imageClient: client,
        imageDownloader: _FakeImageDownloader(),
        outputDirectory: Directory(path.join(tempDir.path, 'images')),
      );

      final result = await runner.runNextPendingJob();

      expect(result.processed, isTrue);
      expect(result.assetId, isNotNull);
      expect(client.calls, 1);
      expect(client.requests.single.model, 'Kwai-Kolors/Kolors');
      expect(client.requests.single.prompt, 'A neon skyline');

      final asset = await assetRepository.getById(result.assetId!);
      expect(asset, isNotNull);
      expect(await File(asset!.filePath).exists(), isTrue);
      expect(asset.taskId, 'task-1');
      expect(asset.jobId, 'job-1');

      final jobs = await taskRepository.listJobs('task-1');
      expect(jobs.single.status, GenerationJobStatus.completed);
      expect(jobs.single.resultImageId, result.assetId);

      final task = await taskRepository.getTaskById('task-1');
      expect(task!.status, GenerationTaskStatus.completed);
    });

    test('does not retry authentication failures', () async {
      await _seedTaskAndJob(taskRepository, promptVersionId);
      final client = _FakeImageGenerationClient.fail(
        const CloudGenerationException(
          type: CloudGenerationFailureType.authentication,
          message: 'bad key',
          retryable: false,
          statusCode: 401,
        ),
      );
      final runner = CloudGenerationQueueRunner(
        taskRepository: taskRepository,
        assetRepository: assetRepository,
        apiKeyStore: apiKeyStore,
        imageClient: client,
        imageDownloader: _FakeImageDownloader(),
        outputDirectory: Directory(path.join(tempDir.path, 'images')),
      );

      final result = await runner.runNextPendingJob();

      expect(result.error!.type, CloudGenerationFailureType.authentication);
      expect(client.calls, 1);
      final jobs = await taskRepository.listJobs('task-1');
      expect(jobs.single.status, GenerationJobStatus.failed);
      expect(jobs.single.attempt, 1);
    });

    test('retries timeout before completing', () async {
      await _seedTaskAndJob(taskRepository, promptVersionId);
      final client = _FakeImageGenerationClient.sequence([
        const CloudGenerationException(
          type: CloudGenerationFailureType.timeout,
          message: 'timeout',
          retryable: true,
        ),
        SiliconFlowImageResult(
          imageUrls: [Uri.parse('https://example.com/image.png')],
        ),
      ]);
      final runner = CloudGenerationQueueRunner(
        taskRepository: taskRepository,
        assetRepository: assetRepository,
        apiKeyStore: apiKeyStore,
        imageClient: client,
        imageDownloader: _FakeImageDownloader(),
        outputDirectory: Directory(path.join(tempDir.path, 'images')),
      );

      final result = await runner.runNextPendingJob();

      expect(result.error, isNull);
      expect(client.calls, 2);
      final jobs = await taskRepository.listJobs('task-1');
      expect(jobs.single.status, GenerationJobStatus.completed);
      expect(jobs.single.attempt, 2);
    });

    test('returns authentication error when api key is missing', () async {
      await _seedTaskAndJob(taskRepository, promptVersionId);
      await apiKeyStore.deleteApiKey();
      final runner = CloudGenerationQueueRunner(
        taskRepository: taskRepository,
        assetRepository: assetRepository,
        apiKeyStore: apiKeyStore,
        imageClient: _FakeImageGenerationClient.success(),
        imageDownloader: _FakeImageDownloader(),
        outputDirectory: Directory(path.join(tempDir.path, 'images')),
      );

      final result = await runner.runNextPendingJob();

      expect(result.processed, isTrue);
      expect(result.error!.type, CloudGenerationFailureType.authentication);
      expect(result.taskId, 'task-1');
      expect(result.jobId, 'job-1');
      final jobs = await taskRepository.listJobs('task-1');
      expect(jobs.single.status, GenerationJobStatus.failed);
      expect(jobs.single.attempt, 0);
      expect(jobs.single.errorMessage, contains('API key'));
      final task = await taskRepository.getTaskById('task-1');
      expect(task!.status, GenerationTaskStatus.failed);
      expect(await assetRepository.list(), isEmpty);
    });

    test(
      'uses local planning before cloud generation for local tasks',
      () async {
        await _seedTaskAndJob(
          taskRepository,
          promptVersionId,
          provider: GenerationProvider.localTflite,
          promptContent: 'A neon skyline over a rainy street at dusk',
        );
        final localModelService = LocalTfliteModelService(
          capabilityService: _FakeLocalCapabilityService(),
          interpreter: _FakeLocalInterpreter(),
        );
        final client = _FakeImageGenerationClient.success();
        final runner = CloudGenerationQueueRunner(
          taskRepository: taskRepository,
          assetRepository: assetRepository,
          apiKeyStore: apiKeyStore,
          imageClient: client,
          imageDownloader: _FakeImageDownloader(),
          outputDirectory: Directory(path.join(tempDir.path, 'images')),
          localModelService: localModelService,
        );

        final result = await runner.runNextPendingJob();

        expect(result.processed, isTrue);
        expect(client.requests.single.prompt, 'A neon skyline over ...');
        final asset = await assetRepository.getById(result.assetId!);
        expect(asset, isNotNull);
        expect(
          asset!.metadata['generation_route'],
          LocalGenerationRoute.local.name,
        );
        expect(asset.metadata['local_result'], isNotNull);
      },
    );
  });
}

CloudGenerationException _fromStatus(int statusCode) {
  return CloudGenerationException.fromDioException(
    DioException(
      requestOptions: RequestOptions(path: '/images/generations'),
      response: Response<void>(
        requestOptions: RequestOptions(path: '/images/generations'),
        statusCode: statusCode,
      ),
      type: DioExceptionType.badResponse,
    ),
  );
}

Future<String> _seedPrompt(AppDatabase database) async {
  final promptRepository = SqlitePromptRepository(database);
  final timestamp = DateTime.utc(2026, 8, 19, 12, 0, 0);
  await promptRepository.save(
    Prompt(
      id: 'prompt-1',
      title: 'Prompt',
      content: 'A neon skyline',
      tags: const ['city'],
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
  );
  return (await promptRepository.listVersions('prompt-1')).single.id;
}

Future<void> _seedTaskAndJob(
  SqliteGenerationTaskRepository repository,
  String promptVersionId, {
  GenerationProvider provider = GenerationProvider.siliconFlow,
  String promptContent = 'A neon skyline',
}) async {
  final timestamp = DateTime.utc(2026, 8, 19, 12, 0, 0);
  await repository.saveTask(
    GenerationTask(
      id: 'task-1',
      promptId: 'prompt-1',
      promptVersionId: promptVersionId,
      status: GenerationTaskStatus.pending,
      provider: provider,
      requestPayload: const {
        'model': 'Kwai-Kolors/Kolors',
        'image_size': '1024x1024',
      },
      promptSnapshot: {
        'title': 'Prompt',
        'content': promptContent,
        'tags': ['city'],
      },
      totalJobs: 1,
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
  );
  await repository.saveJob(
    GenerationJob(
      id: 'job-1',
      taskId: 'task-1',
      status: GenerationJobStatus.pending,
      provider: provider,
      promptVersionId: promptVersionId,
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
  );
}

class _FakeImageGenerationClient implements ImageGenerationClient {
  _FakeImageGenerationClient.sequence(this._results);

  _FakeImageGenerationClient.success()
    : _results = [
        SiliconFlowImageResult(
          imageUrls: [Uri.parse('https://example.com/image.png')],
          seed: 123,
        ),
      ];

  _FakeImageGenerationClient.fail(CloudGenerationException exception)
    : _results = [exception];

  final List<Object> _results;
  final requests = <SiliconFlowImageRequest>[];
  var calls = 0;

  @override
  Future<SiliconFlowImageResult> generateImages({
    required String apiKey,
    required SiliconFlowImageRequest request,
  }) async {
    calls++;
    requests.add(request);
    final result = _results[(calls - 1).clamp(0, _results.length - 1)];
    if (result is CloudGenerationException) throw result;
    return result as SiliconFlowImageResult;
  }
}

class _FakeImageDownloader implements ImageDownloader {
  @override
  Future<GeneratedImageDownload> download({
    required Uri imageUrl,
    required Directory outputDirectory,
    required String fileName,
  }) async {
    await outputDirectory.create(recursive: true);
    final file = File(path.join(outputDirectory.path, '$fileName.png'));
    final bytes = <int>[1, 2, 3, 4];
    await file.writeAsBytes(bytes);
    return GeneratedImageDownload(
      file: file,
      mimeType: 'image/png',
      sizeBytes: bytes.length,
    );
  }
}

class _FakeLocalCapabilityService implements DeviceCapabilityService {
  @override
  Future<LocalModelCapabilityReport> inspect({String? modelPath}) async {
    return const LocalModelCapabilityReport(
      platform: 'android',
      processorCount: 8,
      supportsIsolate: true,
      modelAvailable: true,
      canRunLocal: true,
      reasons: [],
    );
  }
}

class _FakeLocalInterpreter implements LocalTfliteInterpreter {
  @override
  Future<LocalTfliteResult> infer(LocalTfliteRequest request) async {
    return LocalTfliteResult(
      route: LocalGenerationRoute.local,
      refinedPrompt: 'A neon skyline over ...',
      confidence: 0.93,
      raw: {'prompt': request.prompt},
    );
  }
}
