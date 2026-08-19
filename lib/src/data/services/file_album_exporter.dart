import 'dart:io';

import 'package:path/path.dart' as path;

import '../../domain/repositories/album_exporter.dart';

class FileAlbumExporter implements AlbumExporter {
  const FileAlbumExporter(this.exportDirectory);

  final Directory exportDirectory;

  @override
  Future<String> exportImage(File imageFile) async {
    if (!await imageFile.exists()) {
      throw FileSystemException('Image file not found', imageFile.path);
    }
    await exportDirectory.create(recursive: true);
    final destination = File(
      path.join(exportDirectory.path, path.basename(imageFile.path)),
    );
    await imageFile.copy(destination.path);
    return destination.path;
  }
}
