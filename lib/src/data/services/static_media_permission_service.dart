import '../../domain/enums/media_permission_status.dart';
import '../../domain/repositories/media_permission_service.dart';

class StaticMediaPermissionService implements MediaPermissionService {
  const StaticMediaPermissionService(this.status);

  final MediaPermissionStatus status;

  @override
  Future<MediaPermissionStatus> requestExportPermission() async => status;
}
