import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../domain/entities/generated_asset.dart';
import '../../domain/entities/generation_job.dart';
import '../../domain/entities/generation_task.dart';
import '../../domain/entities/silicon_flow_image_request.dart';
import '../../domain/enums/cloud_generation_failure_type.dart';
import '../../domain/enums/generated_asset_source.dart';
import '../../domain/enums/generation_job_status.dart';
import '../../domain/enums/generation_provider.dart';
import '../../domain/enums/generation_task_status.dart';
import '../../domain/repositories/asset_repository.dart';
import '../../domain/repositories/generation_task_repository.dart';
import '../../domain/repositories/secure_api_key_store.dart';
import '../clients/cloud_generation_exception.dart';
import '../clients/image_generation_client.dart';
import 'generated_image_downloader.dart';

class CloudGenerationRunResult {
  const CloudGenerationRunResult({
    required this.processed,
    this.taskId,
    this.jobId,
    this.assetId,
    this.error,
  });

  final bool processed;
  final String? taskId;
  final String? jobId;
  final String? assetId;
  final CloudGenerationException? error;
}

class CloudGenerationQueueRunner {
  CloudGenerationQueueRunner({
    required this.taskRepository,
    required this.assetRepository,
    required this.apiKeyStore,
    required this.imageClient,
    required this.imageDownloader,
    required this.outputDirectory,
    this.defaultModel = 'Kwai-Kolors/Kolors',
    this.retryDelay = Duration.zero,
    Uuid? uuid,
  }) : uuid = uuid ?? const Uuid();

  final GenerationTaskRepository taskRepository;
  final AssetRepository assetRepository;
  final SecureApiKeyStore apiKeyStore;
  final ImageGenerationClient imageClient;
  final ImageDownloader imageDownloader;
  final Directory outputDirectory;
  final String defaultModel;
  final Duration retryDelay;
  final Uuid uuid;

  Future<CloudGenerationRunResult> runNextPendingJob() async {
    final apiKey = await apiKeyStore.readApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      return CloudGenerationRunResult(
        processed: false,
        error: const CloudGenerationException(
          type: CloudGenerationFailureType.authentication,
          message: 'SiliconFlow API key is not configured.',
          retryable: false,
        ),
      );
    }

    final task = await _nextRunnableTask();
    if (task == null) {
      return const CloudGenerationRunResult(processed: false);
    }
    final jobs = await taskRepository.listJobs(task.id);
    final pendingJobs = jobs
        .where((job) => job.status == GenerationJobStatus.pending)
        .toList();
    if (pendingJobs.isEmpty) {
      return const CloudGenerationRunResult(processed: false);
    }

    final job = pendingJobs.first;
    if (task.status == GenerationTaskStatus.pending) {
      await taskRepository.updateTaskStatus(
        task.id,
        GenerationTaskStatus.running,
      );
    }
    return _runJob(apiKey: apiKey.trim(), task: task, job: job);
  }

  Future<CloudGenerationRunResult> _runJob({
    required String apiKey,
    required GenerationTask task,
    required GenerationJob job,
  }) async {
    var attempt = job.attempt;
    CloudGenerationException? lastError;
    while (attempt < job.maxAttempts) {
      attempt++;
      final runningJob = _copyJob(
        job,
        status: GenerationJobStatus.running,
        attempt: attempt,
        startedAt: DateTime.now().toUtc(),
        completedAt: null,
        errorMessage: null,
      );
      await taskRepository.saveJob(runningJob);

      try {
        final request = _buildRequest(task, runningJob);
        final result = await imageClient.generateImages(
          apiKey: apiKey,
          request: request,
        );
        final imageUrl = result.imageUrls.first;
        final assetId = uuid.v4();
        final download = await imageDownloader.download(
          imageUrl: imageUrl,
          outputDirectory: outputDirectory,
          fileName: assetId,
        );
        final asset = GeneratedAsset(
          id: assetId,
          source: GeneratedAssetSource.cloud,
          filePath: download.file.path,
          taskId: task.id,
          jobId: job.id,
          sizeBytes: download.sizeBytes,
          mimeType: download.mimeType,
          seed: result.seed?.toString(),
          promptSnapshot: task.promptSnapshot,
          metadata: {
            'provider': GenerationProvider.siliconFlow.storageKey,
            'source_url': imageUrl.toString(),
            'timings': result.timings,
          },
          createdAt: DateTime.now().toUtc(),
        );
        await assetRepository.save(asset);
        await taskRepository.saveJob(
          _copyJob(
            runningJob,
            status: GenerationJobStatus.completed,
            resultImageId: asset.id,
            completedAt: DateTime.now().toUtc(),
            errorMessage: null,
          ),
        );
        return CloudGenerationRunResult(
          processed: true,
          taskId: task.id,
          jobId: job.id,
          assetId: asset.id,
        );
      } on CloudGenerationException catch (error) {
        lastError = error;
        if (!error.retryable || attempt >= job.maxAttempts) {
          await taskRepository.saveJob(
            _copyJob(
              job,
              status: GenerationJobStatus.failed,
              attempt: attempt,
              startedAt: null,
              completedAt: DateTime.now().toUtc(),
              errorMessage: error.message,
            ),
          );
          return CloudGenerationRunResult(
            processed: true,
            taskId: task.id,
            jobId: job.id,
            error: error,
          );
        }
        if (retryDelay > Duration.zero) {
          await Future<void>.delayed(retryDelay);
        }
      }
    }

    final error =
        lastError ??
        const CloudGenerationException(
          type: CloudGenerationFailureType.unknown,
          message: 'Job has no attempts left.',
          retryable: false,
        );
    await taskRepository.saveJob(
      _copyJob(
        job,
        status: GenerationJobStatus.failed,
        attempt: attempt,
        completedAt: DateTime.now().toUtc(),
        errorMessage: error.message,
      ),
    );
    return CloudGenerationRunResult(
      processed: true,
      taskId: task.id,
      jobId: job.id,
      error: error,
    );
  }

  Future<GenerationTask?> _nextRunnableTask() async {
    final tasks = await taskRepository.listTasks(
      statuses: const {
        GenerationTaskStatus.pending,
        GenerationTaskStatus.running,
      },
    );
    final runnable = <GenerationTask>[];
    for (final task in tasks) {
      final jobs = await taskRepository.listJobs(task.id);
      if (jobs.any((job) => job.status == GenerationJobStatus.pending)) {
        runnable.add(task);
      }
    }
    if (runnable.isEmpty) return null;
    runnable.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return runnable.first;
  }

  SiliconFlowImageRequest _buildRequest(
    GenerationTask task,
    GenerationJob job,
  ) {
    final payload = {...task.requestPayload, ...job.requestPayload};
    final prompt =
        _readString(payload['prompt']) ??
        _readString(task.promptSnapshot['content']);
    if (prompt == null || prompt.trim().isEmpty) {
      throw const CloudGenerationException(
        type: CloudGenerationFailureType.invalidRequest,
        message: 'Generation prompt is empty.',
        retryable: false,
      );
    }
    return SiliconFlowImageRequest(
      model: _readString(payload['model']) ?? defaultModel,
      prompt: prompt,
      imageSize: _readString(payload['image_size']) ?? '1024x1024',
      batchSize: 1,
      numInferenceSteps: _readInt(payload['num_inference_steps']) ?? 20,
      guidanceScale: _readDouble(payload['guidance_scale']) ?? 7.5,
      negativePrompt:
          _readString(payload['negative_prompt']) ??
          _readString(task.promptSnapshot['negativePrompt']),
      seed: _readInt(payload['seed']),
    );
  }

  GenerationJob _copyJob(
    GenerationJob job, {
    required GenerationJobStatus status,
    int? attempt,
    String? resultImageId,
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
  }) {
    final now = DateTime.now().toUtc();
    return GenerationJob(
      id: job.id,
      taskId: job.taskId,
      status: status,
      provider: job.provider,
      promptVersionId: job.promptVersionId,
      requestPayload: job.requestPayload,
      resultImageId: resultImageId ?? job.resultImageId,
      attempt: attempt ?? job.attempt,
      maxAttempts: job.maxAttempts,
      createdAt: job.createdAt,
      updatedAt: now,
      startedAt: startedAt ?? job.startedAt,
      completedAt: completedAt,
      errorMessage: errorMessage,
    );
  }

  String? _readString(Object? value) => value is String ? value : null;

  int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  double? _readDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return null;
  }
}
