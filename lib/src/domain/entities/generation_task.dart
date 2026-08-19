import '../enums/generation_provider.dart';
import '../enums/generation_task_status.dart';

class GenerationTask {
  const GenerationTask({
    required this.id,
    required this.promptId,
    required this.promptVersionId,
    required this.status,
    required this.provider,
    required this.createdAt,
    required this.updatedAt,
    this.requestPayload = const {},
    this.promptSnapshot = const {},
    this.totalJobs = 0,
    this.completedJobs = 0,
    this.failedJobs = 0,
    this.retryCount = 0,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
  });

  final String id;
  final String promptId;
  final String promptVersionId;
  final GenerationTaskStatus status;
  final GenerationProvider provider;
  final Map<String, Object?> requestPayload;
  final Map<String, Object?> promptSnapshot;
  final int totalJobs;
  final int completedJobs;
  final int failedJobs;
  final int retryCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? errorMessage;

  bool get isTerminal =>
      status == GenerationTaskStatus.completed ||
      status == GenerationTaskStatus.failed ||
      status == GenerationTaskStatus.cancelled;

  int get processedJobs => completedJobs + failedJobs;

  double get progress {
    if (totalJobs == 0) return 0;
    return processedJobs / totalJobs;
  }
}
