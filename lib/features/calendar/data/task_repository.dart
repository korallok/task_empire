import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_empire/features/calendar/data/task_item.dart';

abstract interface class TaskRepository {
  Future<List<TaskItem>> fetchTasks();

  Future<void> addTask(NewTaskDraft draft);

  Future<TaskCompletionResult> completeTask(String taskId);
}

final class SupabaseTaskRepository implements TaskRepository {
  const SupabaseTaskRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<TaskItem>> fetchTasks() async {
    _requireUserId();

    try {
      final rows = await _client
          .from('tasks')
          .select(
            'id,user_id,title,difficulty,has_deadline,deadline,'
            'is_completed,created_at,completed_at',
          )
          .order('created_at', ascending: false);

      try {
        return rows.map(TaskItem.fromJson).toList(growable: false);
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
      }
    } on PostgrestException catch (error) {
      throw TaskRepositoryException(
        'Не удалось загрузить задачи.',
        technicalMessage: error.message,
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
  Future<void> addTask(NewTaskDraft draft) async {
    final userId = _requireUserId();
    final title = draft.title.trim();

    if (title.isEmpty || title.length > 500) {
      throw const TaskRepositoryException(
        'Название задачи должно содержать от 1 до 500 символов.',
      );
    }

    try {
      await _client.from('tasks').insert({
        'user_id': userId,
        'title': title,
        'difficulty': TaskDifficulty.e.code,
        'has_deadline': draft.deadline != null,
        'deadline': draft.deadline?.toUtc().toIso8601String(),
      });
    } on PostgrestException catch (error) {
      throw TaskRepositoryException(
        'Не удалось добавить задачу.',
        technicalMessage: error.message,
      );
    } on Exception catch (error) {
      throw TaskRepositoryException(
        'Не удалось добавить задачу. Проверьте подключение к сети.',
        technicalMessage: error.toString(),
      );
    }
  }

  @override
  Future<TaskCompletionResult> completeTask(String taskId) async {
    _requireUserId();

    try {
      final response = await _client.functions.invoke(
        'complete_task_secure',
        body: {'taskId': taskId},
      );
      final data = response.data;

      if (data is! Map<String, dynamic>) {
        throw const TaskRepositoryException(
          'Сервер вернул некорректный результат выполнения.',
        );
      }

      return TaskCompletionResult.fromJson(data);
    } on FunctionException catch (error) {
      throw TaskRepositoryException(
        _messageForFunctionError(error),
        technicalMessage: error.toString(),
      );
    } on FormatException catch (error) {
      throw TaskRepositoryException(
        'Сервер вернул некорректные данные.',
        technicalMessage: error.message,
      );
    } on TypeError catch (error) {
      throw TaskRepositoryException(
        'Сервер вернул некорректные данные.',
        technicalMessage: error.toString(),
      );
    } on TaskRepositoryException {
      rethrow;
    } on Exception catch (error) {
      throw TaskRepositoryException(
        'Не удалось связаться с сервером выполнения задач.',
        technicalMessage: error.toString(),
      );
    }
  }

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const TaskRepositoryException(
        'Для работы с календарём необходимо войти в аккаунт.',
      );
    }
    return userId;
  }

  String _messageForFunctionError(FunctionException exception) {
    final details = exception.details;
    String? code;

    if (details is Map<String, dynamic>) {
      final error = details['error'];
      if (error is Map<String, dynamic>) {
        code = error['code'] as String?;
      }
    }

    return switch (code) {
      'TASK_ALREADY_COMPLETED' => 'Эта задача уже выполнена.',
      'TASK_ASSESSMENT_IN_PROGRESS' =>
        'Эта задача уже проверяется. Подождите немного.',
      'ASSESSMENT_RESERVATION_LOST' =>
        'Проверка задачи устарела. Запустите её ещё раз.',
      'AI_DAILY_LIMIT' =>
        'Дневной лимит проверок сложности исчерпан. Попробуйте завтра.',
      'TASK_NOT_FOUND' => 'Задача не найдена.',
      'AI_TIMEOUT' => 'Проверка сложности заняла слишком много времени.',
      'AI_UNAVAILABLE' ||
      'AI_INVALID_RESPONSE' ||
      'AI_INCOMPLETE_RESPONSE' ||
      'AI_EMPTY_RESPONSE' ||
      'AI_INVALID_ASSESSMENT' => 'Сервис оценки сложности временно недоступен.',
      'UNAUTHORIZED' => 'Сессия истекла. Войдите в аккаунт снова.',
      _ => 'Не удалось выполнить задачу. Попробуйте ещё раз.',
    };
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
