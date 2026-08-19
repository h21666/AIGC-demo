import 'package:uuid/uuid.dart';

import '../../domain/entities/app_log.dart';
import '../../domain/entities/generation_job.dart';
import '../../domain/entities/generation_task.dart';
import '../../domain/entities/prompt.dart';
import '../../domain/entities/prompt_version.dart';
import '../../domain/enums/generation_job_status.dart';
import '../../domain/enums/generation_provider.dart';
import '../../domain/enums/generation_task_status.dart';
import '../../domain/enums/log_level.dart';
import '../../domain/repositories/prompt_repository.dart';
import '../app_runtime.dart';

class PromptDraft {
  const PromptDraft({
    required this.title,
    required this.content,
    required this.tags,
    this.negativePrompt,
  });

  final String title;
  final String content;
  final String? negativePrompt;
  final List<String> tags;
}

class PromptController {
  PromptController(this.runtime);

  final AppRuntime runtime;
  final Uuid _uuid = const Uuid();

  Future<List<Prompt>> loadPrompts({bool includeArchived = false}) {
    return runtime.prompts.list(includeArchived: includeArchived);
  }

  Future<Prompt> savePrompt({
    Prompt? existing,
    required PromptDraft draft,
  }) async {
    final now = DateTime.now().toUtc();
    final prompt = Prompt(
      id: existing?.id ?? _uuid.v4(),
      title: draft.title,
      content: draft.content,
      negativePrompt: draft.negativePrompt,
      tags: draft.tags,
      description: existing?.description,
      currentVersionId: existing?.currentVersionId,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      isArchived: existing?.isArchived ?? false,
    );
    await runtime.prompts.save(prompt);
    await runtime.logs.append(
      AppLog(
        id: _uuid.v4(),
        level: LogLevel.info,
        message: '提示词已保存',
        context: <String, Object?>{
          'promptId': prompt.id,
          'title': prompt.title,
          'tagCount': prompt.tags.length,
        },
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return prompt;
  }

  Future<void> archivePrompt(Prompt prompt) async {
    await runtime.prompts.archive(prompt.id);
    await runtime.logs.append(
      AppLog(
        id: _uuid.v4(),
        level: LogLevel.warning,
        message: '提示词已归档',
        context: <String, Object?>{'promptId': prompt.id, 'title': prompt.title},
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> deletePrompt(Prompt prompt) async {
    await runtime.prompts.delete(prompt.id);
    await runtime.logs.append(
      AppLog(
        id: _uuid.v4(),
        level: LogLevel.warning,
        message: '提示词已删除',
        context: <String, Object?>{'promptId': prompt.id, 'title': prompt.title},
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<String> exportPrompts() async {
    final json = await runtime.prompts.exportJson();
    await runtime.logs.append(
      AppLog(
        id: _uuid.v4(),
        level: LogLevel.info,
        message: '已导出提示词 JSON',
        context: <String, Object?>{'length': json.length},
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return json;
  }

  Future<PromptImportResult> importPrompts(String json) async {
    final result = await runtime.prompts.importJson(json);
    await runtime.logs.append(
      AppLog(
        id: _uuid.v4(),
        level: LogLevel.info,
        message: '已导入提示词 JSON',
        context: <String, Object?>{
          'imported': result.importedCount,
          'skipped': result.skippedCount,
          'failed': result.failedCount,
        },
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return result;
  }

  Future<List<PromptVersion>> loadVersions(String promptId) {
    return runtime.prompts.listVersions(promptId);
  }

  Future<void> rollbackToVersion({
    required String promptId,
    required String versionId,
  }) async {
    await runtime.prompts.rollbackToVersion(
      promptId: promptId,
      versionId: versionId,
    );
    await runtime.logs.append(
      AppLog(
        id: _uuid.v4(),
        level: LogLevel.info,
        message: '提示词已回退版本',
        context: <String, Object?>{
          'promptId': promptId,
          'versionId': versionId,
        },
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> createTaskFromPrompt({
    required Prompt prompt,
    required int count,
  }) async {
    final current = await runtime.prompts.getById(prompt.id) ?? prompt;
    final versionId = current.currentVersionId;
    if (versionId == null) {
      throw StateError('提示词还没有可用版本，请先保存一次。');
    }
    final now = DateTime.now().toUtc();
    final taskId = _uuid.v4();
    final task = GenerationTask(
      id: taskId,
      promptId: current.id,
      promptVersionId: versionId,
      status: GenerationTaskStatus.pending,
      provider: GenerationProvider.siliconFlow,
      requestPayload: const {
        'model': 'Kwai-Kolors/Kolors',
        'image_size': '1024x1024',
      },
      promptSnapshot: {
        'title': current.title,
        'content': current.content,
        'negativePrompt': current.negativePrompt,
        'tags': current.tags,
      },
      totalJobs: count,
      createdAt: now,
      updatedAt: now,
    );
    await runtime.tasks.saveTask(task);
    for (var index = 0; index < count; index++) {
      await runtime.tasks.saveJob(
        GenerationJob(
          id: _uuid.v4(),
          taskId: taskId,
          status: GenerationJobStatus.pending,
          provider: GenerationProvider.siliconFlow,
          promptVersionId: versionId,
          requestPayload: const {},
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await runtime.logs.append(
      AppLog(
        id: _uuid.v4(),
        level: LogLevel.info,
        message: '生成任务已创建',
        context: <String, Object?>{
          'taskId': taskId,
          'promptId': current.id,
          'count': count,
        },
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }
}
