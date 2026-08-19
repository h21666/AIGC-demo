import '../../domain/repositories/secure_api_key_store.dart';

class InMemorySecureApiKeyStore implements SecureApiKeyStore {
  String? _apiKey;

  @override
  Future<String?> readApiKey() async => _apiKey;

  @override
  Future<void> writeApiKey(String apiKey) async {
    _apiKey = apiKey;
  }

  @override
  Future<void> deleteApiKey() async {
    _apiKey = null;
  }
}
