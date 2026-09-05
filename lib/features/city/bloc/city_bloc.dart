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
    on<CityEditModeRequested>(_onEditModeRequested);
    on<CityViewModeRequested>(_onViewModeRequested);
    on<CityBuildModeRequested>(_onBuildModeRequested);
    on<CityMoveModeRequested>(_onMoveModeRequested);
    on<CityTileTapped>(_onTileTapped);
    on<CityPlacementMoved>(_onPlacementMoved);
    on<CityPlacementRotated>(_onPlacementRotated);
    on<CityPlacementCanceled>(_onPlacementCanceled);
    on<CityPlacementConfirmed>(_onPlacementConfirmed, transformer: droppable());
    on<CityBuildRequested>(_onBuildRequested, transformer: droppable());
    on<CityMoveRequested>(_onMoveRequested, transformer: droppable());
    on<CityActionDismissed>(_onActionDismissed);
  }

  final CityRepository _repository;
  var _feedbackId = 0;

  Future<void> _onStarted(CityStarted event, Emitter<CityState> emit) async {
    await _load(emit, previous: state.data);
  }

  Future<void> _onRefreshRequested(
    CityRefreshRequested event,
    Emitter<CityState> emit,
  ) async {
    final current = state;
    if (current is CityOperationInProgress) return;

    final previous = current.data;
    if (previous == null) {
      await _load(emit, previous: null);
      return;
    }

    emit(CityLoading(previousData: previous));
    try {
      final data = await _repository.fetchCity();
      final display = current is CityDisplay ? current : null;
      final selectedId = display?.selectedBuildingId;
      emit(
        CityDisplay(
          data,
          interactionMode: display?.mode == CityMode.edit
              ? CityMode.edit
              : CityMode.view,
          activeBuildingId:
              selectedId != null && data.buildingById(selectedId) != null
              ? selectedId
              : null,
          activeTile: display?.selectedTile,
        ),
      );
    } on CityRepositoryException catch (error) {
      emit(
        CityDisplay(
          previous,
          feedback: _feedback(error.message, isError: true),
        ),
      );
    }
  }

  void _onEditModeRequested(
    CityEditModeRequested event,
    Emitter<CityState> emit,
  ) {
    final current = _display;
    if (current == null) return;
    emit(
      CityDisplay(
        current.data,
        interactionMode: CityMode.edit,
        activeBuildingId: current.selectedBuildingId,
        activeTile: current.selectedTile,
      ),
    );
  }

  void _onViewModeRequested(
    CityViewModeRequested event,
    Emitter<CityState> emit,
  ) {
    final current = _display;
    if (current == null) return;
    emit(
      CityDisplay(
        current.data,
        activeBuildingId: current.preview?.movingBuildingId,
      ),
    );
  }

  void _onBuildModeRequested(
    CityBuildModeRequested event,
    Emitter<CityState> emit,
  ) {
    final current = _display;
    if (current == null) return;
    final definition = current.data.definitionForCode(event.code);
    if (definition == null) {
      emit(_withFeedback(current, 'Здание не найдено.', isError: true));
      return;
    }
    if (!definition.isUnlockedAt(current.data.profile.level)) {
      emit(
        _withFeedback(
          current,
          'Здание откроется на ${definition.requiredPlayerLevel} уровне.',
          isError: true,
        ),
      );
      return;
    }
    if (current.data.profile.gold < definition.price) {
      emit(_withFeedback(current, 'Недостаточно золота.', isError: true));
      return;
    }

    final preview = _initialBuildPreview(
      current.data,
      definition,
      preferredPosition: current.selectedTile,
    );
    emit(
      CityDisplay(
        current.data,
        interactionMode: CityMode.build,
        placementPreview: preview,
        activeTile: preview.position,
      ),
    );
  }

  void _onMoveModeRequested(
    CityMoveModeRequested event,
    Emitter<CityState> emit,
  ) {
    final current = _display;
    if (current == null || current.mode != CityMode.edit) return;
    final building = current.data.buildingById(event.buildingId);
    if (building == null) {
      emit(_withFeedback(current, 'Здание не найдено.', isError: true));
      return;
    }

    final preview = _createPreview(
      data: current.data,
      definition: building.definition,
      position: building.position,
      rotation: building.rotation,
      movingBuildingId: building.id,
    );
    emit(
      CityDisplay(
        current.data,
        interactionMode: CityMode.move,
        placementPreview: preview,
        activeBuildingId: building.id,
        activeTile: building.position,
      ),
    );
  }

  void _onTileTapped(CityTileTapped event, Emitter<CityState> emit) {
    final current = _display;
    if (current == null) return;
    if (current.mode == CityMode.build || current.mode == CityMode.move) {
      _movePreview(current, event.tile, emit);
      return;
    }

    final building = current.data.buildingAt(event.tile);
    emit(
      CityDisplay(
        current.data,
        interactionMode: current.mode,
        activeBuildingId: building?.id,
        activeTile: event.tile,
      ),
    );
  }

  void _onPlacementMoved(CityPlacementMoved event, Emitter<CityState> emit) {
    final current = _display;
    if (current == null) return;
    _movePreview(current, event.position, emit);
  }

  void _movePreview(
    CityDisplay current,
    CityTileCoordinate position,
    Emitter<CityState> emit,
  ) {
    final preview = current.preview;
    if (preview == null) return;
    final nextPreview = _createPreview(
      data: current.data,
      definition: preview.definition,
      position: position,
      rotation: preview.rotation,
      movingBuildingId: preview.movingBuildingId,
    );
    emit(
      CityDisplay(
        current.data,
        interactionMode: current.mode,
        placementPreview: nextPreview,
        activeBuildingId: current.selectedBuildingId,
        activeTile: position,
      ),
    );
  }

  void _onPlacementRotated(
    CityPlacementRotated event,
    Emitter<CityState> emit,
  ) {
    final current = _display;
    final preview = current?.preview;
    if (current == null || preview == null) return;
    final rotation = preview.rotation.clockwise;
    final nextPreview = _createPreview(
      data: current.data,
      definition: preview.definition,
      position: preview.position,
      rotation: rotation,
      movingBuildingId: preview.movingBuildingId,
    );
    emit(
      CityDisplay(
        current.data,
        interactionMode: current.mode,
        placementPreview: nextPreview,
        activeBuildingId: current.selectedBuildingId,
        activeTile: preview.position,
      ),
    );
  }

  void _onPlacementCanceled(
    CityPlacementCanceled event,
    Emitter<CityState> emit,
  ) {
    final current = _display;
    if (current == null || current.preview == null) return;
    emit(
      CityDisplay(
        current.data,
        interactionMode: CityMode.edit,
        activeBuildingId: current.preview?.movingBuildingId,
      ),
    );
  }

  Future<void> _onPlacementConfirmed(
    CityPlacementConfirmed event,
    Emitter<CityState> emit,
  ) async {
    final current = _display;
    final preview = current?.preview;
    if (current == null || preview == null) return;

    final validated = _createPreview(
      data: current.data,
      definition: preview.definition,
      position: preview.position,
      rotation: preview.rotation,
      movingBuildingId: preview.movingBuildingId,
    );
    if (!validated.validation.isValid) {
      emit(
        _withFeedback(
          CityDisplay(
            current.data,
            interactionMode: current.mode,
            placementPreview: validated,
            activeBuildingId: current.selectedBuildingId,
            activeTile: current.selectedTile,
          ),
          validated.validation.message,
          isError: true,
        ),
      );
      return;
    }

    if (current.mode == CityMode.build) {
      if (!validated.definition.isUnlockedAt(current.data.profile.level)) {
        emit(
          _withFeedback(
            current,
            'Здание пока недоступно на вашем уровне.',
            isError: true,
          ),
        );
        return;
      }
      if (current.data.profile.gold < validated.definition.price) {
        emit(_withFeedback(current, 'Недостаточно золота.', isError: true));
        return;
      }
      await _performBuild(current, validated, emit);
      return;
    }
    if (current.mode == CityMode.move && validated.movingBuildingId != null) {
      await _performMove(current, validated, emit);
    }
  }

  Future<void> _onBuildRequested(
    CityBuildRequested event,
    Emitter<CityState> emit,
  ) async {
    final current = _display;
    if (current == null) return;
    final definition = current.data.definitionForCode(event.code);
    if (definition == null) {
      emit(_withFeedback(current, 'Здание не найдено.', isError: true));
      return;
    }
    final preview = _createPreview(
      data: current.data,
      definition: definition,
      position: event.position,
      rotation: event.rotation,
    );
    if (!definition.isUnlockedAt(current.data.profile.level)) {
      emit(
        _withFeedback(
          current,
          'Здание пока недоступно на вашем уровне.',
          isError: true,
        ),
      );
      return;
    }
    if (current.data.profile.gold < definition.price) {
      emit(_withFeedback(current, 'Недостаточно золота.', isError: true));
      return;
    }
    if (!preview.validation.isValid) {
      emit(_withFeedback(current, preview.validation.message, isError: true));
      return;
    }
    await _performBuild(current, preview, emit);
  }

  Future<void> _onMoveRequested(
    CityMoveRequested event,
    Emitter<CityState> emit,
  ) async {
    final current = _display;
    if (current == null) return;
    final building = current.data.buildingById(event.buildingId);
    if (building == null) {
      emit(_withFeedback(current, 'Здание не найдено.', isError: true));
      return;
    }
    final preview = _createPreview(
      data: current.data,
      definition: building.definition,
      position: event.position,
      rotation: event.rotation,
      movingBuildingId: building.id,
    );
    if (!preview.validation.isValid) {
      emit(_withFeedback(current, preview.validation.message, isError: true));
      return;
    }
    await _performMove(current, preview, emit);
  }

  void _onActionDismissed(CityActionDismissed event, Emitter<CityState> emit) {
    final current = _display;
    if (current == null) return;
    if (current.preview != null) {
      _onPlacementCanceled(const CityPlacementCanceled(), emit);
      return;
    }
    emit(CityDisplay(current.data, interactionMode: current.mode));
  }

  Future<void> _performBuild(
    CityDisplay previous,
    CityPlacementPreview preview,
    Emitter<CityState> emit,
  ) async {
    emit(
      CityOperationInProgress(
        previous.data,
        message: 'Строим ${preview.definition.name}…',
        interactionMode: CityMode.build,
        placementPreview: preview,
        activeTile: preview.position,
      ),
    );

    try {
      final data = await _repository.buildBuilding(
        code: preview.definition.code,
        position: preview.position,
        rotation: preview.rotation,
      );
      final previousIds = previous.data.buildings
          .map((building) => building.id)
          .toSet();
      String? createdId;
      for (final building in data.buildings) {
        if (!previousIds.contains(building.id)) {
          createdId = building.id;
          break;
        }
      }
      emit(
        CityDisplay(
          data,
          interactionMode: CityMode.edit,
          activeBuildingId: createdId,
          feedback: _feedback('${preview.definition.name} построено.'),
        ),
      );
    } on CityRepositoryException catch (error) {
      emit(
        CityDisplay(
          previous.data,
          interactionMode: CityMode.build,
          placementPreview: preview,
          activeTile: preview.position,
          feedback: _feedback(error.message, isError: true),
        ),
      );
    }
  }

  Future<void> _performMove(
    CityDisplay previous,
    CityPlacementPreview preview,
    Emitter<CityState> emit,
  ) async {
    final buildingId = preview.movingBuildingId;
    if (buildingId == null) return;
    emit(
      CityOperationInProgress(
        previous.data,
        message: 'Перемещаем ${preview.definition.name}…',
        interactionMode: CityMode.move,
        placementPreview: preview,
        activeBuildingId: buildingId,
        activeTile: preview.position,
      ),
    );

    try {
      final data = await _repository.moveBuilding(
        buildingId: buildingId,
        position: preview.position,
        rotation: preview.rotation,
      );
      emit(
        CityDisplay(
          data,
          interactionMode: CityMode.edit,
          activeBuildingId: buildingId,
          feedback: _feedback('${preview.definition.name} перемещено.'),
        ),
      );
    } on CityRepositoryException catch (error) {
      emit(
        CityDisplay(
          previous.data,
          interactionMode: CityMode.move,
          placementPreview: preview,
          activeBuildingId: buildingId,
          activeTile: preview.position,
          feedback: _feedback(error.message, isError: true),
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
      emit(CityDisplay(await _repository.fetchCity()));
    } on CityRepositoryException catch (error) {
      if (previous == null) {
        emit(CityFailure(error.message));
      } else {
        emit(
          CityDisplay(
            previous,
            feedback: _feedback(error.message, isError: true),
          ),
        );
      }
    }
  }

  CityDisplay? get _display =>
      state is CityDisplay ? state as CityDisplay : null;

  CityPlacementPreview _createPreview({
    required CityStateData data,
    required BuildingDefinition definition,
    required CityTileCoordinate position,
    required CityBuildingRotation rotation,
    String? movingBuildingId,
  }) {
    return CityPlacementPreview(
      definition: definition,
      position: position,
      rotation: rotation,
      movingBuildingId: movingBuildingId,
      validation: data.validatePlacement(
        definition: definition,
        position: position,
        rotation: rotation,
        movingBuildingId: movingBuildingId,
      ),
    );
  }

  CityPlacementPreview _initialBuildPreview(
    CityStateData data,
    BuildingDefinition definition, {
    CityTileCoordinate? preferredPosition,
  }) {
    final preferred = _createPreview(
      data: data,
      definition: definition,
      position: preferredPosition ?? const CityTileCoordinate(0, 0),
      rotation: CityBuildingRotation.north,
    );
    if (preferred.validation.isValid) return preferred;

    for (
      var depth = 0;
      depth <= data.city.width + data.city.height - 2;
      depth++
    ) {
      for (var x = 0; x < data.city.width; x++) {
        final y = depth - x;
        if (y < 0 || y >= data.city.height) continue;
        final candidate = _createPreview(
          data: data,
          definition: definition,
          position: CityTileCoordinate(x, y),
          rotation: CityBuildingRotation.north,
        );
        if (candidate.validation.isValid) return candidate;
      }
    }
    return preferred;
  }

  CityDisplay _withFeedback(
    CityDisplay state,
    String message, {
    bool isError = false,
  }) {
    return CityDisplay(
      state.data,
      interactionMode: state.mode,
      placementPreview: state.preview,
      activeBuildingId: state.selectedBuildingId,
      activeTile: state.selectedTile,
      feedback: _feedback(message, isError: isError),
    );
  }

  CityFeedback _feedback(String message, {bool isError = false}) {
    return CityFeedback(message: message, isError: isError, id: ++_feedbackId);
  }
}
