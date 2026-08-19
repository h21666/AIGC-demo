import '../entities/local_tflite_request.dart';
import '../entities/local_tflite_result.dart';

abstract interface class LocalTfliteInterpreter {
  Future<LocalTfliteResult> infer(LocalTfliteRequest request);
}
