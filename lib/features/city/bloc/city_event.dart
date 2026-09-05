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

final class CityEditModeRequested extends CityEvent {
  const CityEditModeRequested();
}

final class CityViewModeRequested extends CityEvent {
  const CityViewModeRequested();
}

final class CityBuildModeRequested extends CityEvent {
  const CityBuildModeRequested(this.code);

  final String code;

  @override
  List<Object> get props => [code];
}

final class CityMoveModeRequested extends CityEvent {
  const CityMoveModeRequested(this.buildingId);

  final String buildingId;

  @override
  List<Object> get props => [buildingId];
}

final class CityTileTapped extends CityEvent {
  const CityTileTapped(this.tile);

  final CityTileCoordinate tile;

  @override
  List<Object> get props => [tile];
}

final class CityPlacementMoved extends CityEvent {
  const CityPlacementMoved(this.position);

  final CityTileCoordinate position;

  @override
  List<Object> get props => [position];
}

final class CityPlacementRotated extends CityEvent {
  const CityPlacementRotated();
}

final class CityPlacementCanceled extends CityEvent {
  const CityPlacementCanceled();
}

final class CityPlacementConfirmed extends CityEvent {
  const CityPlacementConfirmed();
}

/// Direct build command kept public for non-visual clients and BLoC tests.
final class CityBuildRequested extends CityEvent {
  const CityBuildRequested({
    required this.code,
    required this.position,
    this.rotation = CityBuildingRotation.north,
  });

  final String code;
  final CityTileCoordinate position;
  final CityBuildingRotation rotation;

  @override
  List<Object> get props => [code, position, rotation];
}

/// Direct move command kept public for non-visual clients and BLoC tests.
final class CityMoveRequested extends CityEvent {
  const CityMoveRequested({
    required this.buildingId,
    required this.position,
    required this.rotation,
  });

  final String buildingId;
  final CityTileCoordinate position;
  final CityBuildingRotation rotation;

  @override
  List<Object> get props => [buildingId, position, rotation];
}

/// Backwards-compatible dismissal intent: clears selection in view mode and
/// cancels the active placement everywhere else.
final class CityActionDismissed extends CityEvent {
  const CityActionDismissed();
}
