import '../entities/generated_asset.dart';

abstract interface class AssetRepository {
  Future<GeneratedAsset?> getById(String id);

  Future<List<GeneratedAsset>> list({
    String? taskId,
    DateTime? createdAfter,
    DateTime? createdBefore,
  });

  Future<void> save(GeneratedAsset asset);

  Future<void> delete(String id);

  Future<void> markExported(String id, DateTime exportedAt);
}
