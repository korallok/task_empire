import 'package:flutter_test/flutter_test.dart';
import 'package:task_empire/features/progression/domain/progression_profile.dart';

void main() {
  test('profile parses progression contract and clamps level progress', () {
    final profile = ProgressionProfile.fromJson(
      {
        'xp': 125,
        'gold': 40,
        'level': 2,
        'xp_into_level': 25,
        'xp_for_next_level': 100,
        'completed_tasks': 6,
        'streak': 3,
      },
      userId: 'user-1',
      isGuest: true,
    );

    expect(profile.levelProgress, 0.25);
    expect(profile.isGuest, isTrue);
    expect(profile.completedTasks, 6);
  });

  test('profile rejects impossible economy values', () {
    expect(
      () => ProgressionProfile.fromJson(
        {
          'xp': -1,
          'gold': 0,
          'level': 1,
          'xp_into_level': 0,
          'xp_for_next_level': 100,
          'completed_tasks': 0,
          'streak': 0,
        },
        userId: 'user-1',
        isGuest: true,
      ),
      throwsFormatException,
    );
  });

  test('profile accepts integral numeric JSON values', () {
    final profile = ProgressionProfile.fromJson(
      {
        'xp': 125.0,
        'gold': 40,
        'level': 2.0,
        'xp_into_level': 25,
        'xp_for_next_level': 100.0,
        'completed_tasks': 6,
        'streak': 3.0,
      },
      userId: 'user-1',
      isGuest: false,
    );

    expect(profile.xp, 125);
    expect(profile.level, 2);
    expect(profile.streak, 3);
  });
}
