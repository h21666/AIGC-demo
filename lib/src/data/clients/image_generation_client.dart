import '../../domain/entities/silicon_flow_image_request.dart';
import '../../domain/entities/silicon_flow_image_result.dart';

abstract interface class ImageGenerationClient {
  Future<SiliconFlowImageResult> generateImages({
    required String apiKey,
    required SiliconFlowImageRequest request,
  });
}
