import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aigc_studio/src/app/aigc_studio_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots on the skeleton screen', (tester) async {
    await tester.pumpWidget(const AigcStudioApp());
    await tester.pumpAndSettle();

    expect(find.text('Project skeleton ready'), findsOneWidget);
  });
}
