import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:task_empire/features/city/bloc/city_bloc.dart';
import 'package:task_empire/features/city/data/city_repository.dart';
import 'package:task_empire/features/city/domain/city_building.dart';
import 'package:task_empire/features/city/domain/city_state_data.dart';

void main() {
  test('rapid duplicate build request reaches repository only once', () async {
    final repository = _FakeCityRepository();
    final bloc = CityBloc(repository: repository);
    addTearDown(bloc.close);

    final loaded = bloc.stream.firstWhere((state) => state is CityDisplay);
    bloc.add(const CityStarted());
    await loaded;

    final buildGate = Completer<void>();
    repository.buildGate = buildGate;
    const position = CityTileCoordinate(2, 3);
    const request = CityBuildRequested(code: 'market', position: position);

    final operation = bloc.stream.firstWhere(
      (state) => state is CityOperationInProgress,
    );
    bloc.add(request);
    await operation;
    bloc.add(request);

    final finished = bloc.stream.firstWhere(
      (state) => state is CityDisplay && state.data.buildings.isNotEmpty,
    );
    buildGate.complete();
    final display = await finished as CityDisplay;
    await Future<void>.delayed(Duration.zero);

    expect(repository.buildCalls, 1);
    expect(display.data.buildingAt(position)?.code, 'market');
    expect(display.mode, CityMode.edit);
  });

  test('moving a building ignores its original footprint', () async {
    final repository = _FakeCityRepository(
      buildings: [_buildingRow(id: 'house-1', code: 'house', x: 0, y: 0)],
    );
    final bloc = CityBloc(repository: repository);
    addTearDown(bloc.close);

    final loaded = bloc.stream.firstWhere((state) => state is CityDisplay);
    bloc.add(const CityStarted());
    await loaded;

    const destination = CityTileCoordinate(3, 3);
    final finished = bloc.stream.firstWhere(
      (state) =>
          state is CityDisplay &&
          state.data.buildingById('house-1')?.position == destination,
    );
    bloc.add(
      const CityMoveRequested(
        buildingId: 'house-1',
        position: destination,
        rotation: CityBuildingRotation.east,
      ),
    );
    final display = await finished as CityDisplay;

    expect(repository.moveCalls, 1);
    expect(
      display.data.buildingById('house-1')?.rotation,
      CityBuildingRotation.east,
    );
  });

  test('city state parser rejects duplicate catalog entries', () {
    final json = _cityJson();
    json['catalog'] = [
      (json['catalog'] as List<Object?>).first,
      (json['catalog'] as List<Object?>).first,
    ];

    expect(() => CityStateData.fromJson(json), throwsFormatException);
  });

  test('migrated legacy buildings keep their level but stay non-buildable', () {
    final legacyDefinition = _definitionRow(
      'legacy_market',
      'Рынок',
      0,
      1,
      1,
      45,
      level: 3,
      spriteCode: 'market',
    );
    final json = _cityJson(
      buildings: [
        {
          ...legacyDefinition,
          'id': 'legacy-market-1',
          'position_x': 7,
          'position_y': 8,
          'rotation': 0,
        },
      ],
    );

    final data = CityStateData.fromJson(json);
    final building = data.buildingById('legacy-market-1')!;

    expect(building.level, 3);
    expect(building.definition.isLegacyImport, isTrue);
    expect(building.definition.visualCode, 'market');
    expect(building.type, CityBuildingType.market);
    expect(building.footprint.size, const CityFootprintSize(1, 1));
    expect(
      data.buildableDefinitions.any((definition) => definition.isLegacyImport),
      isFalse,
    );
  });

  test('placement validation checks bounds and rectangular overlap', () {
    final data = CityStateData.fromJson(
      _cityJson(
        buildings: [_buildingRow(id: 'market-1', code: 'market', x: 3, y: 3)],
      ),
    );
    final workshop = data.definitionForCode('workshop')!;

    expect(
      data
          .validatePlacement(
            definition: workshop,
            position: const CityTileCoordinate(2, 4),
            rotation: CityBuildingRotation.east,
          )
          .issue,
      CityPlacementIssue.overlap,
    );
    expect(
      data
          .validatePlacement(
            definition: workshop,
            position: const CityTileCoordinate(8, 8),
            rotation: CityBuildingRotation.north,
          )
          .issue,
      CityPlacementIssue.outOfBounds,
    );
  });
}

Map<String, dynamic> _cityJson({
  int gold = 200,
  List<Map<String, dynamic>> buildings = const [],
}) {
  return {
    'profile': {'gold': gold, 'xp': 180, 'level': 5, 'prosperity': 0},
    'city': {'map_level': 1, 'map_width': 10, 'map_height': 9},
    'buildings': buildings,
    'catalog': [
      _definitionRow('town_hall', 'Ратуша', 60, 4, 4, 40),
      _definitionRow('house', 'Дом', 15, 2, 2, 10),
      _definitionRow('library', 'Библиотека', 45, 3, 3, 25),
      _definitionRow('workshop', 'Мастерская', 60, 3, 2, 30),
      _definitionRow('market', 'Рынок', 75, 3, 3, 35),
      _definitionRow('tower', 'Башня', 100, 2, 2, 45),
      _definitionRow('garden', 'Сад', 10, 2, 2, 8),
    ],
  };
}

Map<String, dynamic> _definitionRow(
  String code,
  String name,
  int price,
  int width,
  int height,
  int prosperity, {
  int level = 1,
  String? spriteCode,
}) {
  return {
    'id': 'definition-$code-$level',
    'code': code,
    'name': name,
    'level': level,
    'price': price,
    'required_player_level': 1,
    'sprite': 'assets/city/buildings/${spriteCode ?? code}_level_$level.webp',
    'footprint_width': width,
    'footprint_height': height,
    'prosperity': prosperity,
  };
}

Map<String, dynamic> _buildingRow({
  required String id,
  required String code,
  required int x,
  required int y,
  int rotation = 0,
}) {
  final definitions = <String, Map<String, dynamic>>{
    'house': _definitionRow('house', 'Дом', 15, 2, 2, 10),
    'market': _definitionRow('market', 'Рынок', 75, 3, 3, 35),
  };
  return {
    ...definitions[code]!,
    'id': id,
    'position_x': x,
    'position_y': y,
    'rotation': rotation,
  };
}

final class _FakeCityRepository implements CityRepository {
  _FakeCityRepository({List<Map<String, dynamic>> buildings = const []})
    : _buildings = [...buildings];

  final List<Map<String, dynamic>> _buildings;
  Completer<void>? buildGate;
  var buildCalls = 0;
  var moveCalls = 0;
  var _gold = 200;

  CityStateData get _data =>
      CityStateData.fromJson(_cityJson(gold: _gold, buildings: _buildings));

  @override
  Future<CityStateData> buildBuilding({
    required String code,
    required CityTileCoordinate position,
    required CityBuildingRotation rotation,
  }) async {
    buildCalls += 1;
    await buildGate?.future;
    final definition = (_cityJson()['catalog'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((row) => row['code'] == code);
    _gold -= definition['price'] as int;
    _buildings.add({
      ...definition,
      'id': 'building-$buildCalls',
      'position_x': position.x,
      'position_y': position.y,
      'rotation': rotation.degrees,
    });
    return _data;
  }

  @override
  Future<CityStateData> fetchCity() async => _data;

  @override
  Future<CityStateData> moveBuilding({
    required String buildingId,
    required CityTileCoordinate position,
    required CityBuildingRotation rotation,
  }) async {
    moveCalls += 1;
    final index = _buildings.indexWhere((row) => row['id'] == buildingId);
    _buildings[index] = {
      ..._buildings[index],
      'position_x': position.x,
      'position_y': position.y,
      'rotation': rotation.degrees,
    };
    return _data;
  }
}
