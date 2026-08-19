enum GeneratedAssetSource {
  cloud('cloud'),
  local('local'),
  imported('imported');

  const GeneratedAssetSource(this.storageKey);

  final String storageKey;
}
