import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_empire/features/city/domain/city_building.dart';
import 'package:task_empire/features/city/presentation/city_building_art.dart';
import 'package:task_empire/features/city/presentation/isometric_city_view.dart';
import 'package:task_empire/features/city/presentation/isometric_projection.dart';

void main() {
  test(
    'isometric projection maps every rectangular-map tile back to itself',
    () {
      const projection = IsometricProjection(
        tileWidth: 104,
        tileHeight: 52,
        origin: Offset(520, 224),
        width: 10,
        height: 6,
      );

      for (var x = 0; x < projection.width; x++) {
        for (var y = 0; y < projection.height; y++) {
          final tile = CityTileCoordinate(x, y);
          expect(projection.tileAt(projection.tileCenter(x, y)), tile);
        }
      }
    },
  );

  test('building art follows Blender export naming conventions', () {
    final art = CityBuildingArt.forBuilding(_market);
    final legacyArt = CityBuildingArt.forDefinition(_legacyMarketDefinition);

    expect(art.key, contains('market:1'));
    expect(
      art.candidateAssetPaths,
      contains('assets/city/buildings/market_level_1.png'),
    );
    expect(art.pivot.dx, inInclusiveRange(0, 1));
    expect(art.pivot.dy, inInclusiveRange(0, 1));
    expect(
      legacyArt.candidateAssetPaths,
      contains('assets/city/buildings/market_level_3.png'),
    );
  });

  testWidgets('city scene can be panned and returned to its centre', (
    tester,
  ) async {
    final controller = TransformationController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            child: IsometricCityView(
              buildings: const [_market],
              onTileTap: (_) {},
              transformationController: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initialTranslation = controller.value.getTranslation();
    await tester.drag(
      find.byKey(const ValueKey('city-interactive-view')),
      const Offset(72, 38),
    );
    await tester.pumpAndSettle();

    final pannedTranslation = controller.value.getTranslation();
    expect(pannedTranslation.x, isNot(closeTo(initialTranslation.x, 0.1)));
    expect(pannedTranslation.y, isNot(closeTo(initialTranslation.y, 0.1)));

    await tester.tap(find.byKey(const ValueKey('city-reset-view')));
    await tester.pump();

    final resetTranslation = controller.value.getTranslation();
    expect(resetTranslation.x, closeTo(initialTranslation.x, 0.1));
    expect(resetTranslation.y, closeTo(initialTranslation.y, 0.1));
  });
}

const _marketDefinition = BuildingDefinition(
  id: 'definition-market',
  code: 'market',
  name: 'Рынок',
  level: 1,
  price: 75,
  requiredPlayerLevel: 1,
  sprite: 'assets/city/buildings/market_level_1.webp',
  footprintWidth: 3,
  footprintHeight: 3,
  prosperity: 35,
);

const _market = CityBuilding(
  id: 'market-1',
  definition: _marketDefinition,
  position: CityTileCoordinate(4, 4),
  rotation: CityBuildingRotation.north,
);

const _legacyMarketDefinition = BuildingDefinition(
  id: 'definition-legacy-market-3',
  code: 'legacy_market',
  name: 'Рынок',
  level: 3,
  price: 0,
  requiredPlayerLevel: 1,
  sprite: 'assets/city/buildings/market_level_3.webp',
  footprintWidth: 1,
  footprintHeight: 1,
  prosperity: 45,
);
