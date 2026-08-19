class AssetExportResult {
  const AssetExportResult({
    required this.exportedCount,
    required this.skippedCount,
    required this.failedCount,
    this.exportedPaths = const [],
    this.failures = const {},
  });

  final int exportedCount;
  final int skippedCount;
  final int failedCount;
  final List<String> exportedPaths;
  final Map<String, String> failures;
}
