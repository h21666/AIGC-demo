import 'package:dio/dio.dart';

import '../../domain/entities/silicon_flow_image_request.dart';
import '../../domain/entities/silicon_flow_image_result.dart';
import '../../domain/enums/cloud_generation_failure_type.dart';
import 'cloud_generation_exception.dart';
import 'image_generation_client.dart';

class SiliconFlowImageClient implements ImageGenerationClient {
  SiliconFlowImageClient({
    Dio? dio,
    String baseUrl = 'https://api.siliconflow.cn/v1',
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 20),
               receiveTimeout: const Duration(minutes: 2),
               sendTimeout: const Duration(seconds: 20),
             ),
           );

  final Dio _dio;

  @override
  Future<SiliconFlowImageResult> generateImages({
    required String apiKey,
    required SiliconFlowImageRequest request,
  }) async {
    try {
      final response = await _dio.post<Map<String, Object?>>(
        '/images/generations',
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );
      final body = response.data;
      if (body == null) {
        throw const CloudGenerationException(
          type: CloudGenerationFailureType.invalidRequest,
          message: 'SiliconFlow returned an empty response.',
          retryable: false,
        );
      }
      return _parseResult(body);
    } on DioException catch (error) {
      throw CloudGenerationException.fromDioException(error);
    }
  }

  SiliconFlowImageResult _parseResult(Map<String, Object?> body) {
    final rawImages = body['images'] ?? body['data'];
    if (rawImages is! List) {
      throw const CloudGenerationException(
        type: CloudGenerationFailureType.invalidRequest,
        message: 'SiliconFlow response does not contain image URLs.',
        retryable: false,
      );
    }
    final urls = rawImages
        .whereType<Map>()
        .map((image) => image['url'])
        .whereType<String>()
        .map(Uri.parse)
        .toList();
    if (urls.isEmpty) {
      throw const CloudGenerationException(
        type: CloudGenerationFailureType.invalidRequest,
        message: 'SiliconFlow response contains no usable image URL.',
        retryable: false,
      );
    }
    return SiliconFlowImageResult(
      imageUrls: urls,
      seed: _readInt(body['seed']),
      timings: _readMap(body['timings']),
      raw: body,
    );
  }

  int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  Map<String, Object?> _readMap(Object? value) {
    if (value is Map) return Map<String, Object?>.from(value);
    return const {};
  }
}
