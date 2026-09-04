import 'package:equatable/equatable.dart';

enum TaskDifficulty {
  e,
  d,
  c,
  b,
  a,
  s;

  String get code => name.toUpperCase();

  static TaskDifficulty fromCode(String code) {
    return switch (code.toUpperCase()) {
      'E' => TaskDifficulty.e,
      'D' => TaskDifficulty.d,
      'C' => TaskDifficulty.c,
      'B' => TaskDifficulty.b,
      'A' => TaskDifficulty.a,
      'S' => TaskDifficulty.s,
      _ => throw FormatException('Unknown task difficulty: $code'),
    };
  }
}

final class TaskItem extends Equatable {
  const TaskItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.difficulty,
    required this.hasDeadline,
    required this.deadline,
    required this.isCompleted,
    required this.createdAt,
    required this.completedAt,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final deadlineValue = json['deadline'];
    final completedAtValue = json['completed_at'];

    return TaskItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      difficulty: TaskDifficulty.fromCode(json['difficulty'] as String),
      hasDeadline: json['has_deadline'] as bool,
      deadline: deadlineValue is String
          ? DateTime.parse(deadlineValue).toLocal()
          : null,
      isCompleted: json['is_completed'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      completedAt: completedAtValue is String
          ? DateTime.parse(completedAtValue).toLocal()
          : null,
    );
  }

  final String id;
  final String userId;
  final String title;
  final TaskDifficulty difficulty;
  final bool hasDeadline;
  final DateTime? deadline;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;

  @override
  List<Object?> get props => [
    id,
    userId,
    title,
    difficulty,
    hasDeadline,
    deadline,
    isCompleted,
    createdAt,
    completedAt,
  ];
}

final class NewTaskDraft extends Equatable {
  const NewTaskDraft({required this.title, this.deadline});

  final String title;
  final DateTime? deadline;

  @override
  List<Object?> get props => [title, deadline];
}

final class TaskCompletionResult extends Equatable {
  const TaskCompletionResult({
    required this.taskId,
    required this.approvedDifficulty,
    required this.reason,
    required this.goldAwarded,
    required this.totalGold,
    required this.dailyGoldEarned,
    required this.dailyGoldCap,
    required this.completedAt,
  });

  factory TaskCompletionResult.fromJson(Map<String, dynamic> json) {
    return TaskCompletionResult(
      taskId: json['taskId'] as String,
      approvedDifficulty: TaskDifficulty.fromCode(
        json['approvedDifficulty'] as String,
      ),
      reason: json['reason'] as String,
      goldAwarded: json['goldAwarded'] as int,
      totalGold: json['totalGold'] as int,
      dailyGoldEarned: json['dailyGoldEarned'] as int,
      dailyGoldCap: json['dailyGoldCap'] as int,
      completedAt: DateTime.parse(json['completedAt'] as String).toLocal(),
    );
  }

  final String taskId;
  final TaskDifficulty approvedDifficulty;
  final String reason;
  final int goldAwarded;
  final int totalGold;
  final int dailyGoldEarned;
  final int dailyGoldCap;
  final DateTime completedAt;

  @override
  List<Object> get props => [
    taskId,
    approvedDifficulty,
    reason,
    goldAwarded,
    totalGold,
    dailyGoldEarned,
    dailyGoldCap,
    completedAt,
  ];
}
