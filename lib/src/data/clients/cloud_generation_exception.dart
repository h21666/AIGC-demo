import 'dart:io';

import 'package:dio/dio.dart';

import '../../domain/enums/cloud_generation_failure_type.dart';

class CloudGenerationException implements Exception {
  const CloudGenerationException({
    required this.type,
    required this.message,
    required this.retryable,
    this.statusCode,
  });

  final CloudGenerationFailureType type;
  final String message;
  final bool retryable;
  final int? statusCode;

  factory CloudGenerationException.fromDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401) {
      return const CloudGenerationException(
        type: CloudGenerationFailureType.authentication,
        message: 'SiliconFlow API key is invalid or missing.',
        retryable: false,
        statusCode: 401,
      );
    }
    if (statusCode == 429) {
      return const CloudGenerationException(
        type: CloudGenerationFailureType.rateLimited,
        message: 'SiliconFlow rate limit reached.',
        retryable: true,
        statusCode: 429,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return CloudGenerationException(
        type: CloudGenerationFailureType.server,
        message: 'SiliconFlow server error: $statusCode.',
        retryable: true,
        statusCode: statusCode,
      );
    }
    if (statusCode != null && statusCode >= 400) {
      return CloudGenerationException(
        type: CloudGenerationFailureType.invalidRequest,
        message: 'SiliconFlow rejected the request: $statusCode.',
        retryable: false,
        statusCode: statusCode,
      );
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const CloudGenerationException(
          type: CloudGenerationFailureType.timeout,
          message: 'SiliconFlow request timed out.',
          retryable: true,
        );
      case DioExceptionType.connectionError:
        return const CloudGenerationException(
          type: CloudGenerationFailureType.noNetwork,
          message: 'Network is unavailable.',
          retryable: true,
        );
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return const CloudGenerationException(
            type: CloudGenerationFailureType.noNetwork,
            message: 'Network is unavailable.',
            retryable: true,
          );
        }
        return CloudGenerationException(
          type: CloudGenerationFailureType.unknown,
          message: error.message ?? 'Unknown generation error.',
          retryable: false,
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
        return CloudGenerationException(
          type: CloudGenerationFailureType.unknown,
          message: error.message ?? 'Generation request failed.',
          retryable: false,
          statusCode: statusCode,
        );
    }
  }

  @override
  String toString() => 'CloudGenerationException($type, $message)';
}
