import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../domain/entities/local_tflite_request.dart';
import '../../domain/entities/local_tflite_result.dart';
import '../../domain/enums/local_generation_route.dart';
import '../../domain/exceptions/local_tflite_exception.dart';
import '../../domain/repositories/local_tflite_interpreter.dart';

class IsolateLocalTfliteInterpreter implements LocalTfliteInterpreter {
  const IsolateLocalTfliteInterpreter({
    this.maxPromptLengthForLocalInference = 240,
    this.minimumModelBytes = 128,
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

Future<LocalTfliteResult> _localTfliteWorker(
  Map<String, Object?> requestJson,
  int maxPromptLengthForLocalInference,
  int minimumModelBytes,
) async {
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

  if (request.outputPath.trim().isEmpty) {
    throw const LocalTfliteException('Local output path is missing.');
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

  final seed = request.seed ?? _deriveSeed(normalizedPrompt);
  Interpreter? interpreter;
  try {
    interpreter = Interpreter.fromFile(modelFile);
    final inputs = interpreter.getInputTensors();
    final outputs = interpreter.getOutputTensors();
    if (inputs.length != 1 || outputs.length != 1) {
      throw const LocalTfliteException(
        'Unsupported model contract: expected one input and one output tensor.',
      );
    }

    final inputTensor = inputs.single;
    final outputTensor = outputs.single;
    final input = _buildInput(inputTensor, seed);
    final dimensions = _readImageDimensions(outputTensor.shape);
    interpreter.runInference([input]);

    final png = _encodeOutputAsPng(
      outputTensor,
      width: dimensions.$1,
      height: dimensions.$2,
      channelsFirst: dimensions.$3,
    );
    final outputFile = File(request.outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(png, flush: true);

    return LocalTfliteResult(
      route: LocalGenerationRoute.local,
      refinedPrompt: normalizedPrompt,
      negativePrompt: request.negativePrompt,
      seed: seed,
      confidence: 1,
      generatedImagePath: outputFile.path,
      width: dimensions.$1,
      height: dimensions.$2,
      sizeBytes: png.length,
      raw: {
        'prompt_length': normalizedPrompt.length,
        'model_bytes': modelFile.lengthSync(),
        'platform': Platform.operatingSystem,
        'input_shape': inputTensor.shape,
        'input_type': inputTensor.type.name,
        'output_shape': outputTensor.shape,
        'output_type': outputTensor.type.name,
        'inference_us': interpreter.lastNativeInferenceDurationMicroSeconds,
        'contract': 'single_tensor_latent_to_rgb_v1',
      },
    );
  } on LocalTfliteException {
    rethrow;
  } on Object catch (error) {
    throw LocalTfliteException('Local TFLite inference failed: $error');
  } finally {
    interpreter?.close();
  }
}

Object _buildInput(Tensor tensor, int seed) {
  final length = tensor.numElements();
  if (length <= 0) {
    throw const LocalTfliteException('Model input tensor is empty.');
  }
  final random = Random(seed);
  final flat = switch (tensor.type) {
    TensorType.float32 => List<double>.generate(
      length,
      (_) => (random.nextDouble() * 2) - 1,
      growable: false,
    ),
    TensorType.uint8 => List<int>.generate(
      length,
      (_) => random.nextInt(256),
      growable: false,
    ),
    TensorType.int8 => List<int>.generate(
      length,
      (_) => random.nextInt(256) - 128,
      growable: false,
    ),
    _ => throw LocalTfliteException(
      'Unsupported model input type: ${tensor.type.name}.',
    ),
  };
  return flat.reshape(tensor.shape);
}

(int, int, bool) _readImageDimensions(List<int> shape) {
  if (shape.length == 4 && shape[0] == 1 && shape[3] == 3) {
    return (shape[2], shape[1], false);
  }
  if (shape.length == 3 && shape[2] == 3) {
    return (shape[1], shape[0], false);
  }
  if (shape.length == 4 && shape[0] == 1 && shape[1] == 3) {
    return (shape[3], shape[2], true);
  }
  if (shape.length == 3 && shape[0] == 3) {
    return (shape[2], shape[1], true);
  }
  throw LocalTfliteException(
    'Unsupported model output shape: $shape. Expected RGB NHWC or NCHW.',
  );
}

Uint8List _encodeOutputAsPng(
  Tensor tensor, {
  required int width,
  required int height,
  required bool channelsFirst,
}) {
  final bytes = tensor.data;
  final values = switch (tensor.type) {
    TensorType.float32 => Float32List.view(
      bytes.buffer,
      bytes.offsetInBytes,
      tensor.numElements(),
    ).map((value) => value.toDouble()).toList(growable: false),
    TensorType.uint8 => Uint8List.view(
      bytes.buffer,
      bytes.offsetInBytes,
      tensor.numElements(),
    ).map((value) => value.toDouble()).toList(growable: false),
    TensorType.int8 => Int8List.view(
      bytes.buffer,
      bytes.offsetInBytes,
      tensor.numElements(),
    ).map((value) => value.toDouble()).toList(growable: false),
    _ => throw LocalTfliteException(
      'Unsupported model output type: ${tensor.type.name}.',
    ),
  };
  final hasNegativeFloat =
      tensor.type == TensorType.float32 && values.any((value) => value < 0);
  final output = image.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      int channel(int c) {
        final index = channelsFirst
            ? (c * width * height) + (y * width) + x
            : ((y * width) + x) * 3 + c;
        final value = values[index];
        if (tensor.type == TensorType.uint8) return value.round();
        if (tensor.type == TensorType.int8) return (value + 128).round();
        final normalized = hasNegativeFloat ? (value + 1) / 2 : value;
        return (normalized.clamp(0.0, 1.0) * 255).round();
      }

      output.setPixelRgb(x, y, channel(0), channel(1), channel(2));
    }
  }
  return Uint8List.fromList(image.encodePng(output));
}

int _deriveSeed(String prompt) {
  var hash = 0x811c9dc5;
  for (final unit in prompt.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
