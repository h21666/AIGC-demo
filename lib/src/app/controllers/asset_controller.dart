import 'package:uuid/uuid.dart';

import '../../domain/entities/app_log.dart';
import '../../domain/entities/asset_export_result.dart';
import '../../domain/entities/generated_asset_preview.dart';
import '../../domain/enums/log_level.dart';
import '../app_runtime.dart';

class AssetController {
  AssetController(this.runtime);

  final AppRuntime runtime;
  final Uuid _uuid = const Uuid();

  Future<List<GeneratedAssetPreview>> loadAssets({int limit = 100}) {
    return runtime.assetLibrary.listPreviews(limit: limit);
  }

  Future<AssetExportResult> exportSelected(Iterable<String> assetIds) async {
    final ids = assetIds.toSet().toList(growable: false);
    final result = await runtime.assetLibrary.exportSelected(ids);
    await runtime.logs.append(
      AppLog(
        id: _uuid.v4(),
        level: result.failedCount == 0 ? LogLevel.info : LogLevel.warning,
        message: '素材导出完成',
        context: <String, Object?>{
          'selected': ids.length,
          'exported': result.exportedCount,
          'skipped': result.skippedCount,
          'failed': result.failedCount,
        },
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return result;
  }
}
