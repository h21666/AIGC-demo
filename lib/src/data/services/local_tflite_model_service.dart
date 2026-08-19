import '../../domain/entities/hybrid_generation_plan.dart';
import '../../domain/entities/local_tflite_request.dart';
import '../../domain/exceptions/local_tflite_exception.dart';
import '../../domain/repositories/device_capability_service.dart';
import '../../domain/repositories/local_tflite_interpreter.dart';

class LocalTfliteModelService {
  const LocalTfliteModelService({
    required this.capabilityService,
    required this.interpreter,
  });

  final DeviceCapabilityService capabilityService;
  final LocalTfliteInterpreter interpreter;

  Future<HybridGenerationPlan> plan(LocalTfliteRequest request) async {
    final capability = await capabilityService.inspect(
      modelPath: request.modelPath,
    );
    if (!capability.canRunLocal) {
      return HybridGenerationPlan.cloud(
        capability: capability,
        cloudRequest: request.toCloudRequest(),
        fallbackReason: capability.reasons.join(' '),
      );
    }

    try {
      final localResult = await interpreter.infer(request);
      if (localResult.shouldFallbackToCloud) {
        return HybridGenerationPlan.cloud(
          capability: capability,
          cloudRequest: request.toCloudRequest(
            promptOverride: localResult.refinedPrompt,
            negativePromptOverride: localResult.negativePrompt,
            seedOverride: localResult.seed,
          ),
          localResult: localResult,
          fallbackReason: localResult.fallbackReason,
        );
      }
      return HybridGenerationPlan.local(
        capability: capability,
        localResult: localResult,
        cloudRequest: request.toCloudRequest(
          promptOverride: localResult.refinedPrompt,
          negativePromptOverride: localResult.negativePrompt,
          seedOverride: localResult.seed,
        ),
      );
    } on LocalTfliteException catch (error) {
      return HybridGenerationPlan.cloud(
        capability: capability,
        cloudRequest: request.toCloudRequest(),
        fallbackReason: error.message,
      );
    }
  }
}
