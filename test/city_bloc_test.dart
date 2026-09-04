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

    bloc.add(const CityStarted());
    await bloc.stream.firstWhere((state) => state is CityDisplay);

    const tile = CityTileCoordinate(2, 3);
    bloc.add(const CityTileTapped(tile));
    await bloc.stream.firstWhere((state) => state is CityActionRequired);

    final buildGate = Completer<void>();
    repository.buildGate = buildGate;
    bloc.add(
      const CityBuildRequested(type: CityBuildingType.market, tile: tile),
    );
    await bloc.stream.firstWhere((state) => state is CityOperationInProgress);

    bloc.add(
      const CityBuildRequested(type: CityBuildingType.market, tile: tile),
    );
    buildGate.complete();
    final display =
        await bloc.stream.firstWhere(
              (state) =>
                  state is CityDisplay && state.data.buildings.isNotEmpty,
            )
            as CityDisplay;
    await Future<void>.delayed(Duration.zero);

    expect(repository.buildCalls, 1);
    expect(display.data.buildingAt(tile)?.type, CityBuildingType.market);
  });

  test('city state parser rejects duplicate catalog entries', () {
    final json = _cityJson();
    json['catalog'] = [
      (json['catalog'] as List<Object?>).first,
      (json['catalog'] as List<Object?>).first,
    ];

    expect(() => CityStateData.fromJson(json), throwsFormatException);
  });
}

Map<String, dynamic> _cityJson({
  List<Map<String, dynamic>> buildings = const [],
}) {
  return {
    'profile': {
      'gold': 100,
      'prosperity': 0,
      'daily_gold_earned': 0,
      'passive_gold_earned': 0,
      'income_per_hour': 0,
    },
    'buildings': buildings,
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
  };
}

final class _FakeCityRepository implements CityRepository {
  var _data = CityStateData.fromJson(_cityJson());
  Completer<void>? buildGate;
  var buildCalls = 0;

  @override
  Future<void> buildBuilding({
    required CityBuildingType type,
    required CityTileCoordinate tile,
  }) async {
    buildCalls += 1;
    await buildGate?.future;
    _data = CityStateData.fromJson(
      _cityJson(
        buildings: [
          {
            'id': 'building-1',
            'type': type.databaseValue,
            'level': 1,
            'iso_x': tile.x,
            'iso_y': tile.y,
            'income_per_hour': type == CityBuildingType.market ? 5 : 12,
            'prosperity': type == CityBuildingType.market ? 15 : 40,
            'upgrade_cost': type == CityBuildingType.market ? 350 : 875,
            'max_level': 5,
          },
        ],
      ),
    );
  }

  @override
  Future<CityStateData> fetchCity() async => _data;

  @override
  Future<void> upgradeBuilding(String buildingId) async {}
}
