import 'package:flutter/services.dart';

import '../../domain/enums/media_permission_status.dart';
import '../../domain/repositories/media_permission_service.dart';

class PlatformMediaPermissionService implements MediaPermissionService {
  const PlatformMediaPermissionService();

  static const MethodChannel _channel = MethodChannel('aigc_studio/media');

  @override
  Future<MediaPermissionStatus> requestExportPermission() async {
    final status = await _channel.invokeMethod<String>(
      'requestGalleryExportPermission',
    );
    return switch (status) {
      'granted' => MediaPermissionStatus.granted,
      'permanently_denied' => MediaPermissionStatus.permanentlyDenied,
      _ => MediaPermissionStatus.denied,
    };
  }
}
