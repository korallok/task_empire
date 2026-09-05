import 'package:equatable/equatable.dart';
import 'package:task_empire/features/city/domain/city_building.dart';

final class CityProfile extends Equatable {
  const CityProfile({
    required this.gold,
    required this.xp,
    required this.level,
    required this.prosperity,
  }) : assert(gold >= 0),
       assert(xp >= 0),
       assert(level >= 1),
       assert(prosperity >= 0);

  factory CityProfile.fromJson(Map<String, dynamic> json) {
    final gold = _readInt(json, 'gold');
    final xp = _readInt(json, 'xp');
    final level = _readInt(json, 'level');
    final prosperity = _readInt(json, 'prosperity');
    if (gold < 0 || xp < 0 || level < 1 || prosperity < 0) {
      throw const FormatException('Invalid city profile values.');
    }

    return CityProfile(
      gold: gold,
      xp: xp,
      level: level,
      prosperity: prosperity,
    );
  }

  final int gold;
  final int xp;
  final int level;
  final int prosperity;

  @override
  List<Object> get props => [gold, xp, level, prosperity];
}

final class CityStateData extends Equatable {
  const CityStateData({
    required this.profile,
    required this.city,
    required this.buildings,
    required this.catalog,
  });

  factory CityStateData.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'];
    final cityJson = json['city'];
    final buildingRows = json['buildings'];
    final catalogRows = json['catalog'];
    if (profileJson is! Map ||
        cityJson is! Map ||
        buildingRows is! List ||
        catalogRows is! List) {
      throw const FormatException('Invalid city state shape.');
    }

    final profile = CityProfile.fromJson(
      Map<String, dynamic>.from(profileJson),
    );
    final city = CityMap.fromJson(Map<String, dynamic>.from(cityJson));
    final catalog = <BuildingDefinition>[];
    final catalogKeys = <String>{};
    final catalogIds = <String>{};
    for (final row in catalogRows) {
      if (row is! Map) {
        throw const FormatException('Invalid city catalog row.');
      }
      final definition = BuildingDefinition.fromJson(
        Map<String, dynamic>.from(row),
      );
      final key = '${definition.code}:${definition.level}';
      if (!catalogKeys.add(key) || !catalogIds.add(definition.id)) {
        throw const FormatException('City catalog contains duplicate items.');
      }
      catalog.add(definition);
    }

    final definitionsByKey = {
      for (final definition in catalog)
        '${definition.code}:${definition.level}': definition,
    };
    final buildings = <CityBuilding>[];
    final buildingIds = <String>{};
    for (final row in buildingRows) {
      if (row is! Map) {
        throw const FormatException('Invalid city building row.');
      }
      final values = Map<String, dynamic>.from(row);
      final code = values['code'];
      final level = values['level'];
      if (code is! String || level is! int) {
        throw const FormatException('Invalid city building definition.');
      }
      final normalizedCode = code.trim().toLowerCase();
      final catalogDefinition = definitionsByKey['$normalizedCode:$level'];
      if (catalogDefinition == null && !normalizedCode.startsWith('legacy_')) {
        throw FormatException(
          'Building definition is missing from catalog: $code:$level.',
        );
      }
      final definition =
          catalogDefinition ?? BuildingDefinition.fromJson(values);
      final building = CityBuilding.fromJson(values, definition: definition);
      if (!buildingIds.add(building.id)) {
        throw const FormatException('City contains duplicate buildings.');
      }
      buildings.add(building);
    }

    _validateLayout(city, buildings);

    return CityStateData(
      profile: profile,
      city: city,
      buildings: List.unmodifiable(buildings),
      catalog: List.unmodifiable(catalog),
    );
  }

  final CityProfile profile;
  final CityMap city;
  final List<CityBuilding> buildings;
  final List<BuildingDefinition> catalog;

  /// Definitions accepted by the v2 build RPC.
  ///
  /// The server currently purchases level-one rows only. The construction
  /// catalog may still contain future levels so they can render dynamically.
  List<BuildingDefinition> get buildableDefinitions => List.unmodifiable(
    catalog.where(
      (definition) => definition.level == 1 && !definition.isLegacyImport,
    ),
  );

  BuildingDefinition? definitionForCode(String code, {int level = 1}) {
    for (final definition in catalog) {
      if (definition.code == code && definition.level == level) {
        return definition;
      }
    }
    return null;
  }

  CityBuilding? buildingById(String id) {
    for (final building in buildings) {
      if (building.id == id) return building;
    }
    return null;
  }

  CityBuilding? buildingAt(CityTileCoordinate tile) {
    final ordered = [...buildings]
      ..sort((left, right) {
        final leftFootprint = left.footprint;
        final rightFootprint = right.footprint;
        final depth = (rightFootprint.baseX + rightFootprint.baseY).compareTo(
          leftFootprint.baseX + leftFootprint.baseY,
        );
        if (depth != 0) return depth;
        return right.id.compareTo(left.id);
      });
    for (final building in ordered) {
      if (building.footprint.contains(tile)) return building;
    }
    return null;
  }

  CityPlacementValidation validatePlacement({
    required BuildingDefinition definition,
    required CityTileCoordinate position,
    required CityBuildingRotation rotation,
    String? movingBuildingId,
  }) {
    return CityPlacementValidator.validate(
      city: city,
      definition: definition,
      position: position,
      rotation: rotation,
      buildings: buildings,
      movingBuildingId: movingBuildingId,
    );
  }

  @override
  List<Object> get props => [profile, city, buildings, catalog];
}

void _validateLayout(CityMap city, List<CityBuilding> buildings) {
  for (var index = 0; index < buildings.length; index++) {
    final building = buildings[index];
    final validation = CityPlacementValidator.validate(
      city: city,
      definition: building.definition,
      position: building.position,
      rotation: building.rotation,
      buildings: buildings.take(index),
    );
    if (!validation.isValid) {
      throw FormatException(
        'Invalid city building placement for ${building.id}: '
        '${validation.issue?.name}.',
      );
    }
  }
}

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('Expected integer field "$key".');
}
