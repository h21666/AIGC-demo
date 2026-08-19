import '../entities/local_model_capability_report.dart';
import '../entities/local_tflite_result.dart';
import '../entities/silicon_flow_image_request.dart';
import '../enums/local_generation_route.dart';

class HybridGenerationPlan {
  const HybridGenerationPlan.local({
    required this.capability,
    required this.localResult,
    required this.cloudRequest,
  }) : route = LocalGenerationRoute.local,
       fallbackReason = null;

  const HybridGenerationPlan.cloud({
    required this.capability,
    required this.cloudRequest,
    this.fallbackReason,
    this.localResult,
  }) : route = LocalGenerationRoute.cloud;

  final LocalGenerationRoute route;
  final LocalModelCapabilityReport capability;
  final LocalTfliteResult? localResult;
  final SiliconFlowImageRequest cloudRequest;
  final String? fallbackReason;

  bool get isCloudFallback => route == LocalGenerationRoute.cloud;
}
