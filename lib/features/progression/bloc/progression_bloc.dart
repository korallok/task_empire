import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:task_empire/features/progression/data/progression_repository.dart';
import 'package:task_empire/features/progression/domain/progression_profile.dart';

part 'progression_event.dart';
part 'progression_state.dart';

final class ProgressionBloc extends Bloc<ProgressionEvent, ProgressionState> {
  ProgressionBloc({required ProgressionRepository repository})
    : _repository = repository,
      super(const ProgressionLoading()) {
    on<ProgressionStarted>(_onStarted, transformer: restartable());
    on<ProgressionRefreshRequested>(
      _onRefreshRequested,
      transformer: droppable(),
    );
  }

  final ProgressionRepository _repository;

  Future<void> _onStarted(
    ProgressionStarted event,
    Emitter<ProgressionState> emit,
  ) async {
    await _load(emit, previous: state.profile);
  }

  Future<void> _onRefreshRequested(
    ProgressionRefreshRequested event,
    Emitter<ProgressionState> emit,
  ) async {
    await _load(emit, previous: state.profile);
  }

  Future<void> _load(
    Emitter<ProgressionState> emit, {
    required ProgressionProfile? previous,
  }) async {
    emit(ProgressionLoading(previousProfile: previous));
    try {
      emit(ProgressionDisplay(await _repository.fetchProfile()));
    } on ProgressionRepositoryException catch (error) {
      if (previous == null) {
        emit(ProgressionFailure(error.message));
      } else {
        emit(ProgressionDisplay(previous, errorMessage: error.message));
      }
    }
  }
}
