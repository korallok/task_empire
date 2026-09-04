import 'package:equatable/equatable.dart';
import 'package:task_empire/features/city/domain/city_building.dart';

final class CityProfile extends Equatable {
  const CityProfile({
    required this.gold,
    required this.prosperity,
    required this.dailyGoldEarned,
    required this.passiveGoldEarned,
    required this.incomePerHour,
  });

  factory CityProfile.fromJson(Map<String, dynamic> json) {
    final gold = json['gold'] as int;
    final prosperity = json['prosperity'] as int;
    final dailyGoldEarned = json['daily_gold_earned'] as int;
    final passiveGoldEarned = json['passive_gold_earned'] as int;
    final incomePerHour = json['income_per_hour'] as int;
    if (gold < 0 ||
        prosperity < 0 ||
        dailyGoldEarned < 0 ||
        passiveGoldEarned < 0 ||
        incomePerHour < 0) {
      throw const FormatException('Invalid city profile economy values.');
    }

    return CityProfile(
      gold: gold,
      prosperity: prosperity,
      dailyGoldEarned: dailyGoldEarned,
      passiveGoldEarned: passiveGoldEarned,
      incomePerHour: incomePerHour,
    );
  }

  final int gold;
  final int prosperity;
  final int dailyGoldEarned;
  final int passiveGoldEarned;
  final int incomePerHour;

  @override
  List<Object> get props => [
    gold,
    prosperity,
    dailyGoldEarned,
    passiveGoldEarned,
    incomePerHour,
  ];
}

final class CityCatalogItem extends Equatable {
  const CityCatalogItem({
    required this.type,
    required this.buildPrice,
    required this.incomePerHour,
    required this.prosperity,
    required this.maxLevel,
  });

  factory CityCatalogItem.fromJson(Map<String, dynamic> json) {
    final buildPrice = json['build_price'] as int;
    final incomePerHour = json['income_per_hour'] as int;
    final prosperity = json['prosperity'] as int;
    final maxLevel = json['max_level'] as int;
    if (buildPrice <= 0 ||
        incomePerHour < 0 ||
        prosperity < 0 ||
        maxLevel < 1) {
      throw const FormatException('Invalid city catalog economy values.');
    }

    return CityCatalogItem(
      type: CityBuildingType.fromDatabase(json['type'] as String),
      buildPrice: buildPrice,
      incomePerHour: incomePerHour,
      prosperity: prosperity,
      maxLevel: maxLevel,
    );
  }

  final CityBuildingType type;
  final int buildPrice;
  final int incomePerHour;
  final int prosperity;
  final int maxLevel;

  @override
  List<Object> get props => [
    type,
    buildPrice,
    incomePerHour,
    prosperity,
    maxLevel,
  ];
}

final class CityStateData extends Equatable {
  const CityStateData({
    required this.profile,
    required this.buildings,
    required this.catalog,
  });

  factory CityStateData.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'];
    final buildingRows = json['buildings'];
    final catalogRows = json['catalog'];
    if (profileJson is! Map || buildingRows is! List || catalogRows is! List) {
      throw const FormatException('Invalid city state shape.');
    }

    final buildings = buildingRows
        .map(
          (row) => CityBuilding.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
    final catalog = catalogRows
        .map(
          (row) =>
              CityCatalogItem.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
    for (final type in CityBuildingType.values) {
      if (catalog.where((item) => item.type == type).length != 1) {
        throw const FormatException('City catalog is incomplete.');
      }
    }
    if (catalog.length != CityBuildingType.values.length) {
      throw const FormatException('City catalog contains duplicate items.');
    }

    return CityStateData(
      profile: CityProfile.fromJson(Map<String, dynamic>.from(profileJson)),
      buildings: List.unmodifiable(buildings),
      catalog: List.unmodifiable(catalog),
    );
  }

  final CityProfile profile;
  final List<CityBuilding> buildings;
  final List<CityCatalogItem> catalog;

  CityBuilding? buildingAt(CityTileCoordinate tile) {
    for (final building in buildings) {
      if (building.tile == tile) return building;
    }
    return null;
  }

  CityCatalogItem catalogItem(CityBuildingType type) {
    return catalog.singleWhere((item) => item.type == type);
  }

  @override
  List<Object> get props => [profile, buildings, catalog];
}
