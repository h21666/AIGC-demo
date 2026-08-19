class LocalTfliteException implements Exception {
  const LocalTfliteException(this.message, {this.fallbackToCloud = true});

  final String message;
  final bool fallbackToCloud;

  @override
  String toString() => 'LocalTfliteException($message)';
}
