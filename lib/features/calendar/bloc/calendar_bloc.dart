import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:task_empire/features/calendar/data/task_item.dart';
import 'package:task_empire/features/calendar/data/task_repository.dart';

part 'calendar_event.dart';
part 'calendar_state.dart';

final class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  CalendarBloc({required TaskRepository repository})
    : _repository = repository,
      super(const CalendarLoading()) {
    on<CalendarStarted>(_onStarted, transformer: restartable());
    on<CalendarRefreshRequested>(_onRefreshRequested, transformer: droppable());
    on<CalendarAddFormRequested>(_onAddFormRequested);
    on<CalendarAddCancelled>(_onAddCancelled);
    on<CalendarTaskSubmitted>(_onTaskSubmitted, transformer: sequential());
    on<CalendarTaskCompletionRequested>(
      _onTaskCompletionRequested,
      transformer: droppable(),
    );
  }

  final TaskRepository _repository;

  Future<void> _onStarted(
    CalendarStarted event,
    Emitter<CalendarState> emit,
  ) async {
    await _load(emit, previous: state.snapshot);
  }

  Future<void> _onRefreshRequested(
    CalendarRefreshRequested event,
    Emitter<CalendarState> emit,
  ) async {
    if (state is CalendarAdding || state is CalendarCompleting) return;
    await _load(emit, previous: state.snapshot);
  }

  void _onAddFormRequested(
    CalendarAddFormRequested event,
    Emitter<CalendarState> emit,
  ) {
    final current = state.snapshot;
    if (state is CalendarDisplay && current != null) {
      emit(CalendarAdding(current));
    }
  }

  void _onAddCancelled(
    CalendarAddCancelled event,
    Emitter<CalendarState> emit,
  ) {
    if (state case CalendarAdding(:final data, isSubmitting: false)) {
      emit(CalendarDisplay(data));
    }
  }

  Future<void> _onTaskSubmitted(
    CalendarTaskSubmitted event,
    Emitter<CalendarState> emit,
  ) async {
    final currentState = state;
    if (currentState is! CalendarAdding || currentState.isSubmitting) return;

    final previous = currentState.data;
    emit(CalendarAdding(previous, isSubmitting: true));

    try {
      await _repository.addTask(event.draft);
      final tasks = await _repository.fetchTasks();
      emit(
        CalendarDisplay(
          CalendarSnapshot.fromTasks(tasks),
          feedback: const CalendarFeedback(message: 'Задача добавлена.'),
        ),
      );
    } on TaskRepositoryException catch (error) {
      emit(
        CalendarDisplay(
          previous,
          feedback: CalendarFeedback(message: error.message, isError: true),
        ),
      );
    }
  }

  Future<void> _onTaskCompletionRequested(
    CalendarTaskCompletionRequested event,
    Emitter<CalendarState> emit,
  ) async {
    final previous = state.snapshot;
    if (previous == null ||
        state is CalendarAdding ||
        state is CalendarCompleting) {
      return;
    }

    TaskItem? task;
    for (final item in [...previous.deadlineTasks, ...previous.timelessTasks]) {
      if (item.id == event.taskId) {
        task = item;
        break;
      }
    }
    if (task == null || task.isCompleted) return;

    emit(CalendarCompleting(previous, taskId: event.taskId));

    try {
      final result = await _repository.completeTask(event.taskId);
      final tasks = await _repository.fetchTasks();
      final rewardText = result.goldAwarded > 0
          ? '+${result.goldAwarded} золота'
          : 'Дневной лимит золота исчерпан';
      emit(
        CalendarDisplay(
          CalendarSnapshot.fromTasks(tasks),
          feedback: CalendarFeedback(
            message:
                '$rewardText · Ранг ${result.approvedDifficulty.code}. '
                '${result.reason}',
          ),
        ),
      );
    } on TaskRepositoryException catch (error) {
      emit(
        CalendarDisplay(
          previous,
          feedback: CalendarFeedback(message: error.message, isError: true),
        ),
      );
    }
  }

  Future<void> _load(
    Emitter<CalendarState> emit, {
    required CalendarSnapshot? previous,
  }) async {
    emit(CalendarLoading(previousSnapshot: previous));
    try {
      final tasks = await _repository.fetchTasks();
      emit(CalendarDisplay(CalendarSnapshot.fromTasks(tasks)));
    } on TaskRepositoryException catch (error) {
      if (previous == null) {
        emit(CalendarFailure(error.message));
      } else {
        emit(
          CalendarDisplay(
            previous,
            feedback: CalendarFeedback(message: error.message, isError: true),
          ),
        );
      }
    }
  }
}
