class SiliconFlowImageRequest {
  const SiliconFlowImageRequest({
    required this.model,
    required this.prompt,
    this.imageSize = '1024x1024',
    this.batchSize = 1,
    this.numInferenceSteps = 20,
    this.guidanceScale = 7.5,
    this.negativePrompt,
    this.seed,
    this.extra = const {},
  });

  final String model;
  final String prompt;
  final String imageSize;
  final int batchSize;
  final int numInferenceSteps;
  final double guidanceScale;
  final String? negativePrompt;
  final int? seed;
  final Map<String, Object?> extra;

  Map<String, Object?> toJson() => {
    'model': model,
    'prompt': prompt,
    'image_size': imageSize,
    'batch_size': batchSize,
    'num_inference_steps': numInferenceSteps,
    'guidance_scale': guidanceScale,
    if (negativePrompt != null) 'negative_prompt': negativePrompt,
    if (seed != null) 'seed': seed,
    ...extra,
  };
}
