class SiliconFlowImageResult {
  const SiliconFlowImageResult({
    required this.imageUrls,
    this.seed,
    this.timings = const {},
    this.raw = const {},
  });

  final List<Uri> imageUrls;
  final int? seed;
  final Map<String, Object?> timings;
  final Map<String, Object?> raw;
}
