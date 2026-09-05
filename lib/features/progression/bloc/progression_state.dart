part of 'progression_bloc.dart';

sealed class ProgressionState extends Equatable {
  const ProgressionState();

  ProgressionProfile? get profile => null;

  @override
  List<Object?> get props => [profile];
}

final class ProgressionLoading extends ProgressionState {
  const ProgressionLoading({this.previousProfile});

  final ProgressionProfile? previousProfile;

  @override
  ProgressionProfile? get profile => previousProfile;
}

final class ProgressionDisplay extends ProgressionState {
  const ProgressionDisplay(this.data, {this.errorMessage});

  final ProgressionProfile data;
  final String? errorMessage;

  @override
  ProgressionProfile get profile => data;

  @override
  List<Object?> get props => [data, errorMessage];
}

final class ProgressionFailure extends ProgressionState {
  const ProgressionFailure(this.message);

  final String message;

  @override
  List<Object> get props => [message];
}
