import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:task_empire/features/tasks/bloc/tasks_bloc.dart';
import 'package:task_empire/features/tasks/data/task_repository.dart';
import 'package:task_empire/features/tasks/domain/task_models.dart';

void main() {
  test('snapshot filters by scheduled day and sorts completed last', () {
    final day = DateTime(2026, 9, 4);
    final snapshot = TasksSnapshot(
      selectedDate: day,
      tasks: [
        _task(id: 'completed', day: day, completed: true),
        _task(id: 'tomorrow', day: DateTime(2026, 9, 5)),
        _task(id: 'active', day: day),
      ],
    );

    expect(snapshot.selectedTasks.map((task) => task.id), [
      'active',
      'completed',
    ]);
    expect(snapshot.completedForDay(day), 1);
    expect(snapshot.progressForDay(day), 0.5);
  });

  test('create, edit and delete flow uses repository operations', () async {
    final repository = _FakeTaskRepository([]);
    final bloc = TasksBloc(repository: repository);
    addTearDown(bloc.close);
    bloc.add(const TasksStarted());
    await bloc.stream.firstWhere((state) => state is TasksDisplay);

    final draft = _draft(title: 'Новая задача');
    bloc.add(TasksCreateRequested(initialDate: draft.scheduledDate));
    await bloc.stream.firstWhere((state) => state is TasksEditing);
    bloc.add(TasksSaved(draft));
    final afterCreate =
        await bloc.stream.firstWhere(
              (state) => state is TasksDisplay && state.data.tasks.length == 1,
            )
            as TasksDisplay;
    expect(repository.addCalls, 1);

    final created = afterCreate.data.tasks.single;
    bloc.add(TasksEditRequested(created));
    await bloc.stream.firstWhere((state) => state is TasksEditing);
    bloc.add(TasksSaved(_draft(title: 'Изменённая задача')));
    final afterEdit =
        await bloc.stream.firstWhere(
              (state) =>
                  state is TasksDisplay &&
                  state.data.tasks.single.title == 'Изменённая задача',
            )
            as TasksDisplay;
    expect(repository.updateCalls, 1);

    bloc.add(TasksDeleteRequested(afterEdit.data.tasks.single.id));
    await bloc.stream.firstWhere(
      (state) => state is TasksDisplay && state.data.tasks.isEmpty,
    );
    expect(repository.deleteCalls, 1);
  });

  test('rapid duplicate completion reaches repository once', () async {
    final repository = _FakeTaskRepository([
      _task(id: 'task-1', day: DateTime(2026, 9, 4)),
    ]);
    final bloc = TasksBloc(repository: repository);
    addTearDown(bloc.close);
    bloc.add(const TasksStarted());
    await bloc.stream.firstWhere((state) => state is TasksDisplay);

    final gate = Completer<void>();
    repository.completionGate = gate;
    bloc.add(const TasksCompletionRequested('task-1'));
    await bloc.stream.firstWhere((state) => state is TasksOperationInProgress);
    bloc.add(const TasksCompletionRequested('task-1'));
    gate.complete();
    await bloc.stream.firstWhere(
      (state) => state is TasksDisplay && state.data.tasks.single.isCompleted,
    );
    await Future<void>.delayed(Duration.zero);

    expect(repository.completeCalls, 1);
  });

  test('AI task cannot enter the normal completion flow', () async {
    final repository = _FakeTaskRepository([
      _task(
        id: 'ai-task',
        day: DateTime(2026, 9, 4),
        verificationMode: TaskVerificationMode.ai,
      ),
    ]);
    final bloc = TasksBloc(repository: repository);
    addTearDown(bloc.close);
    bloc.add(const TasksStarted());
    await bloc.stream.firstWhere((state) => state is TasksDisplay);

    bloc.add(const TasksCompletionRequested('ai-task'));
    final display =
        await bloc.stream.firstWhere(
              (state) => state is TasksDisplay && state.feedback != null,
            )
            as TasksDisplay;

    expect(repository.completeCalls, 0);
    expect(display.feedback?.message, contains('пока недоступно'));
    expect(display.data.tasks.single.isCompleted, isFalse);
  });
}

TaskDraft _draft({required String title}) => TaskDraft(
  title: title,
  description: '',
  category: TaskCategory.personal,
  difficulty: TaskDifficulty.normal,
  scheduledDate: DateTime(2026, 9, 4),
  deadline: null,
  verificationMode: TaskVerificationMode.none,
);

EmpireTask _task({
  required String id,
  required DateTime day,
  bool completed = false,
  String? title,
  TaskVerificationMode verificationMode = TaskVerificationMode.none,
}) => EmpireTask(
  id: id,
  userId: 'user-1',
  title: title ?? id,
  description: '',
  category: TaskCategory.personal,
  difficulty: TaskDifficulty.normal,
  scheduledDate: day,
  deadline: null,
  status: completed ? TaskStatus.completed : TaskStatus.pending,
  verificationMode: verificationMode,
  createdAt: DateTime(2026, 9, 3),
  completedAt: completed ? DateTime(2026, 9, 4, 12) : null,
);

final class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository(List<EmpireTask> tasks) : _tasks = List.of(tasks);

  List<EmpireTask> _tasks;
  Completer<void>? completionGate;
  var addCalls = 0;
  var updateCalls = 0;
  var deleteCalls = 0;
  var completeCalls = 0;

  @override
  Future<EmpireTask> addTask(TaskDraft draft) async {
    addCalls += 1;
    final task = _task(
      id: 'task-${_tasks.length + 1}',
      day: draft.scheduledDate,
      title: draft.title,
    );
    _tasks = [..._tasks, task];
    return task;
  }

  @override
  Future<EmpireTask> updateTask(String taskId, TaskDraft draft) async {
    updateCalls += 1;
    final updated = _task(
      id: taskId,
      day: draft.scheduledDate,
      title: draft.title,
    );
    _tasks = [
      for (final task in _tasks)
        if (task.id == taskId) updated else task,
    ];
    return updated;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    deleteCalls += 1;
    _tasks = _tasks.where((task) => task.id != taskId).toList();
  }

  @override
  Future<TaskCompletionResult> completeTask(String taskId) async {
    completeCalls += 1;
    await completionGate?.future;
    final task = _tasks.singleWhere((item) => item.id == taskId);
    _tasks = [
      for (final item in _tasks)
        if (item.id == taskId)
          EmpireTask(
            id: item.id,
            userId: item.userId,
            title: item.title,
            description: item.description,
            category: item.category,
            difficulty: item.difficulty,
            scheduledDate: item.scheduledDate,
            deadline: item.deadline,
            status: TaskStatus.completed,
            verificationMode: item.verificationMode,
            createdAt: item.createdAt,
            completedAt: DateTime(2026, 9, 4, 12),
          )
        else
          item,
    ];
    return TaskCompletionResult(
      taskId: taskId,
      completedAt: DateTime(2026, 9, 4, 12),
      xpAwarded: task.difficulty.xpReward,
      goldAwarded: task.difficulty.goldReward,
      totalXp: 25,
      totalGold: 115,
      level: 1,
    );
  }

  @override
  Future<List<EmpireTask>> fetchTasks() async => List.unmodifiable(_tasks);
}
