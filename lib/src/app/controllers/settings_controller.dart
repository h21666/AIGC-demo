import 'package:file_selector/file_selector.dart';
import 'package:uuid/uuid.dart';

import '../../data/services/application_settings_service.dart';
import '../../domain/entities/app_log.dart';
import '../../domain/entities/local_model_info.dart';
import '../../domain/enums/log_level.dart';
import '../app_runtime.dart';

class SettingsController {
  SettingsController(this.runtime)
    : service = AppSettingsService(
        settingsRepository: runtime.settings,
        apiKeyStore: runtime.apiKeyStore,
      );

  final AppRuntime runtime;
  final AppSettingsService service;
  final Uuid _uuid = const Uuid();
  static const localModelPathKey = 'local_model_path';
  static const localModelNameKey = 'local_model_name';

  Future<String?> loadApiKey() => service.readApiKey();

  Future<bool> saveApiKey(String value) async {
    final hasApiKey = value.trim().isNotEmpty;
    await service.saveApiKey(value);
    await _appendLog(hasApiKey ? 'API Key 已保存' : 'API Key 已清除');
    return hasApiKey;
  }

  Future<void> clearApiKey() async {
    await service.clearApiKey();
    await _appendLog('API Key 已清除');
  }

  Future<String?> loadLocalModelPath() async {
    final setting = await service.readSetting(localModelPathKey);
    return setting?.value;
  }

  Future<LocalModelInfo?> loadLocalModelInfo() async {
    final modelPath = await loadLocalModelPath();
    if (modelPath == null || modelPath.trim().isEmpty) return null;
    final savedName = (await service.readSetting(localModelNameKey))?.value;
    return runtime.localModels.inspect(modelPath, displayName: savedName);
  }

  Future<LocalModelInfo?> pickAndImportLocalModel() async {
    const typeGroup = XTypeGroup(
      label: 'TFLite model',
      extensions: <String>['tflite'],
    );
    final picked = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (picked == null) return null;

    final imported = await runtime.localModels.importModel(
      fileName: picked.name,
      bytes: picked.openRead(),
    );
    await service.saveSetting(localModelPathKey, imported.path);
    await service.saveSetting(localModelNameKey, imported.fileName);
    await _appendLog(
      '本地 TFLite 模型已导入',
      context: {
        'fileName': imported.fileName,
        'sizeBytes': imported.sizeBytes,
        'deviceReady': imported.capability.canRunLocal,
      },
    );
    return imported;
  }

  Future<void> removeLocalModel() async {
    final modelPath = await loadLocalModelPath();
    await runtime.localModels.removeManagedModel(modelPath);
    await service.deleteSetting(localModelPathKey);
    await service.deleteSetting(localModelNameKey);
    await _appendLog('本地 TFLite 模型已移除');
  }

  Future<bool> saveLocalModelPath(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      await service.deleteSetting(localModelPathKey);
      await _appendLog('本地 TFLite 模型路径已清除');
      return false;
    }
    await service.saveSetting(localModelPathKey, normalized);
    await _appendLog('本地 TFLite 模型路径已保存');
    return true;
  }

  Future<void> clearCache() async {
    await service.clearCache();
    await _appendLog('应用缓存已清理');
  }

  Future<void> _appendLog(
    String message, {
    Map<String, Object?> context = const {},
  }) {
    return runtime.logs.append(
      AppLog(
        id: _uuid.v4(),
        level: LogLevel.info,
        message: message,
        context: context,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }
}
