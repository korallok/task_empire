import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:task_empire/core/theme/app_theme.dart';
import 'package:task_empire/features/calendar/data/task_item.dart';

class TaskList extends StatelessWidget {
  const TaskList({
    required this.tasks,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.completingTaskId,
    required this.interactionEnabled,
    required this.onRefresh,
    required this.onComplete,
    super.key,
  });

  final List<TaskItem> tasks;
  final String emptyTitle;
  final String emptyDescription;
  final String? completingTaskId;
  final bool interactionEnabled;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onComplete;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.forest700,
      onRefresh: onRefresh,
      child: tasks.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
              children: [
                _EmptyTaskState(
                  title: emptyTitle,
                  description: emptyDescription,
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _TaskCard(
                  task: task,
                  isCompleting: completingTaskId == task.id,
                  interactionEnabled: interactionEnabled,
                  onComplete: () => onComplete(task.id),
                );
              },
            ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.isCompleting,
    required this.interactionEnabled,
    required this.onComplete,
  });

  final TaskItem task;
  final bool isCompleting;
  final bool interactionEnabled;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final deadline = task.deadline;
    final isOverdue =
        deadline != null &&
        deadline.isBefore(DateTime.now()) &&
        !task.isCompleted;
    final accent = task.isCompleted
        ? AppColors.forest500
        : isOverdue
        ? AppColors.danger
        : _difficultyColor(task.difficulty);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: task.isCompleted ? 0.7 : 1,
      child: Material(
        color: AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: accent.withValues(alpha: 0.18)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: task.isCompleted || !interactionEnabled ? null : onComplete,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
            child: Row(
              children: [
                _CompletionControl(
                  isCompleted: task.isCompleted,
                  isCompleting: isCompleting,
                  enabled: interactionEnabled,
                  accent: accent,
                  onPressed: onComplete,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          if (deadline != null)
                            _TaskMetaChip(
                              icon: isOverdue
                                  ? Icons.warning_amber_rounded
                                  : Icons.schedule_rounded,
                              label: DateFormat(
                                'd MMM · HH:mm',
                                'ru',
                              ).format(deadline),
                              color: isOverdue
                                  ? AppColors.danger
                                  : AppColors.mutedInk,
                            ),
                          _TaskMetaChip(
                            icon: task.isCompleted
                                ? Icons.verified_rounded
                                : Icons.bolt_rounded,
                            label: task.isCompleted
                                ? 'Завершено'
                                : 'Награда после проверки',
                            color: task.isCompleted
                                ? AppColors.forest700
                                : AppColors.gold600,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _DifficultyBadge(difficulty: task.difficulty),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletionControl extends StatelessWidget {
  const _CompletionControl({
    required this.isCompleted,
    required this.isCompleting,
    required this.enabled,
    required this.accent,
    required this.onPressed,
  });

  final bool isCompleted;
  final bool isCompleting;
  final bool enabled;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: isCompleting
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2.5, color: accent),
            )
          : IconButton(
              tooltip: isCompleted
                  ? 'Задача выполнена'
                  : 'Завершить и оценить задачу',
              onPressed: isCompleted || !enabled ? null : onPressed,
              style: IconButton.styleFrom(
                backgroundColor: accent.withValues(alpha: 0.12),
                foregroundColor: accent,
                disabledBackgroundColor: accent.withValues(alpha: 0.1),
                disabledForegroundColor: accent,
              ),
              icon: Icon(
                isCompleted
                    ? Icons.check_rounded
                    : Icons.radio_button_unchecked_rounded,
              ),
            ),
    );
  }
}

class _TaskMetaChip extends StatelessWidget {
  const _TaskMetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.difficulty});

  final TaskDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final color = _difficultyColor(difficulty);
    return Tooltip(
      message: 'Ранг сложности ${difficulty.code}',
      child: Container(
        width: 38,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.2),
              color.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          difficulty.code,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _EmptyTaskState extends StatelessWidget {
  const _EmptyTaskState({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 300),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x140E2924)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              gradient: AppColors.goldGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flag_rounded,
              size: 36,
              color: AppColors.forest950,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedInk, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

Color _difficultyColor(TaskDifficulty difficulty) {
  return switch (difficulty) {
    TaskDifficulty.e => const Color(0xFF687A75),
    TaskDifficulty.d => const Color(0xFF438A5D),
    TaskDifficulty.c => const Color(0xFF3D78A8),
    TaskDifficulty.b => const Color(0xFF7656A8),
    TaskDifficulty.a => const Color(0xFFC27B28),
    TaskDifficulty.s => const Color(0xFFB64E42),
  };
}
