part of 'city_bloc.dart';

sealed class CityEvent extends Equatable {
  const CityEvent();

  @override
  List<Object?> get props => const [];
}

final class CityStarted extends CityEvent {
  const CityStarted();
}

final class CityRefreshRequested extends CityEvent {
  const CityRefreshRequested();
}

final class CityTileTapped extends CityEvent {
  const CityTileTapped(this.tile);

  final CityTileCoordinate tile;

  @override
  List<Object> get props => [tile];
}

final class CityActionDismissed extends CityEvent {
  const CityActionDismissed();
}

final class CityBuildRequested extends CityEvent {
  const CityBuildRequested({required this.type, required this.tile});

  final CityBuildingType type;
  final CityTileCoordinate tile;

  @override
  List<Object> get props => [type, tile];
}

final class CityUpgradeRequested extends CityEvent {
  const CityUpgradeRequested(this.buildingId);

  final String buildingId;

  @override
  List<Object> get props => [buildingId];
}
