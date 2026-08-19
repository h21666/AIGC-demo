import '../enums/generation_job_status.dart';
import '../enums/generation_provider.dart';

class GenerationJob {
  const GenerationJob({
    required this.id,
    required this.taskId,
    required this.status,
    required this.provider,
    required this.promptVersionId,
    required this.createdAt,
    required this.updatedAt,
    this.requestPayload = const {},
    this.resultImageId,
    this.attempt = 0,
    this.maxAttempts = 3,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
  });

  final String id;
  final String taskId;
  final GenerationJobStatus status;
  final GenerationProvider provider;
  final String promptVersionId;
  final Map<String, Object?> requestPayload;
  final String? resultImageId;
  final int attempt;
  final int maxAttempts;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? errorMessage;

  bool get canRetry =>
      status == GenerationJobStatus.failed && attempt < maxAttempts;
}
