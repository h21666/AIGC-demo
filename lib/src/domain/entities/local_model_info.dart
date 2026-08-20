import 'local_model_capability_report.dart';

class LocalModelInfo {
  const LocalModelInfo({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.exists,
    required this.hasTfliteExtension,
    required this.hasTfliteHeader,
    required this.capability,
  });

  final String path;
  final String fileName;
  final int sizeBytes;
  final bool exists;
  final bool hasTfliteExtension;
  final bool hasTfliteHeader;
  final LocalModelCapabilityReport capability;

  bool get formatValid =>
      exists && sizeBytes >= 128 && hasTfliteExtension && hasTfliteHeader;

  bool get isReady => formatValid && capability.canRunLocal;
}
