import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:aigc_studio/src/data/services/default_local_model_capability_service.dart';
import 'package:aigc_studio/src/data/services/isolate_local_tflite_interpreter.dart';
import 'package:aigc_studio/src/data/services/local_tflite_model_service.dart';
import 'package:aigc_studio/src/domain/entities/local_model_capability_report.dart';
import 'package:aigc_studio/src/domain/entities/local_tflite_request.dart';
import 'package:aigc_studio/src/domain/entities/local_tflite_result.dart';
import 'package:aigc_studio/src/domain/enums/local_generation_route.dart';
import 'package:aigc_studio/src/domain/exceptions/local_tflite_exception.dart';
import 'package:aigc_studio/src/domain/repositories/device_capability_service.dart';
import 'package:aigc_studio/src/domain/repositories/local_tflite_interpreter.dart';

void main() {
  group('Local TFLite', () {
    late Directory tempDir;
    late File modelFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('aigc_local_tflite_');
      modelFile = File(path.join(tempDir.path, 'model.tflite'));
      await modelFile.writeAsBytes(List<int>.generate(256, (index) => index));
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'plans local inference when capability and isolate are available',
      () async {
        final service = _service(
          capabilityService: DefaultLocalModelCapabilityService(
            platformName: 'android',
            processorCount: 8,
            supportsIsolate: true,
          ),
          interpreter: _SuccessfulInterpreter(),
        );

        final plan = await service.plan(
          LocalTfliteRequest(
            modelPath: modelFile.path,
            outputPath: path.join(tempDir.path, 'output.png'),
            prompt: 'a calm landscape',
            cloudModel: 'Kwai-Kolors/Kolors',
          ),
        );

        expect(plan.route, LocalGenerationRoute.local);
        expect(plan.isCloudFallback, isFalse);
        expect(plan.cloudRequest, isNotNull);
        expect(plan.localResult, isNotNull);
        expect(plan.localResult!.refinedPrompt, 'a calm landscape');
        expect(plan.cloudRequest.prompt, 'a calm landscape');
        expect(plan.capability.canRunLocal, isTrue);
      },
    );

    test('falls back to cloud when local prompt budget is exceeded', () async {
      final service = _service(
        capabilityService: DefaultLocalModelCapabilityService(
          platformName: 'android',
          processorCount: 8,
          supportsIsolate: true,
        ),
        interpreter: const IsolateLocalTfliteInterpreter(
          maxPromptLengthForLocalInference: 12,
        ),
      );

      final plan = await service.plan(
        LocalTfliteRequest(
          modelPath: modelFile.path,
          outputPath: path.join(tempDir.path, 'output.png'),
          prompt: 'a calm landscape with a mountain and river',
          cloudModel: 'Kwai-Kolors/Kolors',
        ),
      );

      expect(plan.route, LocalGenerationRoute.cloud);
      expect(plan.isCloudFallback, isTrue);
      expect(plan.cloudRequest, isNotNull);
      expect(
        plan.cloudRequest.prompt,
        'a calm landscape with a mountain and river',
      );
      expect(plan.fallbackReason, isNotNull);
      expect(plan.localResult, isNotNull);
      expect(plan.localResult!.shouldFallbackToCloud, isTrue);
    });

    test(
      'falls back to cloud when capability check rejects local execution',
      () async {
        final service = _service(
          capabilityService: _RejectingCapabilityService(),
          interpreter: _FailingInterpreter(),
        );

        final plan = await service.plan(
          LocalTfliteRequest(
            modelPath: modelFile.path,
            outputPath: path.join(tempDir.path, 'output.png'),
            prompt: 'a calm landscape',
            cloudModel: 'Kwai-Kolors/Kolors',
          ),
        );

        expect(plan.route, LocalGenerationRoute.cloud);
        expect(plan.cloudRequest, isNotNull);
        expect(plan.localResult, isNull);
        expect(plan.fallbackReason, isNotEmpty);
      },
    );

    test('falls back to cloud when interpreter throws', () async {
      final service = _service(
        capabilityService: DefaultLocalModelCapabilityService(
          platformName: 'android',
          processorCount: 8,
          supportsIsolate: true,
        ),
        interpreter: _ThrowingInterpreter(),
      );

      final plan = await service.plan(
        LocalTfliteRequest(
          modelPath: modelFile.path,
          outputPath: path.join(tempDir.path, 'output.png'),
          prompt: 'a calm landscape',
          cloudModel: 'Kwai-Kolors/Kolors',
        ),
      );

      expect(plan.route, LocalGenerationRoute.cloud);
      expect(plan.cloudRequest, isNotNull);
      expect(plan.fallbackReason, 'Local model failed.');
    });
  });
}

LocalTfliteModelService _service({
  required DeviceCapabilityService capabilityService,
  required LocalTfliteInterpreter interpreter,
}) {
  return LocalTfliteModelService(
    capabilityService: capabilityService,
    interpreter: interpreter,
  );
}

class _RejectingCapabilityService implements DeviceCapabilityService {
  @override
  Future<LocalModelCapabilityReport> inspect({String? modelPath}) async {
    return const LocalModelCapabilityReport(
      platform: 'android',
      processorCount: 1,
      supportsIsolate: false,
      modelAvailable: false,
      canRunLocal: false,
      reasons: ['Device is too limited.'],
    );
  }
}

class _FailingInterpreter implements LocalTfliteInterpreter {
  @override
  Future<LocalTfliteResult> infer(LocalTfliteRequest request) async {
    throw const LocalTfliteException('Interpreter should not run.');
  }
}

class _ThrowingInterpreter implements LocalTfliteInterpreter {
  @override
  Future<LocalTfliteResult> infer(LocalTfliteRequest request) async {
    throw const LocalTfliteException('Local model failed.');
  }
}

class _SuccessfulInterpreter implements LocalTfliteInterpreter {
  @override
  Future<LocalTfliteResult> infer(LocalTfliteRequest request) async {
    return LocalTfliteResult(
      route: LocalGenerationRoute.local,
      refinedPrompt: request.prompt,
      generatedImagePath: request.outputPath,
      width: 64,
      height: 64,
      sizeBytes: 128,
    );
  }
}
