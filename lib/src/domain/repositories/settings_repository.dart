import '../entities/app_setting.dart';

abstract interface class SettingsRepository {
  Future<AppSetting?> get(String key);

  Future<void> set(AppSetting setting);

  Future<void> remove(String key);

  Future<void> clearCache();
}
