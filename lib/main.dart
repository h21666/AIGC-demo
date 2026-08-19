import 'package:flutter/material.dart';

import 'src/app/aigc_studio_app.dart';
import 'src/app/app_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = await createAppRuntime();
  runApp(AigcStudioApp(runtime: runtime));
}
