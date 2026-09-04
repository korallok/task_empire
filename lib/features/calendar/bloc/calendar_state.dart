part of 'calendar_bloc.dart';

final class CalendarSnapshot extends Equatable {
  const CalendarSnapshot({
    required this.deadlineTasks,
    required this.timelessTasks,
  });

  factory CalendarSnapshot.fromTasks(List<TaskItem> tasks) {
    final deadlineTasks = tasks
        .where((task) => task.hasDeadline && task.deadline != null)
        .toList();
    final timelessTasks = tasks
        .where((task) => !task.hasDeadline || task.deadline == null)
        .toList();

    deadlineTasks.sort((left, right) {
      final completionOrder = _compareCompletion(left, right);
      if (completionOrder != 0) return completionOrder;
      return left.deadline!.compareTo(right.deadline!);
    });
    timelessTasks.sort((left, right) {
      final completionOrder = _compareCompletion(left, right);
      if (completionOrder != 0) return completionOrder;
      return right.createdAt.compareTo(left.createdAt);
    });

    return CalendarSnapshot(
      deadlineTasks: List.unmodifiable(deadlineTasks),
      timelessTasks: List.unmodifiable(timelessTasks),
    );
  }

  final List<TaskItem> deadlineTasks;
  final List<TaskItem> timelessTasks;

  static int _compareCompletion(TaskItem left, TaskItem right) {
    if (left.isCompleted == right.isCompleted) return 0;
    return left.isCompleted ? 1 : -1;
  }

  @override
  List<Object> get props => [deadlineTasks, timelessTasks];
}

final class CalendarFeedback extends Equatable {
  const CalendarFeedback({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  List<Object> get props => [message, isError];
}

sealed class CalendarState extends Equatable {
  const CalendarState();

  CalendarSnapshot? get snapshot => null;

  @override
  List<Object?> get props => [snapshot];
}

final class CalendarLoading extends CalendarState {
  const CalendarLoading({this.previousSnapshot});

  final CalendarSnapshot? previousSnapshot;

  @override
  CalendarSnapshot? get snapshot => previousSnapshot;
}

final class CalendarDisplay extends CalendarState {
  const CalendarDisplay(this.data, {this.feedback});

  final CalendarSnapshot data;
  final CalendarFeedback? feedback;

  @override
  CalendarSnapshot get snapshot => data;

  @override
  List<Object?> get props => [data, feedback];
}

final class CalendarAdding extends CalendarState {
  const CalendarAdding(this.data, {this.isSubmitting = false});

  final CalendarSnapshot data;
  final bool isSubmitting;

  @override
  CalendarSnapshot get snapshot => data;

  @override
  List<Object> get props => [data, isSubmitting];
}

final class CalendarCompleting extends CalendarState {
  const CalendarCompleting(this.data, {required this.taskId});

  final CalendarSnapshot data;
  final String taskId;

  @override
  CalendarSnapshot get snapshot => data;

  @override
  List<Object> get props => [data, taskId];
}

final class CalendarFailure extends CalendarState {
  const CalendarFailure(this.message, {this.previousSnapshot});

  final String message;
  final CalendarSnapshot? previousSnapshot;

  @override
  CalendarSnapshot? get snapshot => previousSnapshot;

  @override
  List<Object?> get props => [message, previousSnapshot];
}
