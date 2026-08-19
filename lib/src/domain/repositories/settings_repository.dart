import '../entities/app_settings.dart';

abstract interface class SettingsRepository {
  Future<AppSettings?> get(String key);

  Future<void> set(AppSettings setting);

  Future<void> remove(String key);

  Future<void> clearCache();
}
