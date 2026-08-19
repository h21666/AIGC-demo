import 'package:flutter_test/flutter_test.dart';

import 'package:aigc_studio/src/app/aigc_studio_app.dart';

void main() {
  testWidgets('shows project skeleton placeholder', (tester) async {
    await tester.pumpWidget(const AigcStudioApp());

    expect(find.text('AIGC Studio'), findsOneWidget);
    expect(find.text('Project skeleton ready'), findsOneWidget);
  });
}
