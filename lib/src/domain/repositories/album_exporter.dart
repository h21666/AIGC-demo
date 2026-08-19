import 'dart:io';

abstract interface class AlbumExporter {
  Future<String> exportImage(File imageFile);
}
