import '../enums/image_asset_source.dart';

class ImageAsset {
  const ImageAsset({
    required this.id,
    required this.source,
    required this.filePath,
    required this.createdAt,
    this.taskId,
    this.jobId,
    this.thumbnailPath,
    this.width,
    this.height,
    this.sizeBytes,
    this.mimeType,
    this.seed,
    this.promptSnapshot,
    this.metadata = const {},
    this.exportedAt,
  });

  final String id;
  final ImageAssetSource source;
  final String filePath;
  final String? taskId;
  final String? jobId;
  final String? thumbnailPath;
  final int? width;
  final int? height;
  final int? sizeBytes;
  final String? mimeType;
  final String? seed;
  final String? promptSnapshot;
  final Map<String, Object?> metadata;
  final DateTime createdAt;
  final DateTime? exportedAt;
}
