import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:task_empire/app.dart';
import 'package:task_empire/features/calendar/data/task_item.dart';
import 'package:task_empire/features/calendar/data/task_repository.dart';
import 'package:task_empire/features/city/data/city_repository.dart';
import 'package:task_empire/features/city/domain/city_building.dart';
import 'package:task_empire/features/city/domain/city_state_data.dart';

void main() {
  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TaskRepository>(
          create: (_) => _PreviewTaskRepository(),
        ),
        RepositoryProvider<CityRepository>(
          create: (_) => _PreviewCityRepository(),
        ),
      ],
      child: const TaskEmpireView(),
    ),
  );
}

final class _PreviewTaskRepository implements TaskRepository {
  _PreviewTaskRepository() : _tasks = _initialTasks();

  List<TaskItem> _tasks;

  static List<TaskItem> _initialTasks() {
    final now = DateTime.now();
    return [
      TaskItem(
        id: 'preview-1',
        userId: 'preview-user',
        title: 'Подготовить презентацию к встрече',
        difficulty: TaskDifficulty.b,
        hasDeadline: true,
        deadline: now.add(const Duration(hours: 3)),
        isCompleted: false,
        createdAt: now.subtract(const Duration(hours: 2)),
        completedAt: null,
      ),
      TaskItem(
        id: 'preview-2',
        userId: 'preview-user',
        title: 'Разобрать почту и ответить команде',
        difficulty: TaskDifficulty.c,
        hasDeadline: true,
        deadline: now.add(const Duration(days: 1, hours: 2)),
        isCompleted: false,
        createdAt: now.subtract(const Duration(hours: 4)),
        completedAt: null,
      ),
      TaskItem(
        id: 'preview-3',
        userId: 'preview-user',
        title: 'Спланировать цели на следующий месяц',
        difficulty: TaskDifficulty.a,
        hasDeadline: false,
        deadline: null,
        isCompleted: false,
        createdAt: now.subtract(const Duration(days: 1)),
        completedAt: null,
      ),
      TaskItem(
        id: 'preview-4',
        userId: 'preview-user',
        title: 'Тренировка и прогулка',
        difficulty: TaskDifficulty.d,
        hasDeadline: false,
        deadline: null,
        isCompleted: true,
        createdAt: now.subtract(const Duration(days: 2)),
        completedAt: now.subtract(const Duration(hours: 5)),
      ),
    ];
  }

  @override
  Future<void> addTask(NewTaskDraft draft) async {
    final now = DateTime.now();
    _tasks = [
      TaskItem(
        id: 'preview-${_tasks.length + 1}',
        userId: 'preview-user',
        title: draft.title,
        difficulty: TaskDifficulty.e,
        hasDeadline: draft.deadline != null,
        deadline: draft.deadline,
        isCompleted: false,
        createdAt: now,
        completedAt: null,
      ),
      ..._tasks,
    ];
  }

  @override
  Future<TaskCompletionResult> completeTask(String taskId) async {
    final completedAt = DateTime.now();
    _tasks = [
      for (final task in _tasks)
        if (task.id == taskId)
          TaskItem(
            id: task.id,
            userId: task.userId,
            title: task.title,
            difficulty: task.difficulty,
            hasDeadline: task.hasDeadline,
            deadline: task.deadline,
            isCompleted: true,
            createdAt: task.createdAt,
            completedAt: completedAt,
          )
        else
          task,
    ];
    return TaskCompletionResult(
      taskId: taskId,
      approvedDifficulty: TaskDifficulty.b,
      reason: 'Задача требует заметной концентрации.',
      goldAwarded: 100,
      totalGold: 740,
      dailyGoldEarned: 180,
      dailyGoldCap: 600,
      completedAt: completedAt,
    );
  }

  @override
  Future<List<TaskItem>> fetchTasks() async => List.unmodifiable(_tasks);
}

final class _PreviewCityRepository implements CityRepository {
  final _city = CityStateData.fromJson({
    'profile': {
      'gold': 640,
      'prosperity': 95,
      'daily_gold_earned': 180,
      'passive_gold_earned': 12,
      'income_per_hour': 29,
    },
    'buildings': [
      {
        'id': 'hall',
        'type': 'town_hall',
        'level': 2,
        'iso_x': 3,
        'iso_y': 3,
        'income_per_hour': 24,
        'prosperity': 80,
        'upgrade_cost': 1532,
        'max_level': 5,
      },
      {
        'id': 'market',
        'type': 'market',
        'level': 1,
        'iso_x': 5,
        'iso_y': 3,
        'income_per_hour': 5,
        'prosperity': 15,
        'upgrade_cost': 350,
        'max_level': 5,
      },
    ],
    'catalog': [
      {
        'type': 'market',
        'build_price': 200,
        'income_per_hour': 5,
        'prosperity': 15,
        'max_level': 5,
      },
      {
        'type': 'town_hall',
        'build_price': 500,
        'income_per_hour': 12,
        'prosperity': 40,
        'max_level': 5,
      },
    ],
  });

  @override
  Future<void> buildBuilding({
    required CityBuildingType type,
    required CityTileCoordinate tile,
  }) async {}

  @override
  Future<CityStateData> fetchCity() async => _city;

  @override
  Future<void> upgradeBuilding(String buildingId) async {}
}
