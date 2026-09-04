import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:task_empire/features/city/domain/city_building.dart';

/// Rendering metadata shared by the Flutter city scene and Blender exports.
final class CityBuildingArtSpec {
  const CityBuildingArtSpec({
    required this.key,
    required this.candidateAssetPaths,
    required this.renderWidthInTiles,
    required this.pivot,
  });

  final String key;
  final List<String> candidateAssetPaths;

  /// Width of the square transparent render relative to an isometric tile.
  final double renderWidthInTiles;

  /// Point inside the square render that must land on the tile centre.
  final Offset pivot;
}

abstract final class CityBuildingArt {
  static const assetRoot = 'assets/city/buildings';

  static CityBuildingArtSpec forBuilding(CityBuilding building) {
    final stem =
        '${building.type.databaseValue}_level_${building.level.clamp(1, 99)}';
    return CityBuildingArtSpec(
      key: stem,
      candidateAssetPaths: ['$assetRoot/$stem.webp', '$assetRoot/$stem.png'],
      renderWidthInTiles: switch (building.type) {
        CityBuildingType.townHall => 2.55,
        CityBuildingType.market => 2.25,
      },
      pivot: switch (building.type) {
        CityBuildingType.townHall => const Offset(0.5, 0.78),
        CityBuildingType.market => const Offset(0.5, 0.76),
      },
    );
  }

  static Future<Map<String, ui.Image>> loadAvailableSprites({
    required AssetBundle bundle,
    required Iterable<CityBuilding> buildings,
  }) async {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final availableAssets = manifest.listAssets().toSet();
    final specs = <String, CityBuildingArtSpec>{};
    for (final building in buildings) {
      final spec = forBuilding(building);
      specs[spec.key] = spec;
    }

    final sprites = <String, ui.Image>{};
    for (final spec in specs.values) {
      final path = spec.candidateAssetPaths
          .where(availableAssets.contains)
          .firstOrNull;
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
    return sprites;
  }
}
