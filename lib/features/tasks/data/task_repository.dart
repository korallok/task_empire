import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_empire/features/tasks/domain/task_models.dart';

abstract interface class TaskRepository {
  Future<List<EmpireTask>> fetchTasks();

  Future<EmpireTask> addTask(TaskDraft draft);

  Future<EmpireTask> updateTask(String taskId, TaskDraft draft);

  Future<void> deleteTask(String taskId);

  Future<TaskCompletionResult> completeTask(String taskId);
}

final class SupabaseTaskRepository implements TaskRepository {
  const SupabaseTaskRepository(this._client);

  final SupabaseClient _client;

  static const _selection =
      'id,user_id,title,description,category,difficulty,scheduled_date,'
      'deadline,status,verification_mode,created_at,completed_at';

  @override
  Future<List<EmpireTask>> fetchTasks() async {
    _requireUserId();

    try {
      final rows = await _client
          .from('tasks')
          .select(_selection)
          .order('scheduled_date')
          .order('created_at', ascending: false);
      return rows.map(EmpireTask.fromJson).toList(growable: false);
    } on PostgrestException catch (error) {
      throw TaskRepositoryException(
        'Не удалось загрузить задачи.',
        technicalMessage: error.message,
      );
    } on FormatException catch (error) {
      throw TaskRepositoryException(
        'Сервер вернул некорректные данные задачи.',
        technicalMessage: error.message,
      );
    } on TypeError catch (error) {
      throw TaskRepositoryException(
        'Сервер вернул некорректные данные задачи.',
        technicalMessage: error.toString(),
      );
    } on TaskRepositoryException {
      rethrow;
    } on Exception catch (error) {
      throw TaskRepositoryException(
        'Не удалось загрузить задачи. Проверьте подключение к сети.',
        technicalMessage: error.toString(),
      );
    }
  }

  @override
  Future<EmpireTask> addTask(TaskDraft draft) async {
    final userId = _requireUserId();
    _validate(draft);

    try {
      final row = await _client
          .from('tasks')
          .insert({'user_id': userId, ...draft.toDatabaseJson()})
          .select(_selection)
          .single();
      final task = EmpireTask.fromJson(row);
      if (task.userId != userId) {
        throw const TaskRepositoryException(
          'Сервер вернул задачу другого пользователя.',
        );
      }
      return task;
    } on PostgrestException catch (error) {
      throw TaskRepositoryException(
        _messageForDatabaseError(error, fallback: 'Не удалось создать задачу.'),
        technicalMessage: error.message,
      );
    } on FormatException catch (error) {
      throw TaskRepositoryException(
        'Задача создана, но сервер вернул некорректные данные.',
        technicalMessage: error.message,
      );
    } on TypeError catch (error) {
      throw TaskRepositoryException(
        'Задача создана, но сервер вернул некорректные данные.',
        technicalMessage: error.toString(),
      );
    } on TaskRepositoryException {
      rethrow;
    } on Exception catch (error) {
      throw TaskRepositoryException(
        'Не удалось создать задачу. Проверьте подключение к сети.',
        technicalMessage: error.toString(),
      );
    }
  }

  @override
  Future<EmpireTask> updateTask(String taskId, TaskDraft draft) async {
    final userId = _requireUserId();
    _validate(draft);

    try {
      final row = await _client
          .from('tasks')
          .update(draft.toDatabaseJson())
          .eq('id', taskId)
          .select(_selection)
          .single();
      final task = EmpireTask.fromJson(row);
      if (task.id != taskId || task.userId != userId) {
        throw const TaskRepositoryException(
          'Сервер вернул данные другой задачи.',
        );
      }
      return task;
    } on PostgrestException catch (error) {
      throw TaskRepositoryException(
        _messageForDatabaseError(
          error,
          fallback: 'Не удалось сохранить задачу.',
        ),
        technicalMessage: error.message,
      );
    } on FormatException catch (error) {
      throw TaskRepositoryException(
        'Задача сохранена, но сервер вернул некорректные данные.',
        technicalMessage: error.message,
      );
    } on TypeError catch (error) {
      throw TaskRepositoryException(
        'Задача сохранена, но сервер вернул некорректные данные.',
        technicalMessage: error.toString(),
      );
    } on TaskRepositoryException {
      rethrow;
    } on Exception catch (error) {
      throw TaskRepositoryException(
        'Не удалось сохранить задачу. Проверьте подключение к сети.',
        technicalMessage: error.toString(),
      );
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _requireUserId();

    try {
      await _client
          .from('tasks')
          .delete()
          .eq('id', taskId)
          .select('id')
          .single();
    } on PostgrestException catch (error) {
      throw TaskRepositoryException(
        _messageForDatabaseError(error, fallback: 'Не удалось удалить задачу.'),
        technicalMessage: error.message,
      );
    } on TaskRepositoryException {
      rethrow;
    } on Exception catch (error) {
      throw TaskRepositoryException(
        'Не удалось удалить задачу. Проверьте подключение к сети.',
        technicalMessage: error.toString(),
      );
    }
  }

  @override
  Future<TaskCompletionResult> completeTask(String taskId) async {
    _requireUserId();

    try {
      final response = await _client.rpc<dynamic>(
        'complete_task_v2',
        params: {'p_task_id': taskId},
      );
      if (response is! Map) {
        throw const TaskRepositoryException(
          'Сервер вернул некорректную награду.',
        );
      }
      final result = TaskCompletionResult.fromJson(
        Map<String, dynamic>.from(response),
      );
      if (result.taskId != taskId) {
        throw const TaskRepositoryException(
          'Сервер вернул награду для другой задачи.',
        );
      }
      return result;
    } on PostgrestException catch (error) {
      throw TaskRepositoryException(
        _messageForDatabaseError(
          error,
          fallback: 'Не удалось завершить задачу.',
        ),
        technicalMessage: error.message,
      );
    } on FormatException catch (error) {
      throw TaskRepositoryException(
        'Сервер вернул некорректную награду.',
        technicalMessage: error.message,
      );
    } on TypeError catch (error) {
      throw TaskRepositoryException(
        'Сервер вернул некорректную награду.',
        technicalMessage: error.toString(),
      );
    } on TaskRepositoryException {
      rethrow;
    } on Exception catch (error) {
      throw TaskRepositoryException(
        'Не удалось завершить задачу. Проверьте подключение к сети.',
        technicalMessage: error.toString(),
      );
    }
  }

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const TaskRepositoryException(
        'Для работы с задачами необходимо войти в аккаунт.',
      );
    }
    return userId;
  }

  void _validate(TaskDraft draft) {
    final titleLength = draft.title.trim().length;
    if (titleLength < 1 || titleLength > 500) {
      throw const TaskRepositoryException(
        'Название задачи должно содержать от 1 до 500 символов.',
      );
    }
    if (draft.description.trim().length > 4000) {
      throw const TaskRepositoryException(
        'Описание задачи не должно превышать 4000 символов.',
      );
    }
    if (draft.deadline != null &&
        dateOnly(draft.deadline!).isBefore(dateOnly(draft.scheduledDate))) {
      throw const TaskRepositoryException(
        'Дедлайн не может быть раньше запланированной даты.',
      );
    }
  }

  String _messageForDatabaseError(
    PostgrestException error, {
    required String fallback,
  }) {
    final message = error.message;
    if (message.contains('TASK_ALREADY_COMPLETED')) {
      return 'Эта задача уже выполнена.';
    }
    if (message.contains('TASK_NOT_FOUND')) {
      return 'Задача не найдена или уже удалена.';
    }
    if (message.contains('TASK_REQUIRES_AI_VERIFICATION')) {
      return 'Для этой задачи сначала добавьте подтверждение выполнения.';
    }
    if (message.contains('UNAUTHORIZED')) {
      return 'Сессия истекла. Войдите в аккаунт снова.';
    }
    if (message.contains('23514')) {
      return 'Проверьте заполненные поля задачи.';
    }
    return fallback;
  }
}

final class TaskRepositoryException implements Exception {
  const TaskRepositoryException(this.message, {this.technicalMessage});

  final String message;
  final String? technicalMessage;

  @override
  String toString() => technicalMessage == null
      ? 'TaskRepositoryException: $message'
      : 'TaskRepositoryException: $message ($technicalMessage)';
}
