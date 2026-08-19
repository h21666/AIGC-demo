import '../entities/app_log_entry.dart';
import '../enums/log_level.dart';

abstract interface class LogRepository {
  Future<void> append(AppLogEntry entry);

  Future<List<AppLogEntry>> list({
    LogLevel? minLevel,
    DateTime? createdAfter,
    int? limit,
  });

  Future<String> export();

  Future<void> clear();
}
