import 'package:equatable/equatable.dart';

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
    return switch (value) {
      'town_hall' => CityBuildingType.townHall,
      'market' => CityBuildingType.market,
      _ => throw FormatException('Unknown building type: $value'),
    };
  }
}

final class CityTileCoordinate extends Equatable {
  const CityTileCoordinate(this.x, this.y)
    : assert(x >= 0 && x < gridSize),
      assert(y >= 0 && y < gridSize);

  static const gridSize = 8;

  final int x;
  final int y;

  @override
  List<Object> get props => [x, y];

  @override
  String toString() => 'CityTileCoordinate(x: $x, y: $y)';
}

final class CityBuilding extends Equatable {
  const CityBuilding({
    required this.id,
    required this.type,
    required this.level,
    required this.tile,
    required this.incomePerHour,
    required this.prosperity,
    required this.upgradeCost,
    required this.maxLevel,
  }) : assert(level > 0),
       assert(incomePerHour >= 0),
       assert(prosperity >= 0),
       assert(maxLevel >= level);

  factory CityBuilding.fromJson(Map<String, dynamic> json) {
    final level = json['level'] as int;
    final x = json['iso_x'] as int;
    final y = json['iso_y'] as int;
    final incomePerHour = json['income_per_hour'] as int;
    final prosperity = json['prosperity'] as int;
    final upgradeCost = json['upgrade_cost'] as int?;
    final maxLevel = json['max_level'] as int;

    if (level < 1) {
      throw const FormatException('Building level must be positive.');
    }
    if (x < 0 ||
        x >= CityTileCoordinate.gridSize ||
        y < 0 ||
        y >= CityTileCoordinate.gridSize) {
      throw const FormatException(
        'Building coordinates are outside the city grid.',
      );
    }
    if (incomePerHour < 0 || prosperity < 0 || maxLevel < level) {
      throw const FormatException('Invalid building economy values.');
    }
    if (level < maxLevel && (upgradeCost == null || upgradeCost <= 0)) {
      throw const FormatException('Missing building upgrade cost.');
    }
    if (level >= maxLevel && upgradeCost != null) {
      throw const FormatException('Max-level building has an upgrade cost.');
    }

    return CityBuilding(
      id: json['id'] as String,
      type: CityBuildingType.fromDatabase(json['type'] as String),
      level: level,
      tile: CityTileCoordinate(x, y),
      incomePerHour: incomePerHour,
      prosperity: prosperity,
      upgradeCost: upgradeCost,
      maxLevel: maxLevel,
    );
  }

  final String id;
  final CityBuildingType type;
  final int level;
  final CityTileCoordinate tile;
  final int incomePerHour;
  final int prosperity;
  final int? upgradeCost;
  final int maxLevel;

  bool get isMaxLevel => level >= maxLevel || upgradeCost == null;

  @override
  List<Object?> get props => [
    id,
    type,
    level,
    tile,
    incomePerHour,
    prosperity,
    upgradeCost,
    maxLevel,
  ];
}
