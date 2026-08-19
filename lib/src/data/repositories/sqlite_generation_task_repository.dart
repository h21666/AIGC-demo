import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../domain/entities/generation_job.dart';
import '../../domain/entities/generation_task.dart';
import '../../domain/enums/generation_job_status.dart';
import '../../domain/enums/generation_provider.dart';
import '../../domain/enums/generation_task_status.dart';
import '../../domain/repositories/generation_task_repository.dart';

class SqliteGenerationTaskRepository implements GenerationTaskRepository {
  SqliteGenerationTaskRepository(this._database);

  final AppDatabase _database;

  @override
  Future<GenerationTask?> getTaskById(String id) async {
    final db = await _database.database;
    final rows = await db.query(
      'generation_tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _taskFromRow(rows.single);
  }

  @override
  Future<List<GenerationTask>> listTasks({
    Set<GenerationTaskStatus>? statuses,
    int? limit,
  }) async {
    final db = await _database.database;
    final whereArgs = <Object?>[];
    final where = statuses == null || statuses.isEmpty
        ? null
        : 'status IN (${List.filled(statuses.length, '?').join(', ')})';
    if (statuses != null && statuses.isNotEmpty) {
      whereArgs.addAll(statuses.map((status) => status.storageKey));
    }
    final rows = await db.query(
      'generation_tasks',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows.map(_taskFromRow).toList();
  }

  @override
  Future<void> saveTask(GenerationTask task) async {
    final db = await _database.database;
    await db.insert(
      'generation_tasks',
      _taskToRow(task),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateTaskStatus(String id, GenerationTaskStatus status) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc();
    final values = <String, Object?>{
      'status': status.storageKey,
      'updated_at': now.toIso8601String(),
      'error_message': null,
    };
    switch (status) {
      case GenerationTaskStatus.pending:
        values['completed_at'] = null;
        break;
      case GenerationTaskStatus.running:
        values['started_at'] = now.toIso8601String();
        values['completed_at'] = null;
        break;
      case GenerationTaskStatus.paused:
        break;
      case GenerationTaskStatus.failed:
        values['completed_at'] = now.toIso8601String();
        break;
      case GenerationTaskStatus.completed:
      case GenerationTaskStatus.cancelled:
        values['completed_at'] = now.toIso8601String();
        break;
    }
    await db.update(
      'generation_tasks',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> pauseTask(String id) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'generation_tasks',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Task not found: $id');
      }
      await txn.update(
        'generation_jobs',
        {'status': GenerationJobStatus.paused.storageKey, 'updated_at': now},
        where: 'task_id = ? AND status = ?',
        whereArgs: [id, GenerationJobStatus.pending.storageKey],
      );
      await txn.update(
        'generation_tasks',
        {
          'status': GenerationTaskStatus.paused.storageKey,
          'updated_at': now,
          'error_message': null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _refreshTaskSummary(txn, id);
    });
  }

  @override
  Future<void> resumeTask(String id) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'generation_tasks',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Task not found: $id');
      }
      await txn.update(
        'generation_jobs',
        {
          'status': GenerationJobStatus.pending.storageKey,
          'started_at': null,
          'completed_at': null,
          'error_message': null,
          'updated_at': now,
        },
        where: 'task_id = ? AND status = ?',
        whereArgs: [id, GenerationJobStatus.paused.storageKey],
      );
      await txn.update(
        'generation_tasks',
        {
          'status': GenerationTaskStatus.pending.storageKey,
          'updated_at': now,
          'completed_at': null,
          'error_message': null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _refreshTaskSummary(txn, id);
    });
  }

  @override
  Future<void> cancelTask(String id) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'generation_tasks',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Task not found: $id');
      }
      await txn.update(
        'generation_jobs',
        {
          'status': GenerationJobStatus.cancelled.storageKey,
          'completed_at': now,
          'updated_at': now,
          'error_message': null,
        },
        where: 'task_id = ? AND status IN (?, ?, ?)',
        whereArgs: [
          id,
          GenerationJobStatus.pending.storageKey,
          GenerationJobStatus.running.storageKey,
          GenerationJobStatus.paused.storageKey,
        ],
      );
      await txn.update(
        'generation_tasks',
        {
          'status': GenerationTaskStatus.cancelled.storageKey,
          'updated_at': now,
          'completed_at': now,
          'error_message': null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _refreshTaskSummary(txn, id);
    });
  }

  @override
  Future<void> retryTask(String id) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'generation_tasks',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Task not found: $id');
      }
      final jobs = await txn.query(
        'generation_jobs',
        where: 'task_id = ? AND status = ?',
        whereArgs: [id, GenerationJobStatus.failed.storageKey],
      );
      var retriedCount = 0;
      for (final row in jobs) {
        final job = _jobFromRow(row);
        if (!job.canRetry) continue;
        retriedCount++;
        await txn.update(
          'generation_jobs',
          {
            'status': GenerationJobStatus.pending.storageKey,
            'attempt': job.attempt + 1,
            'started_at': null,
            'completed_at': null,
            'error_message': null,
            'result_image_id': null,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [job.id],
        );
      }
      if (retriedCount > 0) {
        await txn.update(
          'generation_tasks',
          {
            'status': GenerationTaskStatus.pending.storageKey,
            'retry_count': _incrementRetryCount(rows.single),
            'updated_at': now,
            'completed_at': null,
            'error_message': null,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      await _refreshTaskSummary(txn, id);
    });
  }

  @override
  Future<List<GenerationJob>> listJobs(String taskId) async {
    final db = await _database.database;
    final rows = await db.query(
      'generation_jobs',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'created_at ASC',
    );
    return rows.map(_jobFromRow).toList();
  }

  @override
  Future<void> saveJob(GenerationJob job) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final taskRows = await txn.query(
        'generation_tasks',
        where: 'id = ?',
        whereArgs: [job.taskId],
        limit: 1,
      );
      if (taskRows.isEmpty) {
        throw StateError('Task not found: ${job.taskId}');
      }
      await txn.insert(
        'generation_jobs',
        _jobToRow(job),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _refreshTaskSummary(txn, job.taskId);
    });
  }

  @override
  Future<void> recoverUnfinishedTasks() async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'generation_tasks',
        where: 'status = ?',
        whereArgs: [GenerationTaskStatus.running.storageKey],
      );
      for (final row in rows) {
        final taskId = row['id'] as String;
        await txn.update(
          'generation_jobs',
          {
            'status': GenerationJobStatus.paused.storageKey,
            'started_at': null,
            'completed_at': null,
            'error_message': null,
            'updated_at': now,
          },
          where: 'task_id = ? AND status = ?',
          whereArgs: [taskId, GenerationJobStatus.running.storageKey],
        );
        await txn.update(
          'generation_tasks',
          {
            'status': GenerationTaskStatus.paused.storageKey,
            'completed_at': null,
            'error_message': null,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [taskId],
        );
        await _refreshTaskSummary(txn, taskId);
      }
    });
  }

  Future<void> _refreshTaskSummary(DatabaseExecutor db, String taskId) async {
    final taskRows = await db.query(
      'generation_tasks',
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    if (taskRows.isEmpty) return;

    final taskRow = taskRows.single;
    final jobs = await db.query(
      'generation_jobs',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'created_at ASC',
    );

    var completedJobs = 0;
    var failedJobs = 0;
    var runningJobs = 0;
    var pendingJobs = 0;
    var pausedJobs = 0;
    String? errorMessage;
    for (final row in jobs) {
      final status = _jobStatusFromStorage(row['status'] as String);
      switch (status) {
        case GenerationJobStatus.completed:
          completedJobs++;
          break;
        case GenerationJobStatus.failed:
          failedJobs++;
          errorMessage ??= row['error_message'] as String?;
          break;
        case GenerationJobStatus.running:
          runningJobs++;
          break;
        case GenerationJobStatus.pending:
          pendingJobs++;
          break;
        case GenerationJobStatus.paused:
          pausedJobs++;
          break;
        case GenerationJobStatus.cancelled:
          break;
      }
    }

    final currentStatus = _taskStatusFromStorage(taskRow['status'] as String);
    final totalJobs = jobs.length;
    final derivedStatus = _deriveTaskStatus(
      currentStatus: currentStatus,
      totalJobs: totalJobs,
      completedJobs: completedJobs,
      failedJobs: failedJobs,
      runningJobs: runningJobs,
      pendingJobs: pendingJobs,
      pausedJobs: pausedJobs,
    );

    final updated = <String, Object?>{
      'total_jobs': totalJobs,
      'completed_jobs': completedJobs,
      'failed_jobs': failedJobs,
      'status': derivedStatus.storageKey,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'error_message': derivedStatus == GenerationTaskStatus.failed
          ? errorMessage
          : null,
    };
    if (derivedStatus == GenerationTaskStatus.completed ||
        derivedStatus == GenerationTaskStatus.failed ||
        derivedStatus == GenerationTaskStatus.cancelled) {
      updated['completed_at'] =
          taskRow['completed_at'] as String? ??
          DateTime.now().toUtc().toIso8601String();
    } else {
      updated['completed_at'] = null;
    }
    if (derivedStatus == GenerationTaskStatus.running &&
        taskRow['started_at'] == null) {
      updated['started_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await db.update(
      'generation_tasks',
      updated,
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  GenerationTaskStatus _deriveTaskStatus({
    required GenerationTaskStatus currentStatus,
    required int totalJobs,
    required int completedJobs,
    required int failedJobs,
    required int runningJobs,
    required int pendingJobs,
    required int pausedJobs,
  }) {
    if (currentStatus == GenerationTaskStatus.completed ||
        currentStatus == GenerationTaskStatus.failed ||
        currentStatus == GenerationTaskStatus.cancelled ||
        currentStatus == GenerationTaskStatus.paused) {
      return currentStatus;
    }
    if (totalJobs > 0 && completedJobs + failedJobs == totalJobs) {
      return completedJobs > 0
          ? GenerationTaskStatus.completed
          : GenerationTaskStatus.failed;
    }
    if (runningJobs > 0) {
      return GenerationTaskStatus.running;
    }
    if (pausedJobs > 0 || pendingJobs > 0) {
      return GenerationTaskStatus.pending;
    }
    if (failedJobs > 0) {
      return GenerationTaskStatus.failed;
    }
    return GenerationTaskStatus.pending;
  }

  int _incrementRetryCount(Map<String, Object?> taskRow) {
    final retryCount = taskRow['retry_count'];
    if (retryCount is int) return retryCount + 1;
    if (retryCount is num) return retryCount.toInt() + 1;
    return 1;
  }

  GenerationTask _taskFromRow(Map<String, Object?> row) => GenerationTask(
    id: row['id']! as String,
    promptId: row['prompt_id']! as String,
    promptVersionId: row['prompt_version_id']! as String,
    status: _taskStatusFromStorage(row['status']! as String),
    provider: _providerFromStorage(row['provider']! as String),
    requestPayload: _decodeMap(row['request_json']),
    promptSnapshot: _decodeMap(row['prompt_snapshot']),
    totalJobs: row['total_jobs']! as int,
    completedJobs: row['completed_jobs']! as int,
    failedJobs: row['failed_jobs']! as int,
    retryCount: row['retry_count']! as int,
    createdAt: DateTime.parse(row['created_at']! as String),
    updatedAt: DateTime.parse(row['updated_at']! as String),
    startedAt: _parseDateTime(row['started_at']),
    completedAt: _parseDateTime(row['completed_at']),
    errorMessage: row['error_message'] as String?,
  );

  GenerationJob _jobFromRow(Map<String, Object?> row) => GenerationJob(
    id: row['id']! as String,
    taskId: row['task_id']! as String,
    status: _jobStatusFromStorage(row['status']! as String),
    provider: _providerFromStorage(row['provider']! as String),
    promptVersionId: row['prompt_version_id']! as String,
    requestPayload: _decodeMap(row['request_json']),
    resultImageId: row['result_image_id'] as String?,
    attempt: row['attempt']! as int,
    maxAttempts: row['max_attempts']! as int,
    createdAt: DateTime.parse(row['created_at']! as String),
    updatedAt: DateTime.parse(row['updated_at']! as String),
    startedAt: _parseDateTime(row['started_at']),
    completedAt: _parseDateTime(row['completed_at']),
    errorMessage: row['error_message'] as String?,
  );

  Map<String, Object?> _taskToRow(GenerationTask value) => {
    'id': value.id,
    'prompt_id': value.promptId,
    'prompt_version_id': value.promptVersionId,
    'status': value.status.storageKey,
    'provider': value.provider.storageKey,
    'request_json': jsonEncode(value.requestPayload),
    'prompt_snapshot': jsonEncode(value.promptSnapshot),
    'total_jobs': value.totalJobs,
    'completed_jobs': value.completedJobs,
    'failed_jobs': value.failedJobs,
    'retry_count': value.retryCount,
    'created_at': value.createdAt.toUtc().toIso8601String(),
    'updated_at': value.updatedAt.toUtc().toIso8601String(),
    'started_at': value.startedAt?.toUtc().toIso8601String(),
    'completed_at': value.completedAt?.toUtc().toIso8601String(),
    'error_message': value.errorMessage,
  };

  Map<String, Object?> _jobToRow(GenerationJob value) => {
    'id': value.id,
    'task_id': value.taskId,
    'status': value.status.storageKey,
    'provider': value.provider.storageKey,
    'prompt_version_id': value.promptVersionId,
    'request_json': jsonEncode(value.requestPayload),
    'result_image_id': value.resultImageId,
    'attempt': value.attempt,
    'max_attempts': value.maxAttempts,
    'created_at': value.createdAt.toUtc().toIso8601String(),
    'updated_at': value.updatedAt.toUtc().toIso8601String(),
    'started_at': value.startedAt?.toUtc().toIso8601String(),
    'completed_at': value.completedAt?.toUtc().toIso8601String(),
    'error_message': value.errorMessage,
  };

  Map<String, Object?> _decodeMap(Object? value) {
    if (value is String && value.isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    }
    return const {};
  }

  DateTime? _parseDateTime(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  GenerationTaskStatus _taskStatusFromStorage(String value) => switch (value) {
    'pending' => GenerationTaskStatus.pending,
    'running' => GenerationTaskStatus.running,
    'paused' => GenerationTaskStatus.paused,
    'failed' => GenerationTaskStatus.failed,
    'completed' => GenerationTaskStatus.completed,
    'cancelled' => GenerationTaskStatus.cancelled,
    _ => throw FormatException('Unknown task status: $value'),
  };

  GenerationJobStatus _jobStatusFromStorage(String value) => switch (value) {
    'pending' => GenerationJobStatus.pending,
    'running' => GenerationJobStatus.running,
    'paused' => GenerationJobStatus.paused,
    'failed' => GenerationJobStatus.failed,
    'completed' => GenerationJobStatus.completed,
    'cancelled' => GenerationJobStatus.cancelled,
    _ => throw FormatException('Unknown job status: $value'),
  };

  GenerationProvider _providerFromStorage(String value) => switch (value) {
    'silicon_flow' => GenerationProvider.siliconFlow,
    'local_tflite' => GenerationProvider.localTflite,
    _ => throw FormatException('Unknown provider: $value'),
  };
}
