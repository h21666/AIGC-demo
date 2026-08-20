import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:aigc_studio/src/data/services/local_model_manager.dart';
import 'package:aigc_studio/src/domain/entities/local_model_capability_report.dart';
import 'package:aigc_studio/src/domain/repositories/device_capability_service.dart';

void main() {
  group('LocalModelManager', () {
    late Directory tempDirectory;
    late Directory modelDirectory;
    late LocalModelManager manager;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'aigc_model_manager_',
      );
      modelDirectory = Directory(path.join(tempDirectory.path, 'models'));
      manager = LocalModelManager(
        modelDirectory: modelDirectory,
        capabilityService: const _ReadyCapabilityService(),
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('imports a valid TFLite file into managed storage', () async {
      final info = await manager.importModel(
        fileName: 'comic-generator.tflite',
        bytes: Stream.value(_validTfliteBytes()),
      );

      expect(info.fileName, 'comic-generator.tflite');
      expect(info.path, path.join(modelDirectory.path, 'local_model.tflite'));
      expect(info.sizeBytes, 128);
      expect(info.formatValid, isTrue);
      expect(info.isReady, isTrue);
      expect(await File(info.path).exists(), isTrue);
    });

    test('rejects a renamed non-TFLite file', () async {
      expect(
        () => manager.importModel(
          fileName: 'not-a-model.tflite',
          bytes: Stream.value(List<int>.filled(128, 0)),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'does not replace a valid model when a new import is invalid',
      () async {
        final first = await manager.importModel(
          fileName: 'first.tflite',
          bytes: Stream.value(_validTfliteBytes()),
        );
        final originalBytes = await File(first.path).readAsBytes();

        await expectLater(
          manager.importModel(
            fileName: 'invalid.tflite',
            bytes: Stream.value(List<int>.filled(128, 0)),
          ),
          throwsA(isA<FormatException>()),
        );

        expect(await File(first.path).readAsBytes(), originalBytes);
      },
    );

    test('removes only models inside managed storage', () async {
      final imported = await manager.importModel(
        fileName: 'model.tflite',
        bytes: Stream.value(_validTfliteBytes()),
      );
      final external = File(path.join(tempDirectory.path, 'external.tflite'));
      await external.writeAsBytes(_validTfliteBytes());

      await manager.removeManagedModel(external.path);
      expect(await external.exists(), isTrue);

      await manager.removeManagedModel(imported.path);
      expect(await File(imported.path).exists(), isFalse);
    });
  });
}

List<int> _validTfliteBytes() {
  return <int>[0, 0, 0, 0, 0x54, 0x46, 0x4c, 0x33, ...List.filled(120, 0)];
}

class _ReadyCapabilityService implements DeviceCapabilityService {
  const _ReadyCapabilityService();

  @override
  Future<LocalModelCapabilityReport> inspect({String? modelPath}) async {
    return const LocalModelCapabilityReport(
      platform: 'android',
      processorCount: 8,
      supportsIsolate: true,
      modelAvailable: true,
      canRunLocal: true,
    );
  }
}
