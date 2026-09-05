import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:task_empire/features/tasks/data/task_repository.dart';
import 'package:task_empire/features/tasks/domain/task_models.dart';

part 'tasks_event.dart';
part 'tasks_state.dart';

final class TasksBloc extends Bloc<TasksEvent, TasksState> {
  TasksBloc({required TaskRepository repository})
    : _repository = repository,
      super(const TasksLoading()) {
    on<TasksStarted>(_onStarted, transformer: restartable());
    on<TasksRefreshRequested>(_onRefreshRequested, transformer: droppable());
    on<TasksDaySelected>(_onDaySelected);
    on<TasksCreateRequested>(_onCreateRequested);
    on<TasksEditRequested>(_onEditRequested);
    on<TasksEditorCancelled>(_onEditorCancelled);
    on<TasksSaved>(_onSaved, transformer: sequential());
    on<TasksDeleteRequested>(_onDeleteRequested, transformer: droppable());
    on<TasksCompletionRequested>(
      _onCompletionRequested,
      transformer: droppable(),
    );
  }

  final TaskRepository _repository;

  Future<void> _onStarted(TasksStarted event, Emitter<TasksState> emit) async {
    await _load(emit, previous: state.snapshot);
  }

  Future<void> _onRefreshRequested(
    TasksRefreshRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (state is TasksEditing || state is TasksOperationInProgress) return;
    await _load(emit, previous: state.snapshot);
  }

  void _onDaySelected(TasksDaySelected event, Emitter<TasksState> emit) {
    final current = state;
    if (current case TasksDisplay(:final data)) {
      emit(TasksDisplay(data.copyWith(selectedDate: event.day)));
    }
  }

  void _onCreateRequested(
    TasksCreateRequested event,
    Emitter<TasksState> emit,
  ) {
    final current = state;
    if (current case TasksDisplay(:final data)) {
      emit(TasksEditing(data, initialDate: event.initialDate));
    }
  }

  void _onEditRequested(TasksEditRequested event, Emitter<TasksState> emit) {
    final current = state;
    if (current is! TasksDisplay || event.task.isCompleted) return;
    if (!current.data.tasks.contains(event.task)) return;
    emit(
      TasksEditing(
        current.data,
        initialDate: event.task.scheduledDate,
        original: event.task,
      ),
    );
  }

  void _onEditorCancelled(
    TasksEditorCancelled event,
    Emitter<TasksState> emit,
  ) {
    if (state case TasksEditing(:final data, isSubmitting: false)) {
      emit(TasksDisplay(data));
    }
  }

  Future<void> _onSaved(TasksSaved event, Emitter<TasksState> emit) async {
    final current = state;
    if (current is! TasksEditing || current.isSubmitting) return;

    final previous = current.data;
    emit(
      TasksEditing(
        previous,
        initialDate: current.initialDate,
        original: current.original,
        isSubmitting: true,
      ),
    );

    try {
      final EmpireTask savedTask;
      if (current.original == null) {
        savedTask = await _repository.addTask(event.draft);
      } else {
        savedTask = await _repository.updateTask(
          current.original!.id,
          event.draft,
        );
      }
      final tasks = current.original == null
          ? [...previous.tasks, savedTask]
          : [
              for (final task in previous.tasks)
                if (task.id == savedTask.id) savedTask else task,
            ];
      emit(
        TasksDisplay(
          previous.copyWith(tasks: tasks),
          feedback: TasksFeedback(
            message: current.original == null
                ? 'Задача создана.'
                : 'Изменения сохранены.',
          ),
        ),
      );
    } on TaskRepositoryException catch (error) {
      emit(
        TasksDisplay(
          previous,
          feedback: TasksFeedback(message: error.message, isError: true),
        ),
      );
    }
  }

  Future<void> _onDeleteRequested(
    TasksDeleteRequested event,
    Emitter<TasksState> emit,
  ) async {
    final current = state;
    if (current is! TasksDisplay) return;
    final task = current.data.taskById(event.taskId);
    if (task == null || task.isCompleted) return;

    final previous = current.data;
    emit(
      TasksOperationInProgress(
        previous,
        taskId: task.id,
        message: 'Удаляем задачу…',
      ),
    );

    try {
      await _repository.deleteTask(task.id);
      final tasks = previous.tasks
          .where((item) => item.id != task.id)
          .toList(growable: false);
      emit(
        TasksDisplay(
          previous.copyWith(tasks: tasks),
          feedback: const TasksFeedback(message: 'Задача удалена.'),
        ),
      );
    } on TaskRepositoryException catch (error) {
      emit(
        TasksDisplay(
          previous,
          feedback: TasksFeedback(message: error.message, isError: true),
        ),
      );
    }
  }

  Future<void> _onCompletionRequested(
    TasksCompletionRequested event,
    Emitter<TasksState> emit,
  ) async {
    final current = state;
    if (current is! TasksDisplay) return;
    final task = current.data.taskById(event.taskId);
    if (task == null || task.isCompleted) return;
    if (task.verificationMode == TaskVerificationMode.ai) {
      emit(
        TasksDisplay(
          current.data,
          feedback: const TasksFeedback(
            message:
                'AI-подтверждение пока недоступно. Задача сохранена для '
                'будущего этапа.',
            isError: true,
          ),
        ),
      );
      return;
    }

    final previous = current.data;
    emit(
      TasksOperationInProgress(
        previous,
        taskId: task.id,
        message: 'Завершаем задачу…',
      ),
    );

    try {
      final result = await _repository.completeTask(task.id);
      final tasks = [
        for (final item in previous.tasks)
          if (item.id == task.id)
            item.markCompleted(result.completedAt)
          else
            item,
      ];
      emit(
        TasksDisplay(
          previous.copyWith(tasks: tasks),
          feedback: TasksFeedback(
            message:
                '+${result.xpAwarded} XP · +${result.goldAwarded} золота · '
                '${result.level} уровень',
          ),
        ),
      );
    } on TaskRepositoryException catch (error) {
      emit(
        TasksDisplay(
          previous,
          feedback: TasksFeedback(message: error.message, isError: true),
        ),
      );
    }
  }

  Future<void> _load(
    Emitter<TasksState> emit, {
    required TasksSnapshot? previous,
  }) async {
    emit(TasksLoading(previousSnapshot: previous));
    try {
      final tasks = await _repository.fetchTasks();
      emit(
        TasksDisplay(
          TasksSnapshot(
            tasks: tasks,
            selectedDate: previous?.selectedDate ?? dateOnly(DateTime.now()),
          ),
        ),
      );
    } on TaskRepositoryException catch (error) {
      if (previous == null) {
        emit(TasksFailure(error.message));
      } else {
        emit(
          TasksDisplay(
            previous,
            feedback: TasksFeedback(message: error.message, isError: true),
          ),
        );
      }
    }
  }
}
