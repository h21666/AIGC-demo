import 'dart:io';

import '../../domain/entities/local_model_capability_report.dart';
import '../../domain/repositories/device_capability_service.dart';

class DefaultLocalModelCapabilityService implements DeviceCapabilityService {
  const DefaultLocalModelCapabilityService({
    this.minimumProcessorCount = 2,
    this.platformName,
    this.processorCount,
    this.supportsIsolate,
  });

  final int minimumProcessorCount;
  final String? platformName;
  final int? processorCount;
  final bool? supportsIsolate;

  @override
  Future<LocalModelCapabilityReport> inspect({String? modelPath}) async {
    final resolvedPlatform = platformName ?? Platform.operatingSystem;
    final resolvedProcessorCount =
        processorCount ?? Platform.numberOfProcessors;
    final resolvedSupportsIsolate = supportsIsolate ?? true;
    final modelExists =
        modelPath != null &&
        modelPath.isNotEmpty &&
        await File(modelPath).exists();
    final reasons = <String>[];

    if (!resolvedSupportsIsolate) {
      reasons.add('Isolate execution is unavailable.');
    }
    if (resolvedProcessorCount < minimumProcessorCount) {
      reasons.add(
        'Processor count $resolvedProcessorCount is below the minimum of $minimumProcessorCount.',
      );
    }
    if (!modelExists) {
      reasons.add('Local TFLite model file is missing.');
    }

    return LocalModelCapabilityReport(
      platform: resolvedPlatform,
      processorCount: resolvedProcessorCount,
      supportsIsolate: resolvedSupportsIsolate,
      modelAvailable: modelExists,
      canRunLocal: reasons.isEmpty,
      reasons: reasons,
    );
  }
}
