part of 'progression_bloc.dart';

sealed class ProgressionEvent extends Equatable {
  const ProgressionEvent();

  @override
  List<Object?> get props => const [];
}

final class ProgressionStarted extends ProgressionEvent {
  const ProgressionStarted();
}

final class ProgressionRefreshRequested extends ProgressionEvent {
  const ProgressionRefreshRequested();
}
