import 'package:uuid/uuid.dart';

import '../../data/services/application_settings_service.dart';
import '../../domain/entities/app_log.dart';
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

  Future<void> _appendLog(String message) {
    return runtime.logs.append(
      AppLog(
        id: _uuid.v4(),
        level: LogLevel.info,
        message: message,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }
}
