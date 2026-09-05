import 'package:equatable/equatable.dart';

/// Legacy bridge for preview tools that still refer to the original two types.
/// New city code uses the server-provided [BuildingDefinition.code] instead.
enum CityBuildingType {
  townHall,
  market;

  String get databaseValue => switch (this) {
    CityBuildingType.townHall => 'town_hall',
    CityBuildingType.market => 'market',
  };

  String get displayName => switch (this) {
    CityBuildingType.townHall => 'Ратуша',
    CityBuildingType.market => 'Рынок',
  };

  static CityBuildingType fromDatabase(String value) {
    final result = tryFromDatabase(value);
    if (result == null) {
      throw FormatException('Unknown legacy building type: $value');
    }
    return result;
  }

  static CityBuildingType? tryFromDatabase(String value) {
    return switch (value) {
      'town_hall' => CityBuildingType.townHall,
      'market' => CityBuildingType.market,
      _ => null,
    };
  }
}

enum CityBuildingRotation {
  north(0),
  east(90),
  south(180),
  west(270);

  const CityBuildingRotation(this.degrees);

  factory CityBuildingRotation.fromDegrees(int degrees) {
    return CityBuildingRotation.values.firstWhere(
      (rotation) => rotation.degrees == degrees,
      orElse: () =>
          throw FormatException('Unsupported building rotation: $degrees'),
    );
  }

  final int degrees;

  bool get swapsFootprint => this == east || this == west;

  CityBuildingRotation get clockwise {
    final index =
        (CityBuildingRotation.values.indexOf(this) + 1) %
        CityBuildingRotation.values.length;
    return CityBuildingRotation.values[index];
  }
}

final class CityTileCoordinate extends Equatable {
  const CityTileCoordinate(this.x, this.y);

  /// Kept only for older previews. V2 uses [CityMap.width]/[CityMap.height].
  static const gridSize = 8;

  final int x;
  final int y;

  CityTileCoordinate translate(int dx, int dy) {
    return CityTileCoordinate(x + dx, y + dy);
  }

  @override
  List<Object> get props => [x, y];

  @override
  String toString() => 'CityTileCoordinate(x: $x, y: $y)';
}

final class CityMap extends Equatable {
  const CityMap({
    required this.level,
    required this.width,
    required this.height,
  }) : assert(level > 0),
       assert(width > 0),
       assert(height > 0);

  factory CityMap.fromJson(Map<String, dynamic> json) {
    final level = _readInt(json, 'map_level');
    final width = _readInt(json, 'map_width');
    final height = _readInt(json, 'map_height');
    if (level < 1 || width < 1 || height < 1) {
      throw const FormatException('Invalid city map dimensions.');
    }
    return CityMap(level: level, width: width, height: height);
  }

  static const legacy = CityMap(level: 1, width: 8, height: 8);

  final int level;
  final int width;
  final int height;

  bool contains(CityTileCoordinate tile) {
    return tile.x >= 0 && tile.y >= 0 && tile.x < width && tile.y < height;
  }

  @override
  List<Object> get props => [level, width, height];
}

final class CityFootprintSize extends Equatable {
  const CityFootprintSize(this.width, this.height)
    : assert(width > 0),
      assert(height > 0);

  final int width;
  final int height;

  @override
  List<Object> get props => [width, height];
}

final class CityFootprint extends Equatable {
  const CityFootprint({required this.origin, required this.size});

  final CityTileCoordinate origin;
  final CityFootprintSize size;

  int get left => origin.x;
  int get top => origin.y;
  int get right => origin.x + size.width;
  int get bottom => origin.y + size.height;
  int get baseX => right - 1;
  int get baseY => bottom - 1;
  int get depth => baseX + baseY;
  double get centerX => left + (size.width - 1) / 2;
  double get centerY => top + (size.height - 1) / 2;

  bool contains(CityTileCoordinate tile) {
    return tile.x >= left && tile.x < right && tile.y >= top && tile.y < bottom;
  }

  bool overlaps(CityFootprint other) {
    return left < other.right &&
        right > other.left &&
        top < other.bottom &&
        bottom > other.top;
  }

  Iterable<CityTileCoordinate> get tiles sync* {
    for (var x = left; x < right; x++) {
      for (var y = top; y < bottom; y++) {
        yield CityTileCoordinate(x, y);
      }
    }
  }

  @override
  List<Object> get props => [origin, size];
}

final class BuildingDefinition extends Equatable {
  const BuildingDefinition({
    required this.id,
    required this.code,
    required this.name,
    required this.level,
    required this.price,
    required this.requiredPlayerLevel,
    required this.sprite,
    required this.footprintWidth,
    required this.footprintHeight,
    required this.prosperity,
  }) : assert(level > 0),
       assert(price >= 0),
       assert(requiredPlayerLevel > 0),
       assert(footprintWidth > 0),
       assert(footprintHeight > 0),
       assert(prosperity >= 0);

  factory BuildingDefinition.fromJson(Map<String, dynamic> json) {
    final codeValue = json['code'] ?? json['type'];
    if (codeValue is! String || codeValue.trim().isEmpty) {
      throw const FormatException('Building definition has no code.');
    }
    final code = codeValue.trim().toLowerCase();
    final level = _readInt(json, 'level', fallback: 1);
    final legacyType = CityBuildingType.tryFromDatabase(code);
    final nameValue = json['name'];
    final name = nameValue is String && nameValue.trim().isNotEmpty
        ? nameValue.trim()
        : legacyType?.displayName ?? code;
    final price = _readInt(
      json,
      'price',
      fallback: _readInt(json, 'build_price', fallback: 0),
    );
    final requiredLevel = _readInt(json, 'required_player_level', fallback: 1);
    final footprintWidth = _readInt(json, 'footprint_width', fallback: 1);
    final footprintHeight = _readInt(json, 'footprint_height', fallback: 1);
    final prosperity = _readInt(json, 'prosperity', fallback: 0);
    final idValue = json['definition_id'] ?? json['building_definition_id'];
    final id = idValue is String && idValue.isNotEmpty
        ? idValue
        : json['position_x'] == null && json['iso_x'] == null
        ? (json['id'] as String? ?? 'definition:$code:$level')
        : 'definition:$code:$level';
    final spriteValue = json['sprite'];
    final sprite = spriteValue is String && spriteValue.trim().isNotEmpty
        ? spriteValue.trim()
        : 'assets/city/buildings/${code}_level_$level.webp';

    if (level < 1 ||
        price < 0 ||
        requiredLevel < 1 ||
        footprintWidth < 1 ||
        footprintHeight < 1 ||
        prosperity < 0) {
      throw const FormatException('Invalid building definition values.');
    }

    return BuildingDefinition(
      id: id,
      code: code,
      name: name,
      level: level,
      price: price,
      requiredPlayerLevel: requiredLevel,
      sprite: sprite,
      footprintWidth: footprintWidth,
      footprintHeight: footprintHeight,
      prosperity: prosperity,
    );
  }

  final String id;
  final String code;
  final String name;
  final int level;
  final int price;
  final int requiredPlayerLevel;
  final String sprite;
  final int footprintWidth;
  final int footprintHeight;
  final int prosperity;

  bool get isLegacyImport => code.startsWith('legacy_');

  String get visualCode =>
      isLegacyImport ? code.substring('legacy_'.length) : code;

  bool isUnlockedAt(int playerLevel) => playerLevel >= requiredPlayerLevel;

  CityFootprintSize footprintSize(CityBuildingRotation rotation) {
    return rotation.swapsFootprint
        ? CityFootprintSize(footprintHeight, footprintWidth)
        : CityFootprintSize(footprintWidth, footprintHeight);
  }

  CityFootprint footprintAt(
    CityTileCoordinate position,
    CityBuildingRotation rotation,
  ) {
    return CityFootprint(origin: position, size: footprintSize(rotation));
  }

  @override
  List<Object> get props => [
    id,
    code,
    name,
    level,
    price,
    requiredPlayerLevel,
    sprite,
    footprintWidth,
    footprintHeight,
    prosperity,
  ];
}

final class CityBuilding extends Equatable {
  const CityBuilding({
    required this.id,
    required this.definition,
    required this.position,
    required this.rotation,
  });

  factory CityBuilding.fromJson(
    Map<String, dynamic> json, {
    BuildingDefinition? definition,
  }) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('City building has no id.');
    }
    final positionX = _readFirstInt(json, 'position_x', 'iso_x');
    final positionY = _readFirstInt(json, 'position_y', 'iso_y');
    final rotation = CityBuildingRotation.fromDegrees(
      _readInt(json, 'rotation', fallback: 0),
    );

    return CityBuilding(
      id: id,
      definition: definition ?? BuildingDefinition.fromJson(json),
      position: CityTileCoordinate(positionX, positionY),
      rotation: rotation,
    );
  }

  final String id;
  final BuildingDefinition definition;
  final CityTileCoordinate position;
  final CityBuildingRotation rotation;

  String get code => definition.code;
  String get name => definition.name;
  int get level => definition.level;
  int get prosperity => definition.prosperity;
  CityFootprint get footprint => definition.footprintAt(position, rotation);
  int get depth => footprint.depth;

  /// Compatibility aliases used by the old preview and renderer tests.
  CityTileCoordinate get tile => position;
  CityBuildingType? get type =>
      CityBuildingType.tryFromDatabase(definition.visualCode);

  CityBuilding copyWith({
    CityTileCoordinate? position,
    CityBuildingRotation? rotation,
  }) {
    return CityBuilding(
      id: id,
      definition: definition,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  List<Object> get props => [id, definition, position, rotation];
}

enum CityPlacementIssue { outOfBounds, overlap }

final class CityPlacementValidation extends Equatable {
  const CityPlacementValidation.valid() : issue = null;
  const CityPlacementValidation.invalid(this.issue);

  final CityPlacementIssue? issue;

  bool get isValid => issue == null;

  String get message => switch (issue) {
    CityPlacementIssue.outOfBounds => 'Здание выходит за границы города.',
    CityPlacementIssue.overlap => 'Здание пересекается с другой постройкой.',
    null => 'Позиция подходит для строительства.',
  };

  @override
  List<Object?> get props => [issue];
}

final class CityPlacementPreview extends Equatable {
  const CityPlacementPreview({
    required this.definition,
    required this.position,
    required this.rotation,
    required this.validation,
    this.movingBuildingId,
  });

  final BuildingDefinition definition;
  final CityTileCoordinate position;
  final CityBuildingRotation rotation;
  final CityPlacementValidation validation;
  final String? movingBuildingId;

  CityFootprint get footprint => definition.footprintAt(position, rotation);

  CityPlacementPreview copyWith({
    CityTileCoordinate? position,
    CityBuildingRotation? rotation,
    CityPlacementValidation? validation,
  }) {
    return CityPlacementPreview(
      definition: definition,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      validation: validation ?? this.validation,
      movingBuildingId: movingBuildingId,
    );
  }

  @override
  List<Object?> get props => [
    definition,
    position,
    rotation,
    validation,
    movingBuildingId,
  ];
}

abstract final class CityPlacementValidator {
  static CityPlacementValidation validate({
    required CityMap city,
    required BuildingDefinition definition,
    required CityTileCoordinate position,
    required CityBuildingRotation rotation,
    required Iterable<CityBuilding> buildings,
    String? movingBuildingId,
  }) {
    final footprint = definition.footprintAt(position, rotation);
    if (footprint.left < 0 ||
        footprint.top < 0 ||
        footprint.right > city.width ||
        footprint.bottom > city.height) {
      return const CityPlacementValidation.invalid(
        CityPlacementIssue.outOfBounds,
      );
    }

    for (final building in buildings) {
      if (building.id == movingBuildingId) continue;
      if (footprint.overlaps(building.footprint)) {
        return const CityPlacementValidation.invalid(
          CityPlacementIssue.overlap,
        );
      }
    }
    return const CityPlacementValidation.valid();
  }
}

int _readInt(Map<String, dynamic> json, String key, {int? fallback}) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  if (fallback != null) return fallback;
  throw FormatException('Expected integer field "$key".');
}

int _readFirstInt(Map<String, dynamic> json, String primary, String fallback) {
  if (json[primary] != null) return _readInt(json, primary);
  return _readInt(json, fallback);
}
