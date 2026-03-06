import 'package:flutter_test/flutter_test.dart';

import 'package:personal_assistant/main.dart';

void main() {
  testWidgets('renders MVP dashboard and navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PersonalAssistantApp());

    expect(find.text('Personal Assistant'), findsOneWidget);
    expect(
      find.text('Stay on track with medication and daily rhythm.'),
      findsOneWidget,
    );
    expect(find.text('Medication schedule'), findsNothing);

    await tester.tap(find.text('Medications'));
    await tester.pumpAndSettle();

    expect(find.text('Medication schedule'), findsOneWidget);
    expect(find.text('Amlodipine'), findsOneWidget);
  });
}
