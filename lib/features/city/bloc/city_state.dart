part of 'city_bloc.dart';

final class CityFeedback extends Equatable {
  const CityFeedback({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  List<Object> get props => [message, isError];
}

sealed class CityState extends Equatable {
  const CityState();

  CityStateData? get data => null;

  @override
  List<Object?> get props => [data];
}

final class CityLoading extends CityState {
  const CityLoading({this.previousData});

  final CityStateData? previousData;

  @override
  CityStateData? get data => previousData;
}

final class CityDisplay extends CityState {
  const CityDisplay(this.cityData, {this.feedback});

  final CityStateData cityData;
  final CityFeedback? feedback;

  @override
  CityStateData get data => cityData;

  @override
  List<Object?> get props => [cityData, feedback];
}

final class CityActionRequired extends CityState {
  const CityActionRequired(
    this.cityData, {
    required this.tile,
    required this.building,
  });

  final CityStateData cityData;
  final CityTileCoordinate tile;
  final CityBuilding? building;

  @override
  CityStateData get data => cityData;

  @override
  List<Object?> get props => [cityData, tile, building];
}

final class CityOperationInProgress extends CityState {
  const CityOperationInProgress(this.cityData, {required this.message});

  final CityStateData cityData;
  final String message;

  @override
  CityStateData get data => cityData;

  @override
  List<Object> get props => [cityData, message];
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
