import 'dart:io';

import 'package:path/path.dart' as path;

import '../../domain/entities/local_model_info.dart';
import '../../domain/repositories/device_capability_service.dart';

class LocalModelManager {
  const LocalModelManager({
    required this.modelDirectory,
    required this.capabilityService,
  });

  final Directory modelDirectory;
  final DeviceCapabilityService capabilityService;

  Future<LocalModelInfo> importModel({
    required String fileName,
    required Stream<List<int>> bytes,
  }) async {
    final safeName = path.basename(fileName.trim());
    if (!safeName.toLowerCase().endsWith('.tflite')) {
      throw const FormatException('请选择扩展名为 .tflite 的模型文件。');
    }

    await modelDirectory.create(recursive: true);
    final destination = File(path.join(modelDirectory.path, 'local_model.tflite'));
    final temporary = File('${destination.path}.importing');
    if (await temporary.exists()) await temporary.delete();

    try {
      final sink = temporary.openWrite();
      await sink.addStream(bytes);
      await sink.close();
      final imported = await inspect(temporary.path, displayName: safeName);
      if (!imported.formatValid) {
        throw const FormatException('所选文件不是有效的 TFLite 模型。');
      }
      if (await destination.exists()) await destination.delete();
      await temporary.rename(destination.path);
    } on Object {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }

    return inspect(destination.path, displayName: safeName);
  }

  Future<LocalModelInfo> inspect(
    String modelPath, {
    String? displayName,
  }) async {
    final file = File(modelPath);
    final exists = await file.exists();
    final sizeBytes = exists ? await file.length() : 0;
    final fileName = (displayName == null || displayName.trim().isEmpty)
        ? path.basename(modelPath)
        : path.basename(displayName.trim());
    final headerValid = exists && await _hasTfliteHeader(file);
    final capability = await capabilityService.inspect(modelPath: modelPath);
    return LocalModelInfo(
      path: modelPath,
      fileName: fileName,
      sizeBytes: sizeBytes,
      exists: exists,
      hasTfliteExtension: fileName.toLowerCase().endsWith('.tflite'),
      hasTfliteHeader: headerValid,
      capability: capability,
    );
  }

  Future<void> removeManagedModel(String? modelPath) async {
    if (modelPath == null || modelPath.trim().isEmpty) return;
    final file = File(modelPath);
    final managedRoot = path.canonicalize(modelDirectory.absolute.path);
    final candidate = path.canonicalize(file.absolute.path);
    if (path.isWithin(managedRoot, candidate) && await file.exists()) {
      await file.delete();
    }
  }

  Future<bool> _hasTfliteHeader(File file) async {
    if (await file.length() < 8) return false;
    final input = await file.open();
    try {
      await input.setPosition(4);
      final identifier = await input.read(4);
      return identifier.length == 4 &&
          identifier[0] == 0x54 &&
          identifier[1] == 0x46 &&
          identifier[2] == 0x4c &&
          identifier[3] == 0x33;
    } finally {
      await input.close();
    }
  }
}
