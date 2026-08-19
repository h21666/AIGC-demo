import '../enums/media_permission_status.dart';

abstract interface class MediaPermissionService {
  Future<MediaPermissionStatus> requestExportPermission();
}
