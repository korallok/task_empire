import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:task_empire/app.dart';
import 'package:task_empire/features/city/data/city_repository.dart';
import 'package:task_empire/features/city/domain/city_building.dart';
import 'package:task_empire/features/city/domain/city_state_data.dart';
import 'package:task_empire/features/progression/data/progression_repository.dart';
import 'package:task_empire/features/progression/domain/progression_profile.dart';
import 'package:task_empire/features/tasks/data/task_repository.dart';
import 'package:task_empire/features/tasks/domain/task_models.dart';

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
        RepositoryProvider<ProgressionRepository>(
          create: (_) => const _PreviewProgressionRepository(),
        ),
      ],
      child: const TaskEmpireView(),
    ),
  );
}

final class _PreviewTaskRepository implements TaskRepository {
  _PreviewTaskRepository() : _tasks = _initialTasks();

  List<EmpireTask> _tasks;

  static List<EmpireTask> _initialTasks() {
    final now = DateTime.now();
    final today = dateOnly(now);
    return [
      EmpireTask(
        id: 'preview-1',
        userId: 'preview-user',
        title: 'Подготовить презентацию к встрече',
        description: 'Собрать результаты недели и следующие шаги.',
        category: TaskCategory.work,
        difficulty: TaskDifficulty.hard,
        scheduledDate: today,
        deadline: now.add(const Duration(hours: 3)),
        status: TaskStatus.pending,
        verificationMode: TaskVerificationMode.none,
        createdAt: now.subtract(const Duration(hours: 2)),
        completedAt: null,
      ),
      EmpireTask(
        id: 'preview-2',
        userId: 'preview-user',
        title: 'Разобрать почту и ответить команде',
        description: '',
        category: TaskCategory.work,
        difficulty: TaskDifficulty.normal,
        scheduledDate: today,
        deadline: now.add(const Duration(days: 1, hours: 2)),
        status: TaskStatus.pending,
        verificationMode: TaskVerificationMode.none,
        createdAt: now.subtract(const Duration(hours: 4)),
        completedAt: null,
      ),
      EmpireTask(
        id: 'preview-3',
        userId: 'preview-user',
        title: 'Спланировать цели на следующий месяц',
        description: 'Определить три главных результата.',
        category: TaskCategory.personal,
        difficulty: TaskDifficulty.normal,
        scheduledDate: today.add(const Duration(days: 1)),
        deadline: null,
        status: TaskStatus.pending,
        verificationMode: TaskVerificationMode.none,
        createdAt: now.subtract(const Duration(days: 1)),
        completedAt: null,
      ),
      EmpireTask(
        id: 'preview-4',
        userId: 'preview-user',
        title: 'Тренировка и прогулка',
        description: '',
        category: TaskCategory.health,
        difficulty: TaskDifficulty.easy,
        scheduledDate: today,
        deadline: null,
        status: TaskStatus.completed,
        verificationMode: TaskVerificationMode.none,
        createdAt: now.subtract(const Duration(days: 2)),
        completedAt: now.subtract(const Duration(hours: 5)),
      ),
    ];
  }

  @override
  Future<EmpireTask> addTask(TaskDraft draft) async {
    final task = _taskFromDraft(
      id: 'preview-${_tasks.length + 1}',
      draft: draft,
    );
    _tasks = [..._tasks, task];
    return task;
  }

  @override
  Future<TaskCompletionResult> completeTask(String taskId) async {
    final completedAt = DateTime.now();
    final task = _tasks.singleWhere((item) => item.id == taskId);
    _tasks = [
      for (final item in _tasks)
        if (item.id == taskId) item.markCompleted(completedAt) else item,
    ];
    return TaskCompletionResult(
      taskId: taskId,
      completedAt: completedAt,
      xpAwarded: task.difficulty.xpReward,
      goldAwarded: task.difficulty.goldReward,
      totalXp: 285 + task.difficulty.xpReward,
      totalGold: 640 + task.difficulty.goldReward,
      level: 6,
    );
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _tasks = _tasks.where((task) => task.id != taskId).toList();
  }

  @override
  Future<List<EmpireTask>> fetchTasks() async => List.unmodifiable(_tasks);

  @override
  Future<EmpireTask> updateTask(String taskId, TaskDraft draft) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    final updated = _taskFromDraft(
      id: taskId,
      draft: draft,
      createdAt: _tasks[index].createdAt,
    );
    _tasks = [..._tasks]..[index] = updated;
    return updated;
  }

  EmpireTask _taskFromDraft({
    required String id,
    required TaskDraft draft,
    DateTime? createdAt,
  }) {
    return EmpireTask(
      id: id,
      userId: 'preview-user',
      title: draft.title.trim(),
      description: draft.description.trim(),
      category: draft.category,
      difficulty: draft.difficulty,
      scheduledDate: dateOnly(draft.scheduledDate),
      deadline: draft.deadline,
      status: TaskStatus.pending,
      verificationMode: draft.verificationMode,
      createdAt: createdAt ?? DateTime.now(),
      completedAt: null,
    );
  }
}

final class _PreviewCityRepository implements CityRepository {
  _PreviewCityRepository()
    : _buildings = [
        _building('hall', 'town_hall', 1, 1),
        _building('house', 'house', 6, 2),
        _building('garden', 'garden', 5, 5),
      ];

  final List<Map<String, dynamic>> _buildings;
  var _gold = 640;
  var _nextId = 1;

  CityStateData get _city => CityStateData.fromJson({
    'profile': {'gold': _gold, 'xp': 285, 'level': 6, 'prosperity': 58},
    'city': {'map_level': 1, 'map_width': 12, 'map_height': 10},
    'buildings': _buildings,
    'catalog': _catalog,
  });

  @override
  Future<CityStateData> buildBuilding({
    required String code,
    required CityTileCoordinate position,
    required CityBuildingRotation rotation,
  }) async {
    final definition = _catalog.singleWhere((row) => row['code'] == code);
    _gold -= definition['price'] as int;
    _buildings.add({
      ...definition,
      'id': 'preview-building-${_nextId++}',
      'position_x': position.x,
      'position_y': position.y,
      'rotation': rotation.degrees,
    });
    return _city;
  }

  @override
  Future<CityStateData> fetchCity() async => _city;

  @override
  Future<CityStateData> moveBuilding({
    required String buildingId,
    required CityTileCoordinate position,
    required CityBuildingRotation rotation,
  }) async {
    final index = _buildings.indexWhere((row) => row['id'] == buildingId);
    _buildings[index] = {
      ..._buildings[index],
      'position_x': position.x,
      'position_y': position.y,
      'rotation': rotation.degrees,
    };
    return _city;
  }
}

const _catalog = <Map<String, dynamic>>[
  {
    'id': 'definition-town-hall',
    'code': 'town_hall',
    'name': 'Ратуша',
    'level': 1,
    'price': 60,
    'required_player_level': 1,
    'sprite': 'assets/city/buildings/town_hall_level_1.webp',
    'footprint_width': 4,
    'footprint_height': 4,
    'prosperity': 40,
  },
  {
    'id': 'definition-house',
    'code': 'house',
    'name': 'Дом',
    'level': 1,
    'price': 15,
    'required_player_level': 1,
    'sprite': 'assets/city/buildings/house_level_1.webp',
    'footprint_width': 2,
    'footprint_height': 2,
    'prosperity': 10,
  },
  {
    'id': 'definition-library',
    'code': 'library',
    'name': 'Библиотека',
    'level': 1,
    'price': 45,
    'required_player_level': 2,
    'sprite': 'assets/city/buildings/library_level_1.webp',
    'footprint_width': 3,
    'footprint_height': 3,
    'prosperity': 25,
  },
  {
    'id': 'definition-workshop',
    'code': 'workshop',
    'name': 'Мастерская',
    'level': 1,
    'price': 60,
    'required_player_level': 3,
    'sprite': 'assets/city/buildings/workshop_level_1.webp',
    'footprint_width': 3,
    'footprint_height': 2,
    'prosperity': 30,
  },
  {
    'id': 'definition-market',
    'code': 'market',
    'name': 'Рынок',
    'level': 1,
    'price': 75,
    'required_player_level': 4,
    'sprite': 'assets/city/buildings/market_level_1.webp',
    'footprint_width': 3,
    'footprint_height': 3,
    'prosperity': 35,
  },
  {
    'id': 'definition-tower',
    'code': 'tower',
    'name': 'Башня',
    'level': 1,
    'price': 100,
    'required_player_level': 5,
    'sprite': 'assets/city/buildings/tower_level_1.webp',
    'footprint_width': 2,
    'footprint_height': 2,
    'prosperity': 45,
  },
  {
    'id': 'definition-garden',
    'code': 'garden',
    'name': 'Сад',
    'level': 1,
    'price': 10,
    'required_player_level': 1,
    'sprite': 'assets/city/buildings/garden_level_1.webp',
    'footprint_width': 2,
    'footprint_height': 2,
    'prosperity': 8,
  },
];

Map<String, dynamic> _building(String id, String code, int x, int y) {
  final definition = _catalog.singleWhere((row) => row['code'] == code);
  return {
    ...definition,
    'id': id,
    'position_x': x,
    'position_y': y,
    'rotation': 0,
  };
}

final class _PreviewProgressionRepository implements ProgressionRepository {
  const _PreviewProgressionRepository();

  @override
  Future<ProgressionProfile> fetchProfile() async {
    return const ProgressionProfile(
      userId: 'preview-user',
      isGuest: false,
      xp: 285,
      gold: 640,
      level: 6,
      xpIntoLevel: 35,
      xpForNextLevel: 100,
      completedTasks: 24,
      streak: 7,
    );
  }
}
