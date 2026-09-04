part of 'calendar_bloc.dart';

sealed class CalendarEvent extends Equatable {
  const CalendarEvent();

  @override
  List<Object?> get props => const [];
}

final class CalendarStarted extends CalendarEvent {
  const CalendarStarted();
}

final class CalendarRefreshRequested extends CalendarEvent {
  const CalendarRefreshRequested();
}

final class CalendarAddFormRequested extends CalendarEvent {
  const CalendarAddFormRequested();
}

final class CalendarAddCancelled extends CalendarEvent {
  const CalendarAddCancelled();
}

final class CalendarTaskSubmitted extends CalendarEvent {
  const CalendarTaskSubmitted(this.draft);

  final NewTaskDraft draft;

  @override
  List<Object> get props => [draft];
}

final class CalendarTaskCompletionRequested extends CalendarEvent {
  const CalendarTaskCompletionRequested(this.taskId);

  final String taskId;

  @override
  List<Object> get props => [taskId];
}
