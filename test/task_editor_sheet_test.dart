import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_empire/features/tasks/domain/task_models.dart';
import 'package:task_empire/features/tasks/presentation/task_editor_sheet.dart';

void main() {
  testWidgets('v2 task editor validates and returns a trimmed draft', (
    tester,
  ) async {
    TaskDraft? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('ru')],
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showModalBottomSheet<TaskDraft>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) =>
                      TaskEditorSheet(initialDate: DateTime(2026, 9, 5)),
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
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();
    expect(find.text('Введите название задачи'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      '  Подготовить презентацию  ',
    );
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(result?.title, 'Подготовить презентацию');
    expect(result?.category, TaskCategory.personal);
    expect(result?.difficulty, TaskDifficulty.normal);
    expect(result?.scheduledDate, DateTime(2026, 9, 5));
  });
}
