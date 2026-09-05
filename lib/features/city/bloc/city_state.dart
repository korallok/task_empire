part of 'city_bloc.dart';

enum CityMode { view, edit, build, move }

final class CityFeedback extends Equatable {
  const CityFeedback({
    required this.message,
    this.isError = false,
    this.id = 0,
  });

  final String message;
  final bool isError;
  final int id;

  @override
  List<Object> get props => [message, isError, id];
}

sealed class CityState extends Equatable {
  const CityState();

  CityStateData? get data => null;
  CityMode get mode => CityMode.view;
  CityPlacementPreview? get preview => null;
  String? get selectedBuildingId => null;
  CityTileCoordinate? get selectedTile => null;

  @override
  List<Object?> get props => [
    data,
    mode,
    preview,
    selectedBuildingId,
    selectedTile,
  ];
}

final class CityLoading extends CityState {
  const CityLoading({this.previousData});

  final CityStateData? previousData;

  @override
  CityStateData? get data => previousData;

  @override
  List<Object?> get props => [previousData];
}

final class CityDisplay extends CityState {
  const CityDisplay(
    this.cityData, {
    this.interactionMode = CityMode.view,
    this.placementPreview,
    this.activeBuildingId,
    this.activeTile,
    this.feedback,
  }) : assert(
         (interactionMode == CityMode.build ||
                 interactionMode == CityMode.move) ==
             (placementPreview != null),
       );

  final CityStateData cityData;
  final CityMode interactionMode;
  final CityPlacementPreview? placementPreview;
  final String? activeBuildingId;
  final CityTileCoordinate? activeTile;
  final CityFeedback? feedback;

  @override
  CityStateData get data => cityData;

  @override
  CityMode get mode => interactionMode;

  @override
  CityPlacementPreview? get preview => placementPreview;

  @override
  String? get selectedBuildingId => activeBuildingId;

  @override
  CityTileCoordinate? get selectedTile => activeTile;

  CityBuilding? get selectedBuilding => activeBuildingId == null
      ? null
      : cityData.buildingById(activeBuildingId!);

  @override
  List<Object?> get props => [
    cityData,
    interactionMode,
    placementPreview,
    activeBuildingId,
    activeTile,
    feedback,
  ];
}

final class CityOperationInProgress extends CityState {
  const CityOperationInProgress(
    this.cityData, {
    required this.message,
    required this.interactionMode,
    this.placementPreview,
    this.activeBuildingId,
    this.activeTile,
  });

  final CityStateData cityData;
  final String message;
  final CityMode interactionMode;
  final CityPlacementPreview? placementPreview;
  final String? activeBuildingId;
  final CityTileCoordinate? activeTile;

  @override
  CityStateData get data => cityData;

  @override
  CityMode get mode => interactionMode;

  @override
  CityPlacementPreview? get preview => placementPreview;

  @override
  String? get selectedBuildingId => activeBuildingId;

  @override
  CityTileCoordinate? get selectedTile => activeTile;

  @override
  List<Object?> get props => [
    cityData,
    message,
    interactionMode,
    placementPreview,
    activeBuildingId,
    activeTile,
  ];
}

final class CityFailure extends CityState {
  const CityFailure(this.message, {this.previousData});

  final String message;
  final CityStateData? previousData;

  @override
  CityStateData? get data => previousData;

  @override
  List<Object?> get props => [message, previousData];
}
