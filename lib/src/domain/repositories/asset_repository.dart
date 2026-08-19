import '../entities/image_asset.dart';

abstract interface class AssetRepository {
  Future<ImageAsset?> getById(String id);

  Future<List<ImageAsset>> list({
    String? taskId,
    DateTime? createdAfter,
    DateTime? createdBefore,
  });

  Future<void> save(ImageAsset asset);

  Future<void> delete(String id);

  Future<void> markExported(String id, DateTime exportedAt);
}
