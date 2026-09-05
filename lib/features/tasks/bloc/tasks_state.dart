part of 'tasks_bloc.dart';

final class TasksSnapshot extends Equatable {
  TasksSnapshot({
    required List<EmpireTask> tasks,
    required DateTime selectedDate,
  }) : tasks = List.unmodifiable(tasks),
       selectedDate = dateOnly(selectedDate);

  final List<EmpireTask> tasks;
  final DateTime selectedDate;

  List<EmpireTask> tasksForDay(DateTime day) {
    final result = tasks.where((task) => task.isScheduledFor(day)).toList();
    result.sort(_compareTasks);
    return List.unmodifiable(result);
  }

  List<EmpireTask> get selectedTasks => tasksForDay(selectedDate);

  List<EmpireTask> get todayTasks => tasksForDay(DateTime.now());

  int completedForDay(DateTime day) =>
      tasksForDay(day).where((task) => task.isCompleted).length;

  double progressForDay(DateTime day) {
    final dailyTasks = tasksForDay(day);
    if (dailyTasks.isEmpty) return 0;
    return dailyTasks.where((task) => task.isCompleted).length /
        dailyTasks.length;
  }

  EmpireTask? taskById(String id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  TasksSnapshot copyWith({List<EmpireTask>? tasks, DateTime? selectedDate}) {
    return TasksSnapshot(
      tasks: tasks ?? this.tasks,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }

  static int _compareTasks(EmpireTask left, EmpireTask right) {
    if (left.isCompleted != right.isCompleted) {
      return left.isCompleted ? 1 : -1;
    }
    final leftDeadline = left.deadline;
    final rightDeadline = right.deadline;
    if (leftDeadline != null && rightDeadline != null) {
      final order = leftDeadline.compareTo(rightDeadline);
      if (order != 0) return order;
    } else if (leftDeadline != null) {
      return -1;
    } else if (rightDeadline != null) {
      return 1;
    }
    return right.createdAt.compareTo(left.createdAt);
  }

  @override
  List<Object> get props => [tasks, selectedDate];
}

final class TasksFeedback extends Equatable {
  const TasksFeedback({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  List<Object> get props => [message, isError];
}

sealed class TasksState extends Equatable {
  const TasksState();

  TasksSnapshot? get snapshot => null;

  @override
  List<Object?> get props => [snapshot];
}

final class TasksLoading extends TasksState {
  const TasksLoading({this.previousSnapshot});

  final TasksSnapshot? previousSnapshot;

  @override
  TasksSnapshot? get snapshot => previousSnapshot;
}

final class TasksDisplay extends TasksState {
  const TasksDisplay(this.data, {this.feedback});

  final TasksSnapshot data;
  final TasksFeedback? feedback;

  @override
  TasksSnapshot get snapshot => data;

  @override
  List<Object?> get props => [data, feedback];
}

final class TasksEditing extends TasksState {
  const TasksEditing(
    this.data, {
    required this.initialDate,
    this.original,
    this.isSubmitting = false,
  });

  final TasksSnapshot data;
  final DateTime initialDate;
  final EmpireTask? original;
  final bool isSubmitting;

  @override
  TasksSnapshot get snapshot => data;

  @override
  List<Object?> get props => [data, initialDate, original, isSubmitting];
}

final class TasksOperationInProgress extends TasksState {
  const TasksOperationInProgress(
    this.data, {
    required this.taskId,
    required this.message,
  });

  final TasksSnapshot data;
  final String taskId;
  final String message;

  @override
  TasksSnapshot get snapshot => data;

  @override
  List<Object> get props => [data, taskId, message];
}

final class TasksFailure extends TasksState {
  const TasksFailure(this.message, {this.previousSnapshot});

  final String message;
  final TasksSnapshot? previousSnapshot;

  @override
  TasksSnapshot? get snapshot => previousSnapshot;

  @override
  List<Object?> get props => [message, previousSnapshot];
}
