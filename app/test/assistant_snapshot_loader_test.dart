import 'package:flutter_test/flutter_test.dart';

import 'package:personal_assistant/assistant_snapshot_loader.dart';

void main() {
  test('loads the recovered root data files', () async {
    final snapshot = await loadAssistantSnapshot();

    expect(snapshot.nextDoseTime, '07:30');
    expect(
      snapshot.doses.any(
        (dose) => dose.name == '21st Century Calcium Magnesium Zinc + D3',
      ),
      isTrue,
    );
    expect(
      snapshot.routines.any(
        (task) => task.title == 'Dinner and evening support',
      ),
      isTrue,
    );
  });
}
