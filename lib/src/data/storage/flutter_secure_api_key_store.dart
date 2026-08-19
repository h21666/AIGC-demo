import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/repositories/secure_api_key_store.dart';

class FlutterSecureApiKeyStore implements SecureApiKeyStore {
  const FlutterSecureApiKeyStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _apiKeyKey = 'silicon_flow_api_key';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readApiKey() async {
    final value = await _storage.read(key: _apiKeyKey);
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  @override
  Future<void> writeApiKey(String apiKey) async {
    final normalized = apiKey.trim();
    if (normalized.isEmpty) {
      await deleteApiKey();
      return;
    }
    await _storage.write(key: _apiKeyKey, value: normalized);
  }

  @override
  Future<void> deleteApiKey() {
    return _storage.delete(key: _apiKeyKey);
  }
}
