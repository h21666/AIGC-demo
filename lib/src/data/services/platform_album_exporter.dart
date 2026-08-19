import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/repositories/album_exporter.dart';

class PlatformAlbumExporter implements AlbumExporter {
  const PlatformAlbumExporter();

  static const MethodChannel _channel = MethodChannel('aigc_studio/media');

  @override
  Future<String> exportImage(File imageFile) async {
    if (!await imageFile.exists()) {
      throw FileSystemException('Image file not found', imageFile.path);
    }

    final uri = await _channel.invokeMethod<String>(
      'saveImageToGallery',
      <String, Object?>{'path': imageFile.path},
    );
    if (uri == null || uri.isEmpty) {
      throw StateError('Gallery export returned an empty path');
    }
    return uri;
  }
}
