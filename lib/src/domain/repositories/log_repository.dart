import '../entities/app_log.dart';
import '../enums/log_level.dart';

abstract interface class LogRepository {
  Future<void> append(AppLog entry);

  Future<List<AppLog>> list({
    LogLevel? minLevel,
    DateTime? createdAfter,
    int? limit,
  });

  Future<String> export();

  Future<void> clear();
}
