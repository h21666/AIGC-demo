import '../enums/local_generation_route.dart';

class LocalTfliteResult {
  const LocalTfliteResult({
    required this.route,
    required this.refinedPrompt,
    this.generatedImagePath,
    this.width,
    this.height,
    this.sizeBytes,
    this.negativePrompt,
    this.seed,
    this.confidence = 0,
    this.warnings = const [],
    this.raw = const {},
    this.fallbackReason,
  });

  final LocalGenerationRoute route;
  final String refinedPrompt;
  final String? generatedImagePath;
  final int? width;
  final int? height;
  final int? sizeBytes;
  final String? negativePrompt;
  final int? seed;
  final double confidence;
  final List<String> warnings;
  final Map<String, Object?> raw;
  final String? fallbackReason;

  bool get shouldFallbackToCloud => route == LocalGenerationRoute.cloud;

  Map<String, Object?> toJson() => {
    'route': route.name,
    'refined_prompt': refinedPrompt,
    'generated_image_path': generatedImagePath,
    'width': width,
    'height': height,
    'size_bytes': sizeBytes,
    'negative_prompt': negativePrompt,
    'seed': seed,
    'confidence': confidence,
    'warnings': warnings,
    'raw': raw,
    'fallback_reason': fallbackReason,
  };

  factory LocalTfliteResult.fromJson(Map<String, Object?> json) {
    final route = switch (json['route'] as String? ?? 'local') {
      'cloud' => LocalGenerationRoute.cloud,
      _ => LocalGenerationRoute.local,
    };
    return LocalTfliteResult(
      route: route,
      refinedPrompt: json['refined_prompt'] as String? ?? '',
      generatedImagePath: json['generated_image_path'] as String?,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      negativePrompt: json['negative_prompt'] as String?,
      seed: (json['seed'] as num?)?.toInt(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      warnings:
          (json['warnings'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const [],
      raw: json['raw'] is Map
          ? Map<String, Object?>.from(json['raw'] as Map)
          : const {},
      fallbackReason: json['fallback_reason'] as String?,
    );
  }
}
