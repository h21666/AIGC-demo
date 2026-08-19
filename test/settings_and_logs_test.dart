import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:aigc_studio/src/core/database/app_database.dart';
import 'package:aigc_studio/src/data/repositories/sqlite_log_repository.dart';
import 'package:aigc_studio/src/data/repositories/sqlite_settings_repository.dart';
import 'package:aigc_studio/src/data/services/application_settings_service.dart';
import 'package:aigc_studio/src/data/storage/in_memory_secure_api_key_store.dart';
import 'package:aigc_studio/src/domain/entities/app_log.dart';
import 'package:aigc_studio/src/domain/entities/app_settings.dart';
import 'package:aigc_studio/src/domain/enums/log_level.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Settings and logs', () {
    late Directory tempDir;
    late Directory cacheDir;
    late AppDatabase database;
    late SqliteSettingsRepository settingsRepository;
    late SqliteLogRepository logRepository;
    late AppSettingsService settingsService;
    late InMemorySecureApiKeyStore apiKeyStore;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('aigc_settings_test_');
      cacheDir = Directory(path.join(tempDir.path, 'cache'));
      await cacheDir.create(recursive: true);
      database = AppDatabase(databasePath: path.join(tempDir.path, 'test.db'));
      settingsRepository = SqliteSettingsRepository(
        database,
        cacheDirectories: [cacheDir],
      );
      logRepository = SqliteLogRepository(database);
      apiKeyStore = InMemorySecureApiKeyStore();
      settingsService = AppSettingsService(
        settingsRepository: settingsRepository,
        apiKeyStore: apiKeyStore,
      );
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('stores api key through application settings service', () async {
      await settingsService.saveApiKey('  secret-key  ');
      expect(await settingsService.readApiKey(), 'secret-key');

      await settingsService.clearApiKey();
      expect(await settingsService.readApiKey(), isNull);
    });

    test('persists app settings and clears cache directories', () async {
      await settingsRepository.set(
        AppSettings(
          key: 'theme',
          value: 'dark',
          updatedAt: DateTime.utc(2026, 8, 19, 12),
        ),
      );

      final setting = await settingsRepository.get('theme');
      expect(setting, isNotNull);
      expect(setting!.value, 'dark');

      final cacheFile = File(path.join(cacheDir.path, 'thumb.jpg'));
      await cacheFile.writeAsString('cached');
      expect(await cacheFile.exists(), isTrue);

      await settingsService.clearCache();
      expect(await cacheFile.exists(), isFalse);
    });

    test('appends, filters, exports, and clears logs', () async {
      await logRepository.append(
        AppLog(
          id: 'log-1',
          level: LogLevel.debug,
          message: 'debug message',
          context: const {'source': 'test'},
          createdAt: DateTime.utc(2026, 8, 19, 12),
        ),
      );
      await logRepository.append(
        AppLog(
          id: 'log-2',
          level: LogLevel.warning,
          message: 'warning message',
          createdAt: DateTime.utc(2026, 8, 19, 13),
        ),
      );
      await logRepository.append(
        AppLog(
          id: 'log-3',
          level: LogLevel.error,
          message: 'error message',
          createdAt: DateTime.utc(2026, 8, 19, 14),
        ),
      );

      final filtered = await logRepository.list(minLevel: LogLevel.warning);
      expect(filtered.map((log) => log.id), ['log-3', 'log-2']);

      final exported =
          jsonDecode(await logRepository.export()) as Map<String, Object?>;
      expect(exported['schemaVersion'], 1);
      expect((exported['logs'] as List).length, 3);

      await logRepository.clear();
      expect(await logRepository.list(), isEmpty);
    });
  });
}
