import 'dart:io';
import 'dart:isolate';

import '../../domain/entities/local_tflite_request.dart';
import '../../domain/entities/local_tflite_result.dart';
import '../../domain/enums/local_generation_route.dart';
import '../../domain/exceptions/local_tflite_exception.dart';
import '../../domain/repositories/local_tflite_interpreter.dart';

class IsolateLocalTfliteInterpreter implements LocalTfliteInterpreter {
  const IsolateLocalTfliteInterpreter({
    this.maxPromptLengthForLocalInference = 240,
    this.minimumModelBytes = 16,
  });

  final int maxPromptLengthForLocalInference;
  final int minimumModelBytes;

  @override
  Future<LocalTfliteResult> infer(LocalTfliteRequest request) async {
    return Isolate.run(
      () => _localTfliteWorker(
        request.toJson(),
        maxPromptLengthForLocalInference,
        minimumModelBytes,
      ),
    );
  }
}

LocalTfliteResult _localTfliteWorker(
  Map<String, Object?> requestJson,
  int maxPromptLengthForLocalInference,
  int minimumModelBytes,
) {
  final request = LocalTfliteRequest.fromJson(requestJson);
  final modelPath = request.modelPath;
  if (modelPath == null || modelPath.trim().isEmpty) {
    throw const LocalTfliteException('Local model path is missing.');
  }

  final modelFile = File(modelPath);
  if (!modelFile.existsSync()) {
    throw LocalTfliteException('Local model file is missing: $modelPath');
  }
  if (modelFile.lengthSync() < minimumModelBytes) {
    throw const LocalTfliteException('Local model file is too small.');
  }

  final normalizedPrompt = request.prompt.trim().replaceAll(
    RegExp(r'\s+'),
    ' ',
  );
  if (normalizedPrompt.isEmpty) {
    throw const LocalTfliteException('Prompt is empty.');
  }

  if (normalizedPrompt.length > maxPromptLengthForLocalInference) {
    return LocalTfliteResult(
      route: LocalGenerationRoute.cloud,
      refinedPrompt: normalizedPrompt,
      negativePrompt: request.negativePrompt,
      seed: request.seed,
      confidence: 0.35,
      warnings: const ['Prompt exceeds the local inference budget.'],
      raw: {
        'prompt_length': normalizedPrompt.length,
        'model_bytes': modelFile.lengthSync(),
      },
      fallbackReason: 'Prompt is better handled by cloud generation.',
    );
  }

  final seed =
      request.seed ?? _deriveSeed(normalizedPrompt, modelFile.lengthSync());
  return LocalTfliteResult(
    route: LocalGenerationRoute.local,
    refinedPrompt: _refinePrompt(normalizedPrompt),
    negativePrompt: request.negativePrompt,
    seed: seed,
    confidence: _confidenceFor(normalizedPrompt, modelFile.lengthSync()),
    warnings: const ['Local inference uses the checked-in isolate scaffold.'],
    raw: {
      'prompt_length': normalizedPrompt.length,
      'model_bytes': modelFile.lengthSync(),
      'platform_hint': Platform.operatingSystem,
    },
  );
}

String _refinePrompt(String prompt) {
  final words = prompt.split(' ');
  if (words.length <= 4) return prompt;
  return '${words.take(4).join(' ')} ...';
}

int _deriveSeed(String prompt, int modelBytes) {
  final hash = Object.hash(prompt, modelBytes);
  return hash.abs();
}

double _confidenceFor(String prompt, int modelBytes) {
  final promptScore = prompt.length.clamp(24, 240) / 240;
  final modelScore = modelBytes.clamp(16, 4096) / 4096;
  final confidence = 0.4 + (promptScore * 0.35) + (modelScore * 0.25);
  return confidence.clamp(0.0, 1.0);
}
