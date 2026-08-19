enum ImageAssetSource {
  cloud('cloud'),
  local('local'),
  imported('imported');

  const ImageAssetSource(this.storageKey);

  final String storageKey;
}
