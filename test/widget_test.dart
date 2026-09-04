import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_empire/features/calendar/data/task_item.dart';
import 'package:task_empire/features/calendar/presentation/add_task_sheet.dart';

void main() {
  testWidgets('add task sheet validates and returns a trimmed draft', (
    tester,
  ) async {
    NewTaskDraft? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showModalBottomSheet<NewTaskDraft>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const AddTaskSheet(),
                );
              },
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    final submitButton = find.byKey(const ValueKey('submit-task'));
    await tester.tap(submitButton);
    await tester.pump();
    expect(find.text('Введите название задачи'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField),
      '  Подготовить презентацию  ',
    );
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(result?.title, 'Подготовить презентацию');
    expect(result?.deadline, isNull);
  });
}
