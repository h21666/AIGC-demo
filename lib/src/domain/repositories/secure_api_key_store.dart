abstract interface class SecureApiKeyStore {
  Future<String?> readApiKey();

  Future<void> writeApiKey(String apiKey);

  Future<void> deleteApiKey();
}
