import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

import '../../domain/entities/generated_asset.dart';
import '../../domain/entities/generated_asset_preview.dart';
import '../../domain/repositories/asset_repository.dart';

class AssetThumbnailService {
  AssetThumbnailService({
    required this.assetRepository,
    required this.thumbnailDirectory,
    this.maxThumbnailSide = 320,
  });

  final AssetRepository assetRepository;
  final Directory thumbnailDirectory;
  final int maxThumbnailSide;

  Future<GeneratedAsset> ensureThumbnail(GeneratedAsset asset) async {
    final existingThumbnailPath = asset.thumbnailPath;
    if (existingThumbnailPath != null &&
        await File(existingThumbnailPath).exists()) {
      return asset;
    }

    final source = File(asset.filePath);
    if (!await source.exists()) {
      throw FileSystemException(
        'Generated asset file not found',
        asset.filePath,
      );
    }
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw FormatException('Unable to decode image: ${asset.filePath}');
    }

    final thumbnail = img.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? maxThumbnailSide : null,
      height: decoded.height > decoded.width ? maxThumbnailSide : null,
      interpolation: img.Interpolation.average,
    );
    await thumbnailDirectory.create(recursive: true);
    final thumbnailPath = path.join(thumbnailDirectory.path, '${asset.id}.jpg');
    final thumbnailFile = File(thumbnailPath);
    await thumbnailFile.writeAsBytes(img.encodeJpg(thumbnail, quality: 82));

    final updated = _copyAsset(
      asset,
      thumbnailPath: thumbnailPath,
      width: decoded.width,
      height: decoded.height,
      sizeBytes: bytes.length,
    );
    await assetRepository.save(updated);
    return updated;
  }

  Future<List<GeneratedAsset>> ensureThumbnails(
    List<GeneratedAsset> assets,
  ) async {
    final updated = <GeneratedAsset>[];
    for (final asset in assets) {
      updated.add(await ensureThumbnail(asset));
    }
    return updated;
  }

  GeneratedAssetPreview previewFor(GeneratedAsset asset) {
    final thumbnailPath = asset.thumbnailPath;
    return GeneratedAssetPreview(
      id: asset.id,
      displayPath: thumbnailPath ?? asset.filePath,
      width: asset.width,
      height: asset.height,
      sizeBytes: asset.sizeBytes,
      usesThumbnail: thumbnailPath != null,
    );
  }

  GeneratedAsset _copyAsset(
    GeneratedAsset asset, {
    String? thumbnailPath,
    int? width,
    int? height,
    int? sizeBytes,
  }) {
    return GeneratedAsset(
      id: asset.id,
      source: asset.source,
      filePath: asset.filePath,
      taskId: asset.taskId,
      jobId: asset.jobId,
      thumbnailPath: thumbnailPath ?? asset.thumbnailPath,
      width: width ?? asset.width,
      height: height ?? asset.height,
      sizeBytes: sizeBytes ?? asset.sizeBytes,
      mimeType: asset.mimeType,
      seed: asset.seed,
      promptSnapshot: asset.promptSnapshot,
      metadata: asset.metadata,
      createdAt: asset.createdAt,
      exportedAt: asset.exportedAt,
    );
  }
}
