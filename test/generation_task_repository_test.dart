import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:aigc_studio/src/core/database/app_database.dart';
import 'package:aigc_studio/src/data/repositories/sqlite_generation_task_repository.dart';
import 'package:aigc_studio/src/data/repositories/sqlite_prompt_repository.dart';
import 'package:aigc_studio/src/domain/entities/generation_job.dart';
import 'package:aigc_studio/src/domain/entities/generation_task.dart';
import 'package:aigc_studio/src/domain/entities/prompt.dart';
import 'package:aigc_studio/src/domain/enums/generation_job_status.dart';
import 'package:aigc_studio/src/domain/enums/generation_provider.dart';
import 'package:aigc_studio/src/domain/enums/generation_task_status.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SqliteGenerationTaskRepository', () {
    late Directory tempDir;
    late String databasePath;
    late String promptVersionId;
    late AppDatabase database;
    late SqliteGenerationTaskRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('aigc_task_test_');
      databasePath = path.join(tempDir.path, 'test.db');
      database = AppDatabase(databasePath: databasePath);
      repository = SqliteGenerationTaskRepository(database);
      promptVersionId = await _seedPrompt(database);
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists tasks and jobs with summary counters', () async {
      await repository.saveTask(_task(
        status: GenerationTaskStatus.pending,
        promptVersionId: promptVersionId,
      ));
      await repository.saveJob(_job(
        id: 'job-1',
        status: GenerationJobStatus.pending,
        promptVersionId: promptVersionId,
      ));
      await repository.saveJob(_job(
        id: 'job-2',
        status: GenerationJobStatus.completed,
        promptVersionId: promptVersionId,
      ));

      final task = await repository.getTaskById('task-1');
      expect(task, isNotNull);
      expect(task!.status, GenerationTaskStatus.pending);
      expect(task.totalJobs, 2);
      expect(task.completedJobs, 1);
      expect(task.failedJobs, 0);

      final pendingTasks = await repository.listTasks(
        statuses: const {GenerationTaskStatus.pending},
      );
      expect(pendingTasks.map((task) => task.id), ['task-1']);
    });

    test('marks task completed when all jobs complete', () async {
      await repository.saveTask(_task(
        status: GenerationTaskStatus.pending,
        promptVersionId: promptVersionId,
      ));
      await repository.saveJob(_job(
        id: 'job-1',
        status: GenerationJobStatus.completed,
        promptVersionId: promptVersionId,
      ));
      await repository.saveJob(_job(
        id: 'job-2',
        status: GenerationJobStatus.completed,
        promptVersionId: promptVersionId,
      ));

      final task = await repository.getTaskById('task-1');
      expect(task, isNotNull);
      expect(task!.status, GenerationTaskStatus.completed);
      expect(task.completedJobs, 2);
      expect(task.completedAt, isNotNull);
    });

    test('pauses and resumes pending or running jobs', () async {
      await repository.saveTask(_task(
        status: GenerationTaskStatus.running,
        promptVersionId: promptVersionId,
      ));
      await repository.saveJob(_job(
        id: 'job-1',
        status: GenerationJobStatus.running,
        promptVersionId: promptVersionId,
      ));
      await repository.saveJob(_job(
        id: 'job-2',
        status: GenerationJobStatus.pending,
        promptVersionId: promptVersionId,
      ));
      await repository.saveJob(_job(
        id: 'job-3',
        status: GenerationJobStatus.completed,
        promptVersionId: promptVersionId,
      ));

      await repository.pauseTask('task-1');

      var task = await repository.getTaskById('task-1');
      expect(task!.status, GenerationTaskStatus.paused);
      var jobs = await repository.listJobs('task-1');
      expect(
        jobs.map((job) => job.status),
        [
          GenerationJobStatus.paused,
          GenerationJobStatus.paused,
          GenerationJobStatus.completed,
        ],
      );

      await repository.resumeTask('task-1');

      task = await repository.getTaskById('task-1');
      expect(task!.status, GenerationTaskStatus.pending);
      jobs = await repository.listJobs('task-1');
      expect(
        jobs.map((job) => job.status),
        [
          GenerationJobStatus.pending,
          GenerationJobStatus.pending,
          GenerationJobStatus.completed,
        ],
      );
    });

    test('cancels unfinished jobs and task', () async {
      await repository.saveTask(_task(
        status: GenerationTaskStatus.running,
        promptVersionId: promptVersionId,
      ));
      await repository.saveJob(_job(
        id: 'job-1',
        status: GenerationJobStatus.running,
        promptVersionId: promptVersionId,
      ));
      await repository.saveJob(_job(
        id: 'job-2',
        status: GenerationJobStatus.failed,
        promptVersionId: promptVersionId,
      ));
      await repository.saveJob(_job(
        id: 'job-3',
        status: GenerationJobStatus.completed,
        promptVersionId: promptVersionId,
      ));

      await repository.cancelTask('task-1');

      final task = await repository.getTaskById('task-1');
      expect(task!.status, GenerationTaskStatus.cancelled);
      expect(task.completedAt, isNotNull);
      final jobs = await repository.listJobs('task-1');
      expect(
        jobs.map((job) => job.status),
        [
          GenerationJobStatus.cancelled,
          GenerationJobStatus.cancelled,
          GenerationJobStatus.completed,
        ],
      );
    });

    test('retries failed jobs that have attempts left', () async {
      await repository.saveTask(_task(
        status: GenerationTaskStatus.failed,
        promptVersionId: promptVersionId,
      ));
      await repository.saveJob(_job(
        id: 'job-1',
        status: GenerationJobStatus.failed,
        promptVersionId: promptVersionId,
        attempt: 1,
        maxAttempts: 3,
        errorMessage: 'timeout',
      ));
      await repository.saveJob(_job(
        id: 'job-2',
        status: GenerationJobStatus.failed,
        promptVersionId: promptVersionId,
        attempt: 3,
        maxAttempts: 3,
        errorMessage: 'quota',
      ));

      await repository.retryTask('task-1');

      final task = await repository.getTaskById('task-1');
      expect(task!.status, GenerationTaskStatus.pending);
      expect(task.retryCount, 1);
      final jobs = await repository.listJobs('task-1');
      expect(jobs[0].status, GenerationJobStatus.pending);
      expect(jobs[0].attempt, 2);
      expect(jobs[0].errorMessage, isNull);
      expect(jobs[1].status, GenerationJobStatus.failed);
      expect(jobs[1].attempt, 3);
    });

    test('recovers running work after app restart', () async {
      await repository.saveTask(_task(
        status: GenerationTaskStatus.running,
        promptVersionId: promptVersionId,
      ));
      await repository.saveJob(_job(
        id: 'job-1',
        status: GenerationJobStatus.running,
        promptVersionId: promptVersionId,
      ));
      await repository.saveJob(_job(
        id: 'job-2',
        status: GenerationJobStatus.completed,
        promptVersionId: promptVersionId,
      ));
      await database.close();

      final restartedDatabase = AppDatabase(databasePath: databasePath);
      final restartedRepository = SqliteGenerationTaskRepository(restartedDatabase);
      addTearDown(restartedDatabase.close);

      await restartedRepository.recoverUnfinishedTasks();

      final task = await restartedRepository.getTaskById('task-1');
      expect(task!.status, GenerationTaskStatus.pending);
      final jobs = await restartedRepository.listJobs('task-1');
      expect(
        jobs.map((job) => job.status),
        [GenerationJobStatus.pending, GenerationJobStatus.completed],
      );
    });
  });
}

Future<String> _seedPrompt(AppDatabase database) async {
  final promptRepository = SqlitePromptRepository(database);
  final timestamp = DateTime.utc(2026, 8, 19, 12, 0, 0);
  await promptRepository.save(Prompt(
    id: 'prompt-1',
    title: 'Prompt',
    content: 'Prompt content',
    createdAt: timestamp,
    updatedAt: timestamp,
  ));
  final version = await promptRepository.createVersion(
    promptId: 'prompt-1',
    content: 'Prompt content v1',
  );
  return version.id;
}

GenerationTask _task({
  required GenerationTaskStatus status,
  required String promptVersionId,
}) {
  final timestamp = DateTime.utc(2026, 8, 19, 12, 0, 0);
  return GenerationTask(
    id: 'task-1',
    promptId: 'prompt-1',
    promptVersionId: promptVersionId,
    status: status,
    provider: GenerationProvider.siliconFlow,
    requestPayload: const {'count': 2},
    createdAt: timestamp,
    updatedAt: timestamp,
    startedAt: status == GenerationTaskStatus.running ? timestamp : null,
  );
}

GenerationJob _job({
  required String id,
  required GenerationJobStatus status,
  required String promptVersionId,
  int attempt = 0,
  int maxAttempts = 3,
  String? errorMessage,
}) {
  final timestamp = DateTime.utc(2026, 8, 19, 12, 0, 0);
  return GenerationJob(
    id: id,
    taskId: 'task-1',
    status: status,
    provider: GenerationProvider.siliconFlow,
    promptVersionId: promptVersionId,
    requestPayload: const {'index': 0},
    attempt: attempt,
    maxAttempts: maxAttempts,
    createdAt: timestamp,
    updatedAt: timestamp,
    startedAt: status == GenerationJobStatus.running ? timestamp : null,
    completedAt: status == GenerationJobStatus.completed ? timestamp : null,
    errorMessage: errorMessage,
  );
}
