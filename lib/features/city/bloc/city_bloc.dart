import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:task_empire/features/city/data/city_repository.dart';
import 'package:task_empire/features/city/domain/city_building.dart';
import 'package:task_empire/features/city/domain/city_state_data.dart';

part 'city_event.dart';
part 'city_state.dart';

final class CityBloc extends Bloc<CityEvent, CityState> {
  CityBloc({required CityRepository repository})
    : _repository = repository,
      super(const CityLoading()) {
    on<CityStarted>(_onStarted, transformer: restartable());
    on<CityRefreshRequested>(_onRefreshRequested, transformer: droppable());
    on<CityTileTapped>(_onTileTapped);
    on<CityActionDismissed>(_onActionDismissed);
    on<CityBuildRequested>(_onBuildRequested, transformer: droppable());
    on<CityUpgradeRequested>(_onUpgradeRequested, transformer: droppable());
  }

  final CityRepository _repository;

  Future<void> _onStarted(CityStarted event, Emitter<CityState> emit) async {
    await _load(emit, previous: state.data);
  }

  Future<void> _onRefreshRequested(
    CityRefreshRequested event,
    Emitter<CityState> emit,
  ) async {
    if (state is CityActionRequired || state is CityOperationInProgress) return;
    await _load(emit, previous: state.data);
  }

  void _onTileTapped(CityTileTapped event, Emitter<CityState> emit) {
    final current = state;
    if (current is! CityDisplay) return;

    emit(
      CityActionRequired(
        current.data,
        tile: event.tile,
        building: current.data.buildingAt(event.tile),
      ),
    );
  }

  void _onActionDismissed(CityActionDismissed event, Emitter<CityState> emit) {
    if (state case CityActionRequired(:final data)) {
      emit(CityDisplay(data));
    }
  }

  Future<void> _onBuildRequested(
    CityBuildRequested event,
    Emitter<CityState> emit,
  ) async {
    final current = state;
    if (current is! CityActionRequired ||
        current.building != null ||
        current.tile != event.tile) {
      return;
    }

    final previous = current.data;
    emit(CityOperationInProgress(previous, message: 'Идёт строительство…'));

    try {
      await _repository.buildBuilding(type: event.type, tile: event.tile);
      final data = await _repository.fetchCity();
      emit(
        CityDisplay(
          data,
          feedback: CityFeedback(
            message: 'Здание построено: ${event.type.displayName}.',
          ),
        ),
      );
    } on CityRepositoryException catch (error) {
      emit(
        CityDisplay(
          previous,
          feedback: CityFeedback(message: error.message, isError: true),
        ),
      );
    }
  }

  Future<void> _onUpgradeRequested(
    CityUpgradeRequested event,
    Emitter<CityState> emit,
  ) async {
    final current = state;
    if (current is! CityActionRequired ||
        current.building?.id != event.buildingId) {
      return;
    }

    final building = current.building!;
    final previous = current.data;
    emit(CityOperationInProgress(previous, message: 'Идёт улучшение здания…'));

    try {
      await _repository.upgradeBuilding(event.buildingId);
      final data = await _repository.fetchCity();
      emit(
        CityDisplay(
          data,
          feedback: CityFeedback(
            message:
                'Здание улучшено: ${building.type.displayName}, '
                '${building.level + 1} уровень.',
          ),
        ),
      );
    } on CityRepositoryException catch (error) {
      emit(
        CityDisplay(
          previous,
          feedback: CityFeedback(message: error.message, isError: true),
        ),
      );
    }
  }

  Future<void> _load(
    Emitter<CityState> emit, {
    required CityStateData? previous,
  }) async {
    emit(CityLoading(previousData: previous));
    try {
      final data = await _repository.fetchCity();
      final passiveGold = data.profile.passiveGoldEarned;
      emit(
        CityDisplay(
          data,
          feedback: passiveGold > 0
              ? CityFeedback(message: 'Пассивный доход: +$passiveGold золота.')
              : null,
        ),
      );
    } on CityRepositoryException catch (error) {
      if (previous == null) {
        emit(CityFailure(error.message));
      } else {
        emit(
          CityDisplay(
            previous,
            feedback: CityFeedback(message: error.message, isError: true),
          ),
        );
      }
    }
  }
}
