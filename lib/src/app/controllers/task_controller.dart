import 'package:uuid/uuid.dart';

import '../../domain/entities/app_log.dart';
import '../../domain/entities/generation_task.dart';
import '../../domain/enums/generation_task_status.dart';
import '../../domain/enums/log_level.dart';
import '../app_runtime.dart';

class TaskController {
  TaskController(this.runtime);

  final AppRuntime runtime;
  final Uuid _uuid = const Uuid();

  Future<List<GenerationTask>> loadTasks({int limit = 50}) {
    return runtime.tasks.listTasks(
      statuses: const {
        GenerationTaskStatus.pending,
        GenerationTaskStatus.running,
        GenerationTaskStatus.paused,
        GenerationTaskStatus.failed,
        GenerationTaskStatus.completed,
      },
      limit: limit,
    );
  }

  Future<void> pauseTask(GenerationTask task) {
    return _mutate(
      task,
      runtime.tasks.pauseTask,
      message: '生成任务已暂停',
      level: LogLevel.info,
    );
  }

  Future<void> resumeTask(GenerationTask task) {
    return _mutate(
      task,
      runtime.tasks.resumeTask,
      message: '生成任务已恢复',
      level: LogLevel.info,
    );
  }

  Future<void> cancelTask(GenerationTask task) {
    return _mutate(
      task,
      runtime.tasks.cancelTask,
      message: '生成任务已取消',
      level: LogLevel.warning,
    );
  }

  Future<void> retryTask(GenerationTask task) {
    return _mutate(
      task,
      runtime.tasks.retryTask,
      message: '生成任务已安排重试',
      level: LogLevel.info,
    );
  }

  Future<void> _mutate(
    GenerationTask task,
    Future<void> Function(String id) action, {
    required String message,
    required LogLevel level,
  }) async {
    await action(task.id);
    await runtime.runQueueOnce();
    await runtime.logs.append(
      AppLog(
        id: _uuid.v4(),
        level: level,
        message: message,
        context: <String, Object?>{
          'taskId': task.id,
          'previousStatus': task.status.storageKey,
        },
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }
}
