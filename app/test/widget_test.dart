import 'package:flutter_test/flutter_test.dart';

import 'package:personal_assistant/assistant_models.dart';
import 'package:personal_assistant/main.dart';

void main() {
  testWidgets('renders MVP dashboard and navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      PersonalAssistantApp(
        workspaceFuture: Future.value(AssistantWorkspaceData.sample()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personal Assistant'), findsOneWidget);
    expect(
      find.text('Stay on track with supplements and daily rhythm.'),
      findsOneWidget,
    );
    expect(find.text('Supplement schedule'), findsNothing);

    await tester.tap(find.text('Supplements'));
    await tester.pumpAndSettle();

    expect(find.text('Supplement schedule'), findsOneWidget);
    expect(
      find.text('21st Century Calcium Magnesium Zinc + D3'),
      findsOneWidget,
    );

    await tester.tap(find.text('Editor'));
    await tester.pumpAndSettle();

    expect(find.text('Data editor'), findsOneWidget);
    expect(find.text('Save All'), findsOneWidget);
  });
}
