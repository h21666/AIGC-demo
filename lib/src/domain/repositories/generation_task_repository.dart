import '../entities/generation_job.dart';
import '../entities/generation_task.dart';
import '../enums/generation_task_status.dart';

abstract interface class GenerationTaskRepository {
  Future<GenerationTask?> getTaskById(String id);

  Future<List<GenerationTask>> listTasks({
    Set<GenerationTaskStatus>? statuses,
    int? limit,
  });

  Future<void> saveTask(GenerationTask task);

  Future<void> updateTaskStatus(String id, GenerationTaskStatus status);

  Future<void> pauseTask(String id);

  Future<void> resumeTask(String id);

  Future<void> cancelTask(String id);

  Future<void> retryTask(String id);

  Future<List<GenerationJob>> listJobs(String taskId);

  Future<void> saveJob(GenerationJob job);

  Future<void> recoverUnfinishedTasks();
}
