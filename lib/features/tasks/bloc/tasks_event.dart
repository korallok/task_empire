part of 'tasks_bloc.dart';

sealed class TasksEvent extends Equatable {
  const TasksEvent();

  @override
  List<Object?> get props => const [];
}

final class TasksStarted extends TasksEvent {
  const TasksStarted();
}

final class TasksRefreshRequested extends TasksEvent {
  const TasksRefreshRequested();
}

final class TasksDaySelected extends TasksEvent {
  const TasksDaySelected(this.day);

  final DateTime day;

  @override
  List<Object> get props => [day];
}

final class TasksCreateRequested extends TasksEvent {
  const TasksCreateRequested({required this.initialDate});

  final DateTime initialDate;

  @override
  List<Object> get props => [initialDate];
}

final class TasksEditRequested extends TasksEvent {
  const TasksEditRequested(this.task);

  final EmpireTask task;

  @override
  List<Object> get props => [task];
}

final class TasksEditorCancelled extends TasksEvent {
  const TasksEditorCancelled();
}

final class TasksSaved extends TasksEvent {
  const TasksSaved(this.draft);

  final TaskDraft draft;

  @override
  List<Object> get props => [draft];
}

final class TasksDeleteRequested extends TasksEvent {
  const TasksDeleteRequested(this.taskId);

  final String taskId;

  @override
  List<Object> get props => [taskId];
}

final class TasksCompletionRequested extends TasksEvent {
  const TasksCompletionRequested(this.taskId);

  final String taskId;

  @override
  List<Object> get props => [taskId];
}
