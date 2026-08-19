import '../../domain/entities/app_log.dart';
import '../../domain/enums/log_level.dart';
import '../app_runtime.dart';

class LogController {
  LogController(this.runtime);

  final AppRuntime runtime;

  Future<List<AppLog>> loadLogs({
    LogLevel? minLevel,
    int? limit,
  }) {
    return runtime.logs.list(minLevel: minLevel, limit: limit);
  }

  Future<String> exportLogs() {
    return runtime.logs.export();
  }

  Future<void> clearLogs() {
    return runtime.logs.clear();
  }
}
