import '../enums/log_level.dart';

class AppLogEntry {
  const AppLogEntry({
    required this.id,
    required this.level,
    required this.message,
    required this.createdAt,
    this.context = const {},
  });

  final String id;
  final LogLevel level;
  final String message;
  final Map<String, Object?> context;
  final DateTime createdAt;
}
