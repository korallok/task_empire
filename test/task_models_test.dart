import 'package:flutter_test/flutter_test.dart';
import 'package:task_empire/features/tasks/domain/task_models.dart';

void main() {
  test('task model parses v2 fields and normal rewards', () {
    final task = EmpireTask.fromJson({
      'id': 'task-1',
      'user_id': 'user-1',
      'title': 'Подготовить макет',
      'description': 'Собрать главный экран',
      'category': 'work',
      'difficulty': 'normal',
      'scheduled_date': '2026-09-04',
      'deadline': '2026-09-04T13:00:00Z',
      'status': 'pending',
      'verification_mode': 'none',
      'created_at': '2026-09-03T10:00:00Z',
      'completed_at': null,
    });

    expect(task.category, TaskCategory.work);
    expect(task.difficulty, TaskDifficulty.normal);
    expect(task.difficulty.xpReward, 25);
    expect(task.difficulty.goldReward, 15);
    expect(task.scheduledDate, DateTime(2026, 9, 4));
    expect(task.isCompleted, isFalse);
  });

  test('legacy ranks collapse into the three v2 difficulties', () {
    expect(TaskDifficulty.fromDatabase('E'), TaskDifficulty.easy);
    expect(TaskDifficulty.fromDatabase('D'), TaskDifficulty.easy);
    expect(TaskDifficulty.fromDatabase('B'), TaskDifficulty.normal);
    expect(TaskDifficulty.fromDatabase('S'), TaskDifficulty.hard);
  });

  test('task rejects malformed nullable timestamps', () {
    expect(
      () => EmpireTask.fromJson({
        'id': 'task-1',
        'user_id': 'user-1',
        'title': 'Задача',
        'description': '',
        'category': 'personal',
        'difficulty': 'normal',
        'scheduled_date': '2026-09-04',
        'deadline': 123,
        'status': 'pending',
        'verification_mode': 'none',
        'created_at': '2026-09-03T10:00:00Z',
        'completed_at': null,
      }),
      throwsFormatException,
    );
  });

  test('completion result accepts integral JSON numbers', () {
    final result = TaskCompletionResult.fromJson({
      'task_id': 'task-1',
      'status': 'completed',
      'completed_at': '2026-09-04T12:00:00Z',
      'reward': {'xp_delta': 25.0, 'gold_delta': 15},
      'profile': {'xp': 125, 'gold': 40.0, 'level': 2},
    });

    expect(result.xpAwarded, 25);
    expect(result.totalGold, 40);
  });

  test('draft serializes a date without a timezone shift', () {
    final draft = TaskDraft(
      title: '  Тренировка  ',
      description: '  30 минут  ',
      category: TaskCategory.health,
      difficulty: TaskDifficulty.easy,
      scheduledDate: DateTime(2026, 9, 4, 23, 55),
      deadline: null,
      verificationMode: TaskVerificationMode.none,
    );

    expect(draft.toDatabaseJson(), containsPair('title', 'Тренировка'));
    expect(draft.toDatabaseJson(), containsPair('description', '30 минут'));
    expect(
      draft.toDatabaseJson(),
      containsPair('scheduled_date', '2026-09-04'),
    );
  });
}
