import 'package:equatable/equatable.dart';

enum TaskDifficulty {
  easy,
  normal,
  hard;

  String get databaseValue => name;

  String get displayName => switch (this) {
    TaskDifficulty.easy => 'Простая',
    TaskDifficulty.normal => 'Обычная',
    TaskDifficulty.hard => 'Сложная',
  };

  int get xpReward => switch (this) {
    TaskDifficulty.easy => 10,
    TaskDifficulty.normal => 25,
    TaskDifficulty.hard => 50,
  };

  int get goldReward => switch (this) {
    TaskDifficulty.easy => 5,
    TaskDifficulty.normal => 15,
    TaskDifficulty.hard => 30,
  };

  static TaskDifficulty fromDatabase(String value) {
    return switch (value.trim().toLowerCase()) {
      'easy' || 'e' || 'd' => TaskDifficulty.easy,
      'normal' || 'c' || 'b' => TaskDifficulty.normal,
      'hard' || 'a' || 's' => TaskDifficulty.hard,
      _ => throw FormatException('Unknown task difficulty: $value'),
    };
  }
}

enum TaskCategory {
  study,
  work,
  personal,
  health;

  String get databaseValue => name;

  String get displayName => switch (this) {
    TaskCategory.study => 'Учёба',
    TaskCategory.work => 'Работа',
    TaskCategory.personal => 'Личное',
    TaskCategory.health => 'Здоровье',
  };

  static TaskCategory fromDatabase(String value) {
    return switch (value.trim().toLowerCase()) {
      'study' => TaskCategory.study,
      'work' => TaskCategory.work,
      'personal' => TaskCategory.personal,
      'health' => TaskCategory.health,
      _ => throw FormatException('Unknown task category: $value'),
    };
  }
}

enum TaskStatus {
  pending,
  completed;

  String get databaseValue => name;

  static TaskStatus fromDatabase(String value) {
    return switch (value.trim().toLowerCase()) {
      'pending' => TaskStatus.pending,
      'completed' => TaskStatus.completed,
      _ => throw FormatException('Unknown task status: $value'),
    };
  }
}

enum TaskVerificationMode {
  none,
  ai;

  String get databaseValue => name;

  static TaskVerificationMode fromDatabase(String value) {
    return switch (value.trim().toLowerCase()) {
      'none' => TaskVerificationMode.none,
      'ai' => TaskVerificationMode.ai,
      _ => throw FormatException('Unknown verification mode: $value'),
    };
  }
}

final class EmpireTask extends Equatable {
  const EmpireTask({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.scheduledDate,
    required this.deadline,
    required this.status,
    required this.verificationMode,
    required this.createdAt,
    required this.completedAt,
  });

  factory EmpireTask.fromJson(Map<String, dynamic> json) {
    final id = _requiredString(json, 'id');
    final userId = _requiredString(json, 'user_id');
    final title = _requiredString(json, 'title');
    final scheduledDate = _requiredDateTime(json, 'scheduled_date');
    final status = TaskStatus.fromDatabase(_requiredString(json, 'status'));
    final completedAt = _optionalDateTime(json, 'completed_at');
    if (id.isEmpty || userId.isEmpty || title.trim().isEmpty) {
      throw const FormatException('Task identity or title is invalid.');
    }
    if ((status == TaskStatus.completed) != (completedAt != null)) {
      throw const FormatException('Task completion fields are inconsistent.');
    }

    return EmpireTask(
      id: id,
      userId: userId,
      title: title,
      description: _optionalString(json, 'description') ?? '',
      category: TaskCategory.fromDatabase(_requiredString(json, 'category')),
      difficulty: TaskDifficulty.fromDatabase(
        _requiredString(json, 'difficulty'),
      ),
      scheduledDate: dateOnly(scheduledDate),
      deadline: _optionalDateTime(json, 'deadline')?.toLocal(),
      status: status,
      verificationMode: TaskVerificationMode.fromDatabase(
        _requiredString(json, 'verification_mode'),
      ),
      createdAt: _requiredDateTime(json, 'created_at').toLocal(),
      completedAt: completedAt?.toLocal(),
    );
  }

  final String id;
  final String userId;
  final String title;
  final String description;
  final TaskCategory category;
  final TaskDifficulty difficulty;
  final DateTime scheduledDate;
  final DateTime? deadline;
  final TaskStatus status;
  final TaskVerificationMode verificationMode;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isCompleted => status == TaskStatus.completed;

  bool isScheduledFor(DateTime day) => sameDay(scheduledDate, day);

  EmpireTask markCompleted(DateTime at) => EmpireTask(
    id: id,
    userId: userId,
    title: title,
    description: description,
    category: category,
    difficulty: difficulty,
    scheduledDate: scheduledDate,
    deadline: deadline,
    status: TaskStatus.completed,
    verificationMode: verificationMode,
    createdAt: createdAt,
    completedAt: at,
  );

  @override
  List<Object?> get props => [
    id,
    userId,
    title,
    description,
    category,
    difficulty,
    scheduledDate,
    deadline,
    status,
    verificationMode,
    createdAt,
    completedAt,
  ];
}

final class TaskDraft extends Equatable {
  const TaskDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.scheduledDate,
    required this.deadline,
    required this.verificationMode,
  });

  factory TaskDraft.fromTask(EmpireTask task) {
    return TaskDraft(
      title: task.title,
      description: task.description,
      category: task.category,
      difficulty: task.difficulty,
      scheduledDate: task.scheduledDate,
      deadline: task.deadline,
      verificationMode: task.verificationMode,
    );
  }

  final String title;
  final String description;
  final TaskCategory category;
  final TaskDifficulty difficulty;
  final DateTime scheduledDate;
  final DateTime? deadline;
  final TaskVerificationMode verificationMode;

  Map<String, Object?> toDatabaseJson() => {
    'title': title.trim(),
    'description': description.trim(),
    'category': category.databaseValue,
    'difficulty': difficulty.databaseValue,
    'scheduled_date': _databaseDate(scheduledDate),
    'deadline': deadline?.toUtc().toIso8601String(),
    'verification_mode': verificationMode.databaseValue,
  };

  @override
  List<Object?> get props => [
    title,
    description,
    category,
    difficulty,
    scheduledDate,
    deadline,
    verificationMode,
  ];
}

final class TaskCompletionResult extends Equatable {
  const TaskCompletionResult({
    required this.taskId,
    required this.completedAt,
    required this.xpAwarded,
    required this.goldAwarded,
    required this.totalXp,
    required this.totalGold,
    required this.level,
  });

  factory TaskCompletionResult.fromJson(Map<String, dynamic> json) {
    if (_requiredString(json, 'status') != 'completed') {
      throw const FormatException('Task completion status is invalid.');
    }
    final reward = _requiredMap(json, 'reward');
    final profile = _requiredMap(json, 'profile');
    final result = TaskCompletionResult(
      taskId: _requiredString(json, 'task_id'),
      completedAt: _requiredDateTime(json, 'completed_at').toLocal(),
      xpAwarded: _requiredInt(reward, 'xp_delta'),
      goldAwarded: _requiredInt(reward, 'gold_delta'),
      totalXp: _requiredInt(profile, 'xp'),
      totalGold: _requiredInt(profile, 'gold'),
      level: _requiredInt(profile, 'level'),
    );
    if (result.taskId.isEmpty ||
        result.xpAwarded < 0 ||
        result.goldAwarded < 0 ||
        result.totalXp < 0 ||
        result.totalGold < 0 ||
        result.level < 1) {
      throw const FormatException('Task completion values are invalid.');
    }
    return result;
  }

  final String taskId;
  final DateTime completedAt;
  final int xpAwarded;
  final int goldAwarded;
  final int totalXp;
  final int totalGold;
  final int level;

  @override
  List<Object> get props => [
    taskId,
    completedAt,
    xpAwarded,
    goldAwarded,
    totalXp,
    totalGold,
    level,
  ];
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _databaseDate(DateTime value) {
  final day = dateOnly(value);
  final month = day.month.toString().padLeft(2, '0');
  final dayOfMonth = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$dayOfMonth';
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected string field "$key".');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected nullable string field "$key".');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('Expected integer field "$key".');
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected object field "$key".');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Expected date field "$key".');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Invalid date field "$key".');
  return parsed;
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Expected nullable date field "$key".');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Invalid date field "$key".');
  return parsed;
}
