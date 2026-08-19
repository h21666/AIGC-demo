import '../entities/local_model_capability_report.dart';

abstract interface class DeviceCapabilityService {
  Future<LocalModelCapabilityReport> inspect({String? modelPath});
}
