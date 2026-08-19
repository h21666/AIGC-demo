import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/secure_api_key_store.dart';
import '../../domain/repositories/settings_repository.dart';

class AppSettingsService {
  const AppSettingsService({
    required this.settingsRepository,
    required this.apiKeyStore,
  });

  final SettingsRepository settingsRepository;
  final SecureApiKeyStore apiKeyStore;

  Future<String?> readApiKey() => apiKeyStore.readApiKey();

  Future<void> saveApiKey(String? apiKey) async {
    final normalized = apiKey?.trim() ?? '';
    if (normalized.isEmpty) {
      await apiKeyStore.deleteApiKey();
      return;
    }
    await apiKeyStore.writeApiKey(normalized);
  }

  Future<void> clearApiKey() => apiKeyStore.deleteApiKey();

  Future<AppSettings?> readSetting(String key) => settingsRepository.get(key);

  Future<void> saveSetting(String key, String value) {
    return settingsRepository.set(
      AppSettings(key: key, value: value, updatedAt: DateTime.now().toUtc()),
    );
  }

  Future<void> deleteSetting(String key) => settingsRepository.remove(key);

  Future<void> clearCache() => settingsRepository.clearCache();
}
