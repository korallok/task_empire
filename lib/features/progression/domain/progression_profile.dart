import 'package:equatable/equatable.dart';

final class ProgressionProfile extends Equatable {
  const ProgressionProfile({
    required this.userId,
    required this.isGuest,
    required this.xp,
    required this.gold,
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.completedTasks,
    required this.streak,
  });

  factory ProgressionProfile.fromJson(
    Map<String, dynamic> json, {
    required String userId,
    required bool isGuest,
  }) {
    final xp = _requiredInt(json, 'xp');
    final gold = _requiredInt(json, 'gold');
    final level = _requiredInt(json, 'level');
    final xpIntoLevel = _requiredInt(json, 'xp_into_level');
    final xpForNextLevel = _requiredInt(json, 'xp_for_next_level');
    final completedTasks = _requiredInt(json, 'completed_tasks');
    final streak = _requiredInt(json, 'streak');
    if (userId.isEmpty ||
        xp < 0 ||
        gold < 0 ||
        level < 1 ||
        xpIntoLevel < 0 ||
        xpForNextLevel < 1 ||
        completedTasks < 0 ||
        streak < 0) {
      throw const FormatException('Invalid progression profile values.');
    }

    return ProgressionProfile(
      userId: userId,
      isGuest: isGuest,
      xp: xp,
      gold: gold,
      level: level,
      xpIntoLevel: xpIntoLevel,
      xpForNextLevel: xpForNextLevel,
      completedTasks: completedTasks,
      streak: streak,
    );
  }

  final String userId;
  final bool isGuest;
  final int xp;
  final int gold;
  final int level;
  final int xpIntoLevel;
  final int xpForNextLevel;
  final int completedTasks;
  final int streak;

  double get levelProgress => (xpIntoLevel / xpForNextLevel).clamp(0.0, 1.0);

  @override
  List<Object> get props => [
    userId,
    isGuest,
    xp,
    gold,
    level,
    xpIntoLevel,
    xpForNextLevel,
    completedTasks,
    streak,
  ];
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('Expected integer field "$key".');
}
