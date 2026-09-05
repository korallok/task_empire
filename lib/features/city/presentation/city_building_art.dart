import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:task_empire/features/city/domain/city_building.dart';

/// Sprite metadata shared by the scene and the Blender export convention.
final class CityBuildingArtSpec {
  const CityBuildingArtSpec({
    required this.key,
    required this.candidateAssetPaths,
    required this.renderWidthInTiles,
    required this.pivot,
  });

  final String key;
  final List<String> candidateAssetPaths;
  final double renderWidthInTiles;
  final Offset pivot;
}

abstract final class CityBuildingArt {
  static const assetRoot = 'assets/city/buildings';

  static CityBuildingArtSpec forBuilding(CityBuilding building) {
    return forDefinition(building.definition);
  }

  static CityBuildingArtSpec forDefinition(BuildingDefinition definition) {
    final stem = '${definition.visualCode}_level_${definition.level}';
    final paths = <String>[
      definition.sprite,
      '$assetRoot/$stem.webp',
      '$assetRoot/$stem.png',
      'assets/city/$stem.webp',
      'assets/city/$stem.png',
    ];
    return CityBuildingArtSpec(
      key: '${definition.code}:${definition.level}:${definition.sprite}',
      candidateAssetPaths: List.unmodifiable(paths.toSet()),
      renderWidthInTiles:
          math.max(definition.footprintWidth, definition.footprintHeight) + 1.2,
      pivot: const Offset(0.5, 0.78),
    );
  }

  static Future<Map<String, ui.Image>> loadAvailableSprites({
    required AssetBundle bundle,
    required Iterable<CityBuilding> buildings,
    Iterable<BuildingDefinition> additionalDefinitions = const [],
  }) async {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final availableAssets = manifest.listAssets().toSet();
    final specs = <String, CityBuildingArtSpec>{};
    for (final building in buildings) {
      final spec = forBuilding(building);
      specs[spec.key] = spec;
    }
    for (final definition in additionalDefinitions) {
      final spec = forDefinition(definition);
      specs[spec.key] = spec;
    }

    final sprites = <String, ui.Image>{};
    for (final spec in specs.values) {
      String? path;
      for (final candidate in spec.candidateAssetPaths) {
        if (availableAssets.contains(candidate)) {
          path = candidate;
          break;
        }
      }
      if (path == null) continue;

      try {
        final bytes = await bundle.load(path);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        try {
          sprites[spec.key] = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      } on Exception catch (error) {
        debugPrint('Could not load city sprite "$path": $error');
      }
    }
    return Map.unmodifiable(sprites);
  }
}
