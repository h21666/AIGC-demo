import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

import '../clients/cloud_generation_exception.dart';
import '../../domain/enums/cloud_generation_failure_type.dart';

class GeneratedImageDownload {
  const GeneratedImageDownload({
    required this.file,
    required this.mimeType,
    required this.sizeBytes,
  });

  final File file;
  final String? mimeType;
  final int sizeBytes;
}

abstract interface class ImageDownloader {
  Future<GeneratedImageDownload> download({
    required Uri imageUrl,
    required Directory outputDirectory,
    required String fileName,
  });
}

class GeneratedImageDownloader implements ImageDownloader {
  GeneratedImageDownloader({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<GeneratedImageDownload> download({
    required Uri imageUrl,
    required Directory outputDirectory,
    required String fileName,
  }) async {
    try {
      await outputDirectory.create(recursive: true);
      final response = await _dio.get<List<int>>(
        imageUrl.toString(),
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const CloudGenerationException(
          type: CloudGenerationFailureType.invalidRequest,
          message: 'Downloaded image is empty.',
          retryable: false,
        );
      }
      final mimeType = response.headers.value(Headers.contentTypeHeader);
      final resolvedFileName = fileName.endsWith(_extensionFor(mimeType))
          ? fileName
          : '$fileName${_extensionFor(mimeType)}';
      final file = File(path.join(outputDirectory.path, resolvedFileName));
      await file.writeAsBytes(bytes, flush: true);
      return GeneratedImageDownload(
        file: file,
        mimeType: mimeType,
        sizeBytes: bytes.length,
      );
    } on DioException catch (error) {
      throw CloudGenerationException.fromDioException(error);
    }
  }

  String _extensionFor(String? mimeType) => switch (mimeType) {
    'image/jpeg' => '.jpg',
    'image/webp' => '.webp',
    _ => '.png',
  };
}
