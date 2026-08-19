import '../entities/silicon_flow_image_request.dart';

class LocalTfliteRequest {
  const LocalTfliteRequest({
    required this.modelPath,
    required this.prompt,
    required this.cloudModel,
    this.negativePrompt,
    this.imageSize = '1024x1024',
    this.batchSize = 1,
    this.numInferenceSteps = 20,
    this.guidanceScale = 7.5,
    this.seed,
    this.extra = const {},
  });

  final String? modelPath;
  final String prompt;
  final String cloudModel;
  final String? negativePrompt;
  final String imageSize;
  final int batchSize;
  final int numInferenceSteps;
  final double guidanceScale;
  final int? seed;
  final Map<String, Object?> extra;

  SiliconFlowImageRequest toCloudRequest({
    String? promptOverride,
    String? negativePromptOverride,
    int? seedOverride,
  }) {
    return SiliconFlowImageRequest(
      model: cloudModel,
      prompt: promptOverride ?? prompt,
      imageSize: imageSize,
      batchSize: batchSize,
      numInferenceSteps: numInferenceSteps,
      guidanceScale: guidanceScale,
      negativePrompt: negativePromptOverride ?? negativePrompt,
      seed: seedOverride ?? seed,
      extra: extra,
    );
  }

  Map<String, Object?> toJson() => {
    'model_path': modelPath,
    'prompt': prompt,
    'cloud_model': cloudModel,
    'negative_prompt': negativePrompt,
    'image_size': imageSize,
    'batch_size': batchSize,
    'num_inference_steps': numInferenceSteps,
    'guidance_scale': guidanceScale,
    'seed': seed,
    'extra': extra,
  };

  factory LocalTfliteRequest.fromJson(Map<String, Object?> json) {
    return LocalTfliteRequest(
      modelPath: json['model_path'] as String?,
      prompt: json['prompt'] as String? ?? '',
      cloudModel: json['cloud_model'] as String? ?? 'Kwai-Kolors/Kolors',
      negativePrompt: json['negative_prompt'] as String?,
      imageSize: json['image_size'] as String? ?? '1024x1024',
      batchSize: (json['batch_size'] as num?)?.toInt() ?? 1,
      numInferenceSteps: (json['num_inference_steps'] as num?)?.toInt() ?? 20,
      guidanceScale: (json['guidance_scale'] as num?)?.toDouble() ?? 7.5,
      seed: (json['seed'] as num?)?.toInt(),
      extra: json['extra'] is Map
          ? Map<String, Object?>.from(json['extra'] as Map)
          : const {},
    );
  }
}
