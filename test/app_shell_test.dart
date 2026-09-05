import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_empire/app.dart';
import 'package:task_empire/features/city/data/city_repository.dart';
import 'package:task_empire/features/city/domain/city_building.dart';
import 'package:task_empire/features/city/domain/city_state_data.dart';
import 'package:task_empire/features/progression/data/progression_repository.dart';
import 'package:task_empire/features/progression/domain/progression_profile.dart';
import 'package:task_empire/features/tasks/data/task_repository.dart';
import 'package:task_empire/features/tasks/domain/task_models.dart';

void main() {
  testWidgets(
    'compact shell opens every primary destination without overflow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<TaskRepository>(
              create: (_) => _ShellTaskRepository(),
            ),
            RepositoryProvider<CityRepository>(
              create: (_) => const _ShellCityRepository(),
            ),
            RepositoryProvider<ProgressionRepository>(
              create: (_) => const _ShellProgressionRepository(),
            ),
          ],
          child: const TaskEmpireView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Сегодня строим империю'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _openDestination(tester, 'Календарь');
      expect(find.text('Планируйте путь вперёд'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _openDestination(tester, 'Город');
      expect(find.text('Город 1 уровня'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _openDestination(tester, 'Профиль');
      expect(find.text('ПРАВИТЕЛЬ ГОРОДА'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _openDestination(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

final class _ShellTaskRepository implements TaskRepository {
  final List<EmpireTask> _tasks = [
    EmpireTask(
      id: 'task-1',
      userId: 'user-1',
      title: 'Сделать главный шаг',
      description: 'Небольшой мобильный smoke test.',
      category: TaskCategory.personal,
      difficulty: TaskDifficulty.normal,
      scheduledDate: dateOnly(DateTime.now()),
      deadline: null,
      status: TaskStatus.pending,
      verificationMode: TaskVerificationMode.none,
      createdAt: DateTime.now(),
      completedAt: null,
    ),
  ];

  @override
  Future<EmpireTask> addTask(TaskDraft draft) async => _tasks.first;

  @override
  Future<TaskCompletionResult> completeTask(String taskId) async {
    return TaskCompletionResult(
      taskId: taskId,
      completedAt: DateTime.now(),
      xpAwarded: 25,
      goldAwarded: 15,
      totalXp: 25,
      totalGold: 115,
      level: 1,
    );
  }

  @override
  Future<void> deleteTask(String taskId) async {}

  @override
  Future<List<EmpireTask>> fetchTasks() async => _tasks;

  @override
  Future<EmpireTask> updateTask(String taskId, TaskDraft draft) async {
    return _tasks.first;
  }
}

final class _ShellCityRepository implements CityRepository {
  const _ShellCityRepository();

  CityStateData get _data => CityStateData.fromJson({
    'profile': {'gold': 100, 'xp': 25, 'level': 1, 'prosperity': 8},
    'city': {'map_level': 1, 'map_width': 8, 'map_height': 8},
    'buildings': [
      {
        ..._gardenDefinition,
        'id': 'garden-1',
        'position_x': 3,
        'position_y': 3,
        'rotation': 0,
      },
    ],
    'catalog': [_gardenDefinition],
  });

  @override
  Future<CityStateData> buildBuilding({
    required String code,
    required CityTileCoordinate position,
    required CityBuildingRotation rotation,
  }) async => _data;

  @override
  Future<CityStateData> fetchCity() async => _data;

  @override
  Future<CityStateData> moveBuilding({
    required String buildingId,
    required CityTileCoordinate position,
    required CityBuildingRotation rotation,
  }) async => _data;
}

const _gardenDefinition = <String, dynamic>{
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
};

final class _ShellProgressionRepository implements ProgressionRepository {
  const _ShellProgressionRepository();

  @override
  Future<ProgressionProfile> fetchProfile() async {
    return const ProgressionProfile(
      userId: 'user-1',
      isGuest: true,
      xp: 25,
      gold: 100,
      level: 1,
      xpIntoLevel: 25,
      xpForNextLevel: 100,
      completedTasks: 1,
      streak: 1,
    );
  }
}
