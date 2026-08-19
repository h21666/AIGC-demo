class LocalModelCapabilityReport {
  const LocalModelCapabilityReport({
    required this.platform,
    required this.processorCount,
    required this.supportsIsolate,
    required this.modelAvailable,
    required this.canRunLocal,
    this.reasons = const [],
  });

  final String platform;
  final int processorCount;
  final bool supportsIsolate;
  final bool modelAvailable;
  final bool canRunLocal;
  final List<String> reasons;

  bool get shouldFallbackToCloud => !canRunLocal;

  Map<String, Object?> toJson() => {
    'platform': platform,
    'processor_count': processorCount,
    'supports_isolate': supportsIsolate,
    'model_available': modelAvailable,
    'can_run_local': canRunLocal,
    'reasons': reasons,
  };
}
