import 'dart:io';

import '../../domain/entities/asset_export_result.dart';
import '../../domain/entities/generated_asset.dart';
import '../../domain/entities/generated_asset_preview.dart';
import '../../domain/enums/media_permission_status.dart';
import '../../domain/repositories/album_exporter.dart';
import '../../domain/repositories/asset_repository.dart';
import '../../domain/repositories/media_permission_service.dart';
import 'asset_thumbnail_service.dart';

class AssetLibraryService {
  const AssetLibraryService({
    required this.assetRepository,
    required this.thumbnailService,
    required this.permissionService,
    required this.albumExporter,
  });

  final AssetRepository assetRepository;
  final AssetThumbnailService thumbnailService;
  final MediaPermissionService permissionService;
  final AlbumExporter albumExporter;

  Future<List<GeneratedAssetPreview>> listPreviews({
    String? taskId,
    DateTime? createdAfter,
    DateTime? createdBefore,
    int? limit,
  }) async {
    final assets = await assetRepository.list(
      taskId: taskId,
      createdAfter: createdAfter,
      createdBefore: createdBefore,
      limit: limit,
    );
    final prepared = await thumbnailService.ensureThumbnails(assets);
    return prepared.map(thumbnailService.previewFor).toList();
  }

  Future<GeneratedAssetPreview?> preview(String id) async {
    final asset = await assetRepository.getById(id);
    if (asset == null) return null;
    final prepared = await thumbnailService.ensureThumbnail(asset);
    return thumbnailService.previewFor(prepared);
  }

  Future<AssetExportResult> exportSelected(List<String> assetIds) async {
    final uniqueIds = assetIds.toSet().toList();
    if (uniqueIds.isEmpty) {
      return const AssetExportResult(
        exportedCount: 0,
        skippedCount: 0,
        failedCount: 0,
      );
    }

    final permission = await permissionService.requestExportPermission();
    if (permission != MediaPermissionStatus.granted) {
      return AssetExportResult(
        exportedCount: 0,
        skippedCount: 0,
        failedCount: uniqueIds.length,
        failures: {
          for (final id in uniqueIds) id: 'Media export permission denied',
        },
      );
    }

    final assets = await assetRepository.listByIds(uniqueIds);
    final foundIds = assets.map((asset) => asset.id).toSet();
    final skippedCount = uniqueIds.where((id) => !foundIds.contains(id)).length;
    final failures = <String, String>{};
    final exportedPaths = <String>[];
    final exportedAssets = <GeneratedAsset>[];

    for (final asset in assets) {
      final file = File(asset.filePath);
      if (!await file.exists()) {
        failures[asset.id] = 'Asset file not found';
        continue;
      }
      try {
        final exportedPath = await albumExporter.exportImage(file);
        exportedPaths.add(exportedPath);
        exportedAssets.add(
          _copyAsset(asset, exportedAt: DateTime.now().toUtc()),
        );
      } on Object catch (error) {
        failures[asset.id] = error.toString();
      }
    }

    await assetRepository.saveAll(exportedAssets);
    return AssetExportResult(
      exportedCount: exportedPaths.length,
      skippedCount: skippedCount,
      failedCount: failures.length,
      exportedPaths: exportedPaths,
      failures: failures,
    );
  }

  GeneratedAsset _copyAsset(GeneratedAsset asset, {DateTime? exportedAt}) {
    return GeneratedAsset(
      id: asset.id,
      source: asset.source,
      filePath: asset.filePath,
      taskId: asset.taskId,
      jobId: asset.jobId,
      thumbnailPath: asset.thumbnailPath,
      width: asset.width,
      height: asset.height,
      sizeBytes: asset.sizeBytes,
      mimeType: asset.mimeType,
      seed: asset.seed,
      promptSnapshot: asset.promptSnapshot,
      metadata: asset.metadata,
      createdAt: asset.createdAt,
      exportedAt: exportedAt ?? asset.exportedAt,
    );
  }
}
