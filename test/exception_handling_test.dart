import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aigc_studio/src/data/clients/cloud_generation_exception.dart';
import 'package:aigc_studio/src/domain/enums/cloud_generation_failure_type.dart';
import 'package:aigc_studio/src/domain/exceptions/local_tflite_exception.dart';

void main() {
  group('Exception handling', () {
    test('classifies cloud generation network errors', () {
      final exception = CloudGenerationException.fromDioException(
        DioException(
          requestOptions: RequestOptions(path: '/images/generations'),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(exception.type, CloudGenerationFailureType.noNetwork);
      expect(exception.retryable, isTrue);
    });

    test('local tflite exception keeps the fallback flag', () {
      const exception = LocalTfliteException('Local model failed.');
      expect(exception.message, 'Local model failed.');
      expect(exception.fallbackToCloud, isTrue);
      expect(exception.toString(), contains('Local model failed.'));
    });
  });
}
