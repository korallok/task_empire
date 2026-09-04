import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:task_empire/features/calendar/bloc/calendar_bloc.dart';
import 'package:task_empire/features/calendar/data/task_item.dart';
import 'package:task_empire/features/calendar/data/task_repository.dart';

void main() {
  test('calendar loads and sorts deadline and timeless tasks', () async {
    final repository = _FakeTaskRepository([
      _task(
        id: 'timeless',
        title: 'Бессрочная',
        createdAt: DateTime(2026, 7, 27, 12),
      ),
      _task(
        id: 'later',
        title: 'Позже',
        createdAt: DateTime(2026, 7, 27, 10),
        deadline: DateTime(2026, 7, 29),
      ),
      _task(
        id: 'sooner',
        title: 'Раньше',
        createdAt: DateTime(2026, 7, 27, 11),
        deadline: DateTime(2026, 7, 28),
      ),
    ]);
    final bloc = CalendarBloc(repository: repository);
    addTearDown(bloc.close);

    bloc.add(const CalendarStarted());
    final state =
        await bloc.stream.firstWhere((state) => state is CalendarDisplay)
            as CalendarDisplay;

    expect(state.data.deadlineTasks.map((task) => task.id), [
      'sooner',
      'later',
    ]);
    expect(state.data.timelessTasks.single.id, 'timeless');
  });

  test('rapid duplicate completion invokes repository only once', () async {
    final task = _task(
      id: 'task-1',
      title: 'Подготовить отчёт',
      createdAt: DateTime(2026, 7, 27),
    );
    final repository = _FakeTaskRepository([task]);
    final bloc = CalendarBloc(repository: repository);
    addTearDown(bloc.close);

    bloc.add(const CalendarStarted());
    await bloc.stream.firstWhere((state) => state is CalendarDisplay);

    final completionGate = Completer<void>();
    repository.completionGate = completionGate;
    bloc.add(const CalendarTaskCompletionRequested('task-1'));
    await bloc.stream.firstWhere((state) => state is CalendarCompleting);

    bloc.add(const CalendarTaskCompletionRequested('task-1'));
    completionGate.complete();
    await bloc.stream.firstWhere(
      (state) =>
          state is CalendarDisplay &&
          state.data.timelessTasks.single.isCompleted,
    );
    await Future<void>.delayed(Duration.zero);

    expect(repository.completionCalls, 1);
  });
}

TaskItem _task({
  required String id,
  required String title,
  required DateTime createdAt,
  DateTime? deadline,
  bool isCompleted = false,
}) {
  return TaskItem(
    id: id,
    userId: 'user-1',
    title: title,
    difficulty: TaskDifficulty.e,
    hasDeadline: deadline != null,
    deadline: deadline,
    isCompleted: isCompleted,
    createdAt: createdAt,
    completedAt: isCompleted ? DateTime(2026, 7, 27, 14) : null,
  );
}

final class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository(List<TaskItem> tasks) : _tasks = List.of(tasks);

  List<TaskItem> _tasks;
  Completer<void>? completionGate;
  var completionCalls = 0;

  @override
  Future<void> addTask(NewTaskDraft draft) async {
    _tasks = [
      ..._tasks,
      _task(
        id: 'created-${_tasks.length}',
        title: draft.title,
        createdAt: DateTime(2026, 7, 27),
        deadline: draft.deadline,
      ),
    ];
  }

  @override
  Future<TaskCompletionResult> completeTask(String taskId) async {
    completionCalls += 1;
    await completionGate?.future;
    _tasks = [
      for (final task in _tasks)
        if (task.id == taskId)
          _task(
            id: task.id,
            title: task.title,
            createdAt: task.createdAt,
            deadline: task.deadline,
            isCompleted: true,
          )
        else
          task,
    ];
    return TaskCompletionResult(
      taskId: taskId,
      approvedDifficulty: TaskDifficulty.c,
      reason: 'Обычная сфокусированная задача.',
      goldAwarded: 40,
      totalGold: 140,
      dailyGoldEarned: 40,
      dailyGoldCap: 600,
      completedAt: DateTime(2026, 7, 27, 14),
    );
  }

  @override
  Future<List<TaskItem>> fetchTasks() async => List.unmodifiable(_tasks);
}
